-- =============================================================================
-- FILE: OLAP.sql
-- PROJECT: Telecom Customer Analytics & Churn Analysis System
-- DESCRIPTION: OLAP Star Schema — Dimension tables + Fact table
--              DDL creation + data injection from OLTP schema (telecom.*)
--              Optimised for Power BI DirectQuery and Import mode.
-- DBMS: Microsoft SQL Server 2016+ / Azure SQL Database
-- SCHEMA TYPE: Star Schema (see OLAP_design.md for full rationale)
-- PRE-REQUISITE: telecom.* OLTP tables must be fully loaded before running this.
-- =============================================================================

USE telecom_churn_db;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. CREATE OLAP SCHEMA
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'olap')
BEGIN
    EXEC('CREATE SCHEMA olap');
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- DROP ORDER (safe teardown — fact first, then dims)
-- ─────────────────────────────────────────────────────────────────────────────
IF OBJECT_ID('olap.fact_churn',        'U') IS NOT NULL DROP TABLE olap.fact_churn;
IF OBJECT_ID('olap.dim_customer',      'U') IS NOT NULL DROP TABLE olap.dim_customer;
IF OBJECT_ID('olap.dim_location',      'U') IS NOT NULL DROP TABLE olap.dim_location;
IF OBJECT_ID('olap.dim_service',       'U') IS NOT NULL DROP TABLE olap.dim_service;
IF OBJECT_ID('olap.dim_subscription',  'U') IS NOT NULL DROP TABLE olap.dim_subscription;
IF OBJECT_ID('olap.dim_date',          'U') IS NOT NULL DROP TABLE olap.dim_date;
GO


-- =============================================================================
-- ██████████████████████████████████████████████████████████████████████████
-- DIMENSION TABLES
-- ██████████████████████████████████████████████████████████████████████████
-- =============================================================================


-- =============================================================================
-- DIM 1: olap.dim_date
-- Grain    : One row per fiscal quarter
-- Source   : telecom.quarter
-- Power BI : Time slicer, quarter filter, trend axis
-- =============================================================================
CREATE TABLE olap.dim_date (
    -- Surrogate key
    date_sk       INT           NOT NULL IDENTITY(1,1),

    -- Natural / business key (traceable back to OLTP)
    quarter_id    NVARCHAR(20)  NOT NULL,

    -- Descriptive attributes
    quarter_name  NVARCHAR(20)  NOT NULL,   -- e.g. 'Q1', 'Q2', 'Q3', 'Q4'
    quarter_num   INT           NOT NULL,   -- 1, 2, 3, 4  (numeric — for sorting in Power BI)
    fiscal_year   INT           NOT NULL,   -- extracted from quarter label if available; default 2022

    CONSTRAINT pk_dim_date PRIMARY KEY (date_sk),
    CONSTRAINT uq_dim_date_quarter_id UNIQUE (quarter_id)
);
GO


-- =============================================================================
-- DIM 2: olap.dim_customer
-- Grain    : One row per customer
-- Source   : telecom.customer (demographics)
-- Power BI : Demographic slicers — gender, age band, marital status, senior flag
-- Key decisions:
--   - BIT fields converted to 'Yes'/'No' NVARCHAR for clean Power BI slicer labels
--   - age_band computed column bucket for instant histogram without DAX binning
--   - tenure_band computed from customer_loyalty (joined at load time)
-- =============================================================================
CREATE TABLE olap.dim_customer (
    -- Surrogate key
    customer_sk        INT           NOT NULL IDENTITY(1,1),

    -- Natural / business key
    customer_id        NVARCHAR(20)  NOT NULL,

    -- Demographic attributes
    gender             NVARCHAR(10)  NOT NULL,
    age                INT           NOT NULL,
    age_band           NVARCHAR(20)  NOT NULL,   -- 'Under 30' | '30-45' | '46-60' | '60+'
    under_30           NVARCHAR(3)   NOT NULL,   -- 'Yes' / 'No'
    senior_citizen     NVARCHAR(3)   NOT NULL,   -- 'Yes' / 'No'
    married            NVARCHAR(3)   NOT NULL,   -- 'Yes' / 'No'
    dependents         NVARCHAR(3)   NOT NULL,   -- 'Yes' / 'No'
    number_of_dependents INT         NOT NULL,

    -- Referral info
    has_referral       NVARCHAR(3)   NOT NULL,   -- 'Yes' / 'No' (referred_by IS NOT NULL)

    CONSTRAINT pk_dim_customer PRIMARY KEY (customer_sk),
    CONSTRAINT uq_dim_customer_id UNIQUE (customer_id)
);
GO


-- =============================================================================
-- DIM 3: olap.dim_location
-- Grain    : One row per customer location
-- Source   : telecom.location
-- Power BI : Geographic map visual (uses latitude/longitude), city/state slicers
-- Key decision: latitude + longitude retained for Power BI Map / Azure Maps visuals
-- =============================================================================
CREATE TABLE olap.dim_location (
    -- Surrogate key
    location_sk   INT            NOT NULL IDENTITY(1,1),

    -- Natural / business key
    location_id   NVARCHAR(20)   NOT NULL,
    customer_id   NVARCHAR(20)   NOT NULL,   -- alternate key for traceability

    -- Geographic hierarchy (Country > State > City > Zip)
    country       NVARCHAR(100)  NOT NULL,
    state         NVARCHAR(100)  NOT NULL,
    city          NVARCHAR(100)  NOT NULL,
    zip_code      NVARCHAR(10)   NOT NULL,
    latitude      DECIMAL(9,6)   NOT NULL,
    longitude     DECIMAL(9,6)   NOT NULL,

    CONSTRAINT pk_dim_location PRIMARY KEY (location_sk),
    CONSTRAINT uq_dim_location_id UNIQUE (location_id)
);
GO


-- =============================================================================
-- DIM 4: olap.dim_service
-- Grain    : One row per customer service record
-- Source   : telecom.service
-- Power BI : Service adoption slicers, internet type filter, add-on analysis
-- Key decision:
--   - All BIT flags converted to 'Yes'/'No' for Power BI slicer usability
--   - service_count pre-computed here to drive upsell analysis
-- =============================================================================
CREATE TABLE olap.dim_service (
    -- Surrogate key
    service_sk               INT            NOT NULL IDENTITY(1,1),

    -- Natural / business key
    service_id               NVARCHAR(20)   NOT NULL,
    customer_id              NVARCHAR(20)   NOT NULL,   -- traceability

    -- Service flags ('Yes' / 'No' for Power BI slicers)
    phone_service            NVARCHAR(3)    NOT NULL,
    multiple_lines           NVARCHAR(3)    NOT NULL,
    internet_service         NVARCHAR(3)    NOT NULL,
    internet_type            NVARCHAR(50)   NOT NULL,   -- 'DSL' | 'Fiber Optic' | 'None'
    online_security          NVARCHAR(3)    NOT NULL,
    online_backup            NVARCHAR(3)    NOT NULL,
    device_protection_plan   NVARCHAR(50)   NOT NULL,
    premium_tech_support     NVARCHAR(3)    NOT NULL,
    streaming_tv             NVARCHAR(3)    NOT NULL,
    streaming_movies         NVARCHAR(3)    NOT NULL,
    streaming_music          NVARCHAR(3)    NOT NULL,
    unlimited_data           NVARCHAR(3)    NOT NULL,

    -- Pre-computed service adoption count (count of active 'Yes' services per customer)
    -- Useful KPI: customers with more services churn less
    service_count            INT            NOT NULL,

    CONSTRAINT pk_dim_service PRIMARY KEY (service_sk),
    CONSTRAINT uq_dim_service_id UNIQUE (service_id)
);
GO


-- =============================================================================
-- DIM 5: olap.dim_subscription
-- Grain    : One row per customer subscription
-- Source   : telecom.subscription
-- Power BI : Contract type slicer, payment method analysis, offer filter
-- Key decision: paperless_billing converted to 'Yes'/'No'
-- =============================================================================
CREATE TABLE olap.dim_subscription (
    -- Surrogate key
    subscription_sk           INT            NOT NULL IDENTITY(1,1),

    -- Natural / business key
    sub_id                    NVARCHAR(20)   NOT NULL,
    customer_id               NVARCHAR(20)   NOT NULL,   -- traceability

    -- Subscription attributes
    contract_type             NVARCHAR(50)   NOT NULL,   -- 'Month-to-Month' | 'One Year' | 'Two Year'
    offer_details             NVARCHAR(255)  NOT NULL,   -- 'None' if no offer (no NULLs in dim)
    payment_method            NVARCHAR(50)   NOT NULL,
    paperless_billing         NVARCHAR(3)    NOT NULL,   -- 'Yes' / 'No'

    CONSTRAINT pk_dim_subscription PRIMARY KEY (subscription_sk),
    CONSTRAINT uq_dim_subscription_id UNIQUE (sub_id)
);
GO


-- =============================================================================
-- ██████████████████████████████████████████████████████████████████████████
-- FACT TABLE
-- ██████████████████████████████████████████████████████████████████████████
-- =============================================================================


-- =============================================================================
-- FACT: olap.fact_churn
-- Grain      : One row per customer (snapshot fact)
-- Schema type: Star — all 5 dimension FKs are direct from this table
-- Source     : telecom.* (joined at load time — see INSERT below)
--
-- Degenerate dimensions stored directly in fact (low cardinality, query-critical):
--   churn_label  — 'Yes' / 'No'  (primary churn slicer)
--   churn_reason — text reason   (reason analysis)
--
-- Additive measures: all financial columns, counts, scores
-- Semi-additive: churn_score (average meaningful; sum not meaningful — use AVG in DAX)
-- =============================================================================
CREATE TABLE olap.fact_churn (
    -- Fact surrogate key
    fact_sk               INT            NOT NULL IDENTITY(1,1),

    -- ── Dimension foreign keys (surrogate) ────────────────────────────────────
    customer_sk           INT            NOT NULL,   -- -> dim_customer
    location_sk           INT            NOT NULL,   -- -> dim_location
    service_sk            INT            NOT NULL,   -- -> dim_service
    subscription_sk       INT            NOT NULL,   -- -> dim_subscription
    date_sk               INT            NOT NULL,   -- -> dim_date (quarter)

    -- ── Natural business key (retained for drill-through in Power BI) ─────────
    customer_id           NVARCHAR(20)   NOT NULL,

    -- ── Degenerate dimensions ─────────────────────────────────────────────────
    churn_label           NVARCHAR(3)    NOT NULL,   -- 'Yes' / 'No'
    churn_reason          NVARCHAR(255)  NOT NULL,   -- 'No Churn' if not churned

    -- ── Churn measures ────────────────────────────────────────────────────────
    churn_value           INT            NOT NULL,   -- 0 or 1  (additive churn count)
    churn_score           INT            NOT NULL,   -- 0-100   (semi-additive; use AVG in DAX)

    -- ── Loyalty / lifetime measures ───────────────────────────────────────────
    cltv                  INT            NOT NULL,   -- Customer Lifetime Value
    tenure_months         INT            NOT NULL,   -- Months as subscriber
    tenure_band           NVARCHAR(20)   NOT NULL,   -- '0-12 mo' | '13-24 mo' | '25-48 mo' | '48+ mo'
    number_of_referrals   INT            NOT NULL,

    -- ── Financial measures (all additive) ────────────────────────────────────
    monthly_charges       DECIMAL(10,2)  NOT NULL,
    total_charges         DECIMAL(12,2)  NOT NULL,
    total_revenue         DECIMAL(12,2)  NOT NULL,
    total_refunds         DECIMAL(10,2)  NOT NULL,
    total_extra_data_charges     DECIMAL(10,2) NOT NULL,
    total_long_distance_charges  DECIMAL(10,2) NOT NULL,

    -- ── Usage measures ────────────────────────────────────────────────────────
    avg_monthly_gb_download      INT           NOT NULL,
    avg_monthly_ld_charges       DECIMAL(10,2) NOT NULL,

    -- ── Additive count helper (always = 1, simplifies COUNT in Power BI) ─────
    customer_count        INT            NOT NULL   CONSTRAINT df_fact_custcount DEFAULT 1,

    -- ── Service count (denormalised from dim_service for fast aggregation) ───
    service_count         INT            NOT NULL,

    CONSTRAINT pk_fact_churn PRIMARY KEY (fact_sk),

    -- FK to dimensions
    CONSTRAINT fk_fact_customer     FOREIGN KEY (customer_sk)     REFERENCES olap.dim_customer     (customer_sk),
    CONSTRAINT fk_fact_location     FOREIGN KEY (location_sk)     REFERENCES olap.dim_location     (location_sk),
    CONSTRAINT fk_fact_service      FOREIGN KEY (service_sk)      REFERENCES olap.dim_service      (service_sk),
    CONSTRAINT fk_fact_subscription FOREIGN KEY (subscription_sk) REFERENCES olap.dim_subscription (subscription_sk),
    CONSTRAINT fk_fact_date         FOREIGN KEY (date_sk)         REFERENCES olap.dim_date         (date_sk)
);
GO


-- =============================================================================
-- ██████████████████████████████████████████████████████████████████████████
-- INDEXES  — Non-clustered indexes tuned for Power BI query patterns
-- ██████████████████████████████████████████████████████████████████████████
-- =============================================================================

-- fact_churn: most filtered columns in Power BI reports
CREATE NONCLUSTERED INDEX ix_fact_churn_label
    ON olap.fact_churn (churn_label) INCLUDE (churn_value, monthly_charges, total_revenue, cltv);

CREATE NONCLUSTERED INDEX ix_fact_churn_score
    ON olap.fact_churn (churn_score);

CREATE NONCLUSTERED INDEX ix_fact_churn_customer
    ON olap.fact_churn (customer_sk) INCLUDE (churn_value, monthly_charges, total_revenue);

CREATE NONCLUSTERED INDEX ix_fact_churn_date
    ON olap.fact_churn (date_sk) INCLUDE (churn_value, monthly_charges);

CREATE NONCLUSTERED INDEX ix_fact_churn_location
    ON olap.fact_churn (location_sk) INCLUDE (churn_value, customer_count);

-- dim_customer: most sliced demographic columns
CREATE NONCLUSTERED INDEX ix_dim_customer_gender
    ON olap.dim_customer (gender);

CREATE NONCLUSTERED INDEX ix_dim_customer_ageband
    ON olap.dim_customer (age_band);

CREATE NONCLUSTERED INDEX ix_dim_customer_senior
    ON olap.dim_customer (senior_citizen);

-- dim_location: geographic queries
CREATE NONCLUSTERED INDEX ix_dim_location_city
    ON olap.dim_location (city, state);

-- dim_subscription: contract type is a primary slicer
CREATE NONCLUSTERED INDEX ix_dim_sub_contract
    ON olap.dim_subscription (contract_type);

GO


-- =============================================================================
-- ██████████████████████████████████████████████████████████████████████████
-- DATA INJECTION
-- All INSERTs use SELECT from telecom.* OLTP tables.
-- ORDER: dims first (no deps between dims), fact last (needs all dim SKs).
-- ██████████████████████████████████████████████████████████████████████████
-- =============================================================================

BEGIN TRANSACTION;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- INJECT DIM 1: dim_date
-- Extracts quarter number from quarter_id string (e.g., 'Q1' -> 1)
-- Fiscal year defaulted to 2022 (source data is a single-year snapshot)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO olap.dim_date (
    quarter_id,
    quarter_name,
    quarter_num,
    fiscal_year
)
SELECT
    q.quarter_id,
    q.quarter_name,
    -- Extract numeric quarter from strings like 'Q1', 'Q2', 'Q3', 'Q4'
    TRY_CAST(SUBSTRING(q.quarter_id, 2, 1) AS INT),
    -- Fiscal year: if quarter_id contains a year (e.g. 'Q1-2022') extract it,
    -- otherwise default to 2022
    CASE
        WHEN LEN(q.quarter_id) > 2 AND CHARINDEX('-', q.quarter_id) > 0
            THEN TRY_CAST(RIGHT(q.quarter_id, 4) AS INT)
        ELSE 2022
    END
FROM telecom.quarter q
ORDER BY q.quarter_id;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- INJECT DIM 2: dim_customer
-- Converts BIT -> 'Yes'/'No', computes age_band bucket
-- has_referral derived from OLTP customer.referred_by
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO olap.dim_customer (
    customer_id,
    gender,
    age,
    age_band,
    under_30,
    senior_citizen,
    married,
    dependents,
    number_of_dependents,
    has_referral
)
SELECT
    c.customer_id,
    c.gender,
    c.age,
    -- Age band: Power BI histogram buckets — no DAX SWITCH needed
    CASE
        WHEN c.age < 30             THEN 'Under 30'
        WHEN c.age BETWEEN 30 AND 45 THEN '30-45'
        WHEN c.age BETWEEN 46 AND 60 THEN '46-60'
        ELSE                             '60+'
    END                                         AS age_band,
    CASE WHEN c.under_30       = 1 THEN 'Yes' ELSE 'No' END AS under_30,
    CASE WHEN c.senior_citizen = 1 THEN 'Yes' ELSE 'No' END AS senior_citizen,
    CASE WHEN c.married        = 1 THEN 'Yes' ELSE 'No' END AS married,
    CASE WHEN c.dependents     = 1 THEN 'Yes' ELSE 'No' END AS dependents,
    c.no_dependents,
    CASE WHEN c.referred_by IS NOT NULL THEN 'Yes' ELSE 'No' END AS has_referral
FROM telecom.customer c;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- INJECT DIM 3: dim_location
-- Straight projection from OLTP location; lat/long preserved for map visuals
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO olap.dim_location (
    location_id,
    customer_id,
    country,
    state,
    city,
    zip_code,
    latitude,
    longitude
)
SELECT
    l.location_id,
    l.customer_id,
    l.country,
    l.state,
    l.city,
    l.zip_code,
    l.latitude,
    l.longitude
FROM telecom.location l;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- INJECT DIM 4: dim_service
-- Converts all BIT flags to 'Yes'/'No'
-- Computes service_count: sum of active add-on services per customer
-- internet_type: COALESCE NULL to 'None' so no NULLs in dimension
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO olap.dim_service (
    service_id,
    customer_id,
    phone_service,
    multiple_lines,
    internet_service,
    internet_type,
    online_security,
    online_backup,
    device_protection_plan,
    premium_tech_support,
    streaming_tv,
    streaming_movies,
    streaming_music,
    unlimited_data,
    service_count
)
SELECT
    s.service_id,
    s.customer_id,
    CASE WHEN s.phone_service        = 1 THEN 'Yes' ELSE 'No' END AS phone_service,
    CASE WHEN s.multiple_lines       = 1 THEN 'Yes' ELSE 'No' END AS multiple_lines,
    CASE WHEN s.internet_service     = 1 THEN 'Yes' ELSE 'No' END AS internet_service,
    COALESCE(NULLIF(LTRIM(RTRIM(s.internet_type)), ''), 'None')   AS internet_type,
    CASE WHEN s.online_security      = 1 THEN 'Yes' ELSE 'No' END AS online_security,
    CASE WHEN s.online_backup        = 1 THEN 'Yes' ELSE 'No' END AS online_backup,
    s.device_protection_plan,
    CASE WHEN s.premium_tech_support = 1 THEN 'Yes' ELSE 'No' END AS premium_tech_support,
    CASE WHEN s.streaming_tv         = 1 THEN 'Yes' ELSE 'No' END AS streaming_tv,
    CASE WHEN s.streaming_movies     = 1 THEN 'Yes' ELSE 'No' END AS streaming_movies,
    CASE WHEN s.streaming_music      = 1 THEN 'Yes' ELSE 'No' END AS streaming_music,
    CASE WHEN s.unlimited_data       = 1 THEN 'Yes' ELSE 'No' END AS unlimited_data,
    -- service_count: count each flag that is active
    (
        s.phone_service
      + s.multiple_lines
      + s.internet_service
      + s.online_security
      + s.online_backup
      + s.premium_tech_support
      + s.streaming_tv
      + s.streaming_movies
      + s.streaming_music
      + s.unlimited_data
      + CASE WHEN s.device_protection_plan NOT IN ('No', 'None', '') THEN 1 ELSE 0 END
    )                                                              AS service_count
FROM telecom.service s;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- INJECT DIM 5: dim_subscription
-- offer_details: COALESCE NULL to 'None' — no NULLs in dimension tables
-- paperless_billing: BIT -> 'Yes'/'No'
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO olap.dim_subscription (
    sub_id,
    customer_id,
    contract_type,
    offer_details,
    payment_method,
    paperless_billing
)
SELECT
    sb.sub_id,
    sb.customer_id,
    sb.contract_type,
    COALESCE(NULLIF(LTRIM(RTRIM(sb.offer_details)), ''), 'None') AS offer_details,
    sb.payment_method,
    CASE WHEN sb.paperless_billing_option = 1 THEN 'Yes' ELSE 'No' END AS paperless_billing
FROM telecom.subscription sb;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- INJECT FACT: fact_churn
-- Single denormalised JOIN across all OLTP tables.
-- All surrogate keys resolved via JOIN to the dim tables just loaded.
-- tenure_band computed inline for Power BI cohort slicing.
-- churn_reason: COALESCE NULL to 'No Churn' for non-churned customers.
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO olap.fact_churn (
    customer_sk,
    location_sk,
    service_sk,
    subscription_sk,
    date_sk,
    customer_id,
    churn_label,
    churn_reason,
    churn_value,
    churn_score,
    cltv,
    tenure_months,
    tenure_band,
    number_of_referrals,
    monthly_charges,
    total_charges,
    total_revenue,
    total_refunds,
    total_extra_data_charges,
    total_long_distance_charges,
    avg_monthly_gb_download,
    avg_monthly_ld_charges,
    customer_count,
    service_count
)
SELECT
    -- ── Surrogate keys resolved from dim tables ───────────────────────────────
    dc.customer_sk,
    dl.location_sk,
    ds.service_sk,
    dsub.subscription_sk,
    dd.date_sk,

    -- ── Natural business key ─────────────────────────────────────────────────
    c.customer_id,

    -- ── Degenerate dimensions ─────────────────────────────────────────────────
    cr.churn_label,
    COALESCE(NULLIF(LTRIM(RTRIM(cr.churn_reason)), ''), 'No Churn') AS churn_reason,

    -- ── Churn measures ────────────────────────────────────────────────────────
    cr.churn_value,
    cr.churn_score,

    -- ── Loyalty measures ──────────────────────────────────────────────────────
    cl.cltv,
    cl.tenure_months,
    -- tenure_band: pre-computed cohort bucket
    CASE
        WHEN cl.tenure_months BETWEEN 0  AND 12  THEN '0-12 mo'
        WHEN cl.tenure_months BETWEEN 13 AND 24  THEN '13-24 mo'
        WHEN cl.tenure_months BETWEEN 25 AND 48  THEN '25-48 mo'
        ELSE                                          '48+ mo'
    END                                              AS tenure_band,
    cl.number_of_referrals,

    -- ── Financial measures ────────────────────────────────────────────────────
    b.monthly_charges,
    b.total_charges,
    b.total_revenue,
    b.total_refunds,
    b.total_extra_data_charges,
    b.total_long_distance_charges,

    -- ── Usage measures ────────────────────────────────────────────────────────
    svc.avg_monthly_gb_download,
    svc.avg_monthly_ld_charges,

    -- ── Additive count ────────────────────────────────────────────────────────
    1                                                AS customer_count,

    -- ── Service count (from dim_service for fast aggregation) ────────────────
    ds.service_count

FROM telecom.customer c

-- Resolve dim_customer SK
JOIN olap.dim_customer dc
    ON dc.customer_id = c.customer_id

-- Location (1:1 per customer in source data)
JOIN telecom.location loc
    ON loc.customer_id = c.customer_id
JOIN olap.dim_location dl
    ON dl.location_id = loc.location_id

-- Service record (1:1 per customer in source data)
JOIN telecom.service svc
    ON svc.customer_id = c.customer_id
JOIN olap.dim_service ds
    ON ds.service_id = svc.service_id

-- Subscription (1:1 per customer in source data)
JOIN telecom.subscription sb
    ON sb.customer_id = c.customer_id
JOIN olap.dim_subscription dsub
    ON dsub.sub_id = sb.sub_id

-- Billing (1:1 per customer)
JOIN telecom.billing b
    ON b.customer_id = c.customer_id

-- Customer loyalty (1:1 per customer; quarter_id used for dim_date)
JOIN telecom.customer_loyalty cl
    ON cl.customer_id = c.customer_id

-- Date dimension resolved from loyalty quarter
JOIN olap.dim_date dd
    ON dd.quarter_id = cl.quarter_id

-- Churn report (via junction table)
JOIN telecom.customer_churn_report ccr
    ON ccr.customer_id = c.customer_id
JOIN telecom.churn_report cr
    ON cr.churn_id = ccr.churn_id;

GO

COMMIT TRANSACTION;
GO


-- =============================================================================
-- ██████████████████████████████████████████████████████████████████████████
-- VERIFICATION QUERIES
-- Run these after the script to confirm the load was successful.
-- ██████████████████████████████████████████████████████████████████████████
-- =============================================================================

-- 1. Row counts for all OLAP tables
SELECT 'dim_date'         AS table_name, COUNT(*) AS row_count FROM olap.dim_date
UNION ALL
SELECT 'dim_customer',                   COUNT(*) FROM olap.dim_customer
UNION ALL
SELECT 'dim_location',                   COUNT(*) FROM olap.dim_location
UNION ALL
SELECT 'dim_service',                    COUNT(*) FROM olap.dim_service
UNION ALL
SELECT 'dim_subscription',               COUNT(*) FROM olap.dim_subscription
UNION ALL
SELECT 'fact_churn',                     COUNT(*) FROM olap.fact_churn
ORDER BY table_name;
GO

-- 2. Churn summary — primary KPI check
SELECT
    churn_label                                                AS [Churn Label],
    COUNT(*)                                                   AS [Customer Count],
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS [Churn Rate %],
    AVG(CAST(churn_score AS FLOAT))                            AS [Avg Churn Score],
    AVG(CAST(cltv AS FLOAT))                                   AS [Avg CLTV],
    SUM(monthly_charges)                                       AS [Total Monthly Charges],
    SUM(total_revenue)                                         AS [Total Revenue]
FROM olap.fact_churn
GROUP BY churn_label
ORDER BY churn_label DESC;
GO

-- 3. Revenue at risk (churned customers)
SELECT
    SUM(monthly_charges)   AS [Monthly Revenue at Risk],
    SUM(total_revenue)     AS [Total Revenue from Churned],
    COUNT(*)               AS [Churned Customers]
FROM olap.fact_churn
WHERE churn_label = 'Yes';
GO

-- 4. Churn by contract type — common Power BI visual
SELECT
    dsub.contract_type                                         AS [Contract Type],
    COUNT(*)                                                   AS [Total Customers],
    SUM(f.churn_value)                                         AS [Churned],
    CAST(SUM(f.churn_value) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS [Churn Rate %]
FROM olap.fact_churn f
JOIN olap.dim_subscription dsub ON f.subscription_sk = dsub.subscription_sk
GROUP BY dsub.contract_type
ORDER BY [Churn Rate %] DESC;
GO

-- 5. Churn by age band — demographic insight
SELECT
    dc.age_band                                                AS [Age Band],
    COUNT(*)                                                   AS [Total Customers],
    SUM(f.churn_value)                                         AS [Churned],
    CAST(SUM(f.churn_value) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS [Churn Rate %],
    AVG(f.monthly_charges)                                     AS [Avg Monthly Charges]
FROM olap.fact_churn f
JOIN olap.dim_customer dc ON f.customer_sk = dc.customer_sk
GROUP BY dc.age_band
ORDER BY dc.age_band;
GO

-- 6. Top 10 churn reasons
SELECT TOP 10
    churn_reason                                               AS [Churn Reason],
    COUNT(*)                                                   AS [Count],
    AVG(CAST(churn_score AS FLOAT))                            AS [Avg Churn Score]
FROM olap.fact_churn
WHERE churn_label = 'Yes'
GROUP BY churn_reason
ORDER BY COUNT(*) DESC;
GO

-- 7. Churn by city (top 15 — for Power BI map drill-down)
SELECT TOP 15
    dl.city                                                    AS [City],
    dl.state                                                   AS [State],
    dl.latitude                                                AS [Latitude],
    dl.longitude                                               AS [Longitude],
    COUNT(*)                                                   AS [Total Customers],
    SUM(f.churn_value)                                         AS [Churned]
FROM olap.fact_churn f
JOIN olap.dim_location dl ON f.location_sk = dl.location_sk
GROUP BY dl.city, dl.state, dl.latitude, dl.longitude
ORDER BY SUM(f.churn_value) DESC;
GO

-- =============================================================================
-- END OF FILE: OLAP.sql
-- Connect Power BI Desktop to: telecom_churn_db / olap schema
-- Recommended import order: dim_date, dim_customer, dim_location,
--                           dim_service, dim_subscription, fact_churn
-- =============================================================================
