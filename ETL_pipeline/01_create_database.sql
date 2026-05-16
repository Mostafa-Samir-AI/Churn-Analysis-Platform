-- =============================================================================
-- FILE: 01_create_database.sql
-- PROJECT: Telecom Customer Analytics & Churn Analysis System
-- DESCRIPTION: DDL (T-SQL / Microsoft SQL Server) — Creates all tables WITHOUT
--              FK constraints so data can be loaded in any order.
--              FK + additional constraints are defined in the commented block
--              at the bottom of this file. Run that block AFTER running
--              02_insert_data.sql (or the Jupyter notebook).
-- DBMS: Microsoft SQL Server 2016+ / Azure SQL Database
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. DATABASE & SCHEMA SETUP
-- ─────────────────────────────────────────────────────────────────────────────
-- Create the database if it does not exist (run once as sysadmin):
--use master

--CREATE DATABASE telecom_churn_db;
--GO

USE telecom_churn_db;
GO

-- Create schema if it does not exist
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'telecom')
BEGIN
    EXEC('CREATE SCHEMA telecom');
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- DROP ORDER (safe teardown — reverse of creation order)
-- Dependent junction tables first, then independent lookup tables last
-- ─────────────────────────────────────────────────────────────────────────────
IF OBJECT_ID('telecom.customer_churn_report', 'U') IS NOT NULL DROP TABLE telecom.customer_churn_report;
IF OBJECT_ID('telecom.customer_service',      'U') IS NOT NULL DROP TABLE telecom.customer_service;
IF OBJECT_ID('telecom.customer_loyalty',      'U') IS NOT NULL DROP TABLE telecom.customer_loyalty;
IF OBJECT_ID('telecom.churn_report',          'U') IS NOT NULL DROP TABLE telecom.churn_report;
IF OBJECT_ID('telecom.behavior',              'U') IS NOT NULL DROP TABLE telecom.behavior;
IF OBJECT_ID('telecom.billing',               'U') IS NOT NULL DROP TABLE telecom.billing;
IF OBJECT_ID('telecom.subscription',          'U') IS NOT NULL DROP TABLE telecom.subscription;
IF OBJECT_ID('telecom.service',               'U') IS NOT NULL DROP TABLE telecom.service;
IF OBJECT_ID('telecom.location',              'U') IS NOT NULL DROP TABLE telecom.location;
IF OBJECT_ID('telecom.quarter',               'U') IS NOT NULL DROP TABLE telecom.quarter;
IF OBJECT_ID('telecom.customer',              'U') IS NOT NULL DROP TABLE telecom.customer;
GO


-- =============================================================================
-- TABLE 1: telecom.customer
-- Source CSV : Telco_customer_churn_demographics.csv (primary)
--              + Telco_customer_churn.csv (supplemental)
-- NOTE: referred_by FK (self-ref) is defined in the constraints section below
-- =============================================================================
CREATE TABLE telecom.customer (
    customer_id      NVARCHAR(20)  NOT NULL,
    gender           NVARCHAR(10)  NOT NULL,
    age              INT           NOT NULL,
    under_30         BIT           NOT NULL CONSTRAINT df_customer_under_30       DEFAULT 0,
    senior_citizen   BIT           NOT NULL CONSTRAINT df_customer_senior_citizen DEFAULT 0,
    married          BIT           NOT NULL CONSTRAINT df_customer_married        DEFAULT 0,
    dependents       BIT           NOT NULL CONSTRAINT df_customer_dependents     DEFAULT 0,
    no_dependents    INT           NOT NULL CONSTRAINT df_customer_no_dependents  DEFAULT 0,
    -- self-referencing FK; loaded as NULL, constrained post-load (see bottom)
    referred_by      NVARCHAR(20)  NULL,
    CONSTRAINT pk_customer PRIMARY KEY (customer_id)
);
GO
EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Core subscriber entity — demographics sourced from churn_demographics CSV',
    @level0type = N'SCHEMA', @level0name = N'telecom',
    @level1type = N'TABLE',  @level1name = N'customer';
GO


-- =============================================================================
-- TABLE 2: telecom.location
-- Source CSV : Telco_customer_churn_location.csv
-- =============================================================================
CREATE TABLE telecom.location (
    location_id  NVARCHAR(20)   NOT NULL,
    customer_id  NVARCHAR(20)   NOT NULL,       -- FK -> customer; constrained post-load
    country      NVARCHAR(100)  NOT NULL,
    state        NVARCHAR(100)  NOT NULL,
    city         NVARCHAR(100)  NOT NULL,
    zip_code     NVARCHAR(10)   NOT NULL,
    lat_long     NVARCHAR(50)   NULL,
    latitude     DECIMAL(9,6)   NOT NULL,
    longitude    DECIMAL(9,6)   NOT NULL,
    CONSTRAINT pk_location PRIMARY KEY (location_id)
);
GO


-- =============================================================================
-- TABLE 3: telecom.quarter
-- Source CSV : Telco_customer_churn_services.csv  (Quarter column)
-- Distinct quarters extracted and stored as a lookup table
-- =============================================================================
CREATE TABLE telecom.quarter (
    quarter_id    NVARCHAR(20)  NOT NULL,    -- e.g. 'Q1', 'Q2', 'Q3', 'Q4'
    quarter_name  NVARCHAR(20)  NOT NULL,
    CONSTRAINT pk_quarter PRIMARY KEY (quarter_id)
);
GO


-- =============================================================================
-- TABLE 4: telecom.subscription
-- Source CSV : Telco_customer_churn_services.csv (contract / billing columns)
--              + Telco_customer_churn.csv (Payment Method, Paperless Billing)
-- =============================================================================
CREATE TABLE telecom.subscription (
    sub_id                    NVARCHAR(20)   NOT NULL,   -- derived: 'SUB-' + customer_id
    customer_id               NVARCHAR(20)   NOT NULL,   -- FK -> customer; constrained post-load
    contract_type             NVARCHAR(50)   NOT NULL,
    offer_details             NVARCHAR(255)  NULL,
    payment_method            NVARCHAR(50)   NOT NULL,
    paperless_billing_option  BIT            NOT NULL CONSTRAINT df_sub_paperless DEFAULT 0,
    CONSTRAINT pk_subscription PRIMARY KEY (sub_id)
);
GO


-- =============================================================================
-- TABLE 5: telecom.service
-- Source CSV : Telco_customer_churn_services.csv  (service feature columns)
-- One row per unique Service ID
-- =============================================================================
CREATE TABLE telecom.service (
    service_id               NVARCHAR(20)   NOT NULL,
    customer_id              NVARCHAR(20)   NOT NULL,   -- FK -> customer; constrained post-load
    phone_service            BIT            NOT NULL CONSTRAINT df_svc_phone     DEFAULT 0,
    avg_monthly_ld_charges   DECIMAL(10,2)  NOT NULL CONSTRAINT df_svc_ld_chg    DEFAULT 0,
    multiple_lines           BIT            NOT NULL CONSTRAINT df_svc_multiline  DEFAULT 0,
    internet_service         BIT            NOT NULL CONSTRAINT df_svc_internet   DEFAULT 0,
    internet_type            NVARCHAR(50)   NULL,
    avg_monthly_gb_download  INT            NOT NULL CONSTRAINT df_svc_gb         DEFAULT 0,
    online_security          BIT            NOT NULL CONSTRAINT df_svc_security   DEFAULT 0,
    online_backup            BIT            NOT NULL CONSTRAINT df_svc_backup     DEFAULT 0,
    device_protection_plan   NVARCHAR(50)   NOT NULL CONSTRAINT df_svc_devprot    DEFAULT 'No',
    premium_tech_support     BIT            NOT NULL CONSTRAINT df_svc_premtech   DEFAULT 0,
    streaming_tv             BIT            NOT NULL CONSTRAINT df_svc_stv        DEFAULT 0,
    streaming_movies         BIT            NOT NULL CONSTRAINT df_svc_smov       DEFAULT 0,
    streaming_music          BIT            NOT NULL CONSTRAINT df_svc_smus       DEFAULT 0,
    unlimited_data           BIT            NOT NULL CONSTRAINT df_svc_unlimited  DEFAULT 0,
    CONSTRAINT pk_service PRIMARY KEY (service_id)
);
GO


-- =============================================================================
-- TABLE 6: telecom.behavior
-- Source CSV : Telco_customer_churn_services.csv
--              (Avg Monthly GB Download, Avg Monthly Long Distance Charges)
-- =============================================================================
CREATE TABLE telecom.behavior (
    behavior_id                  NVARCHAR(20)   NOT NULL,   -- derived: 'BEH-' + customer_id
    customer_id                  NVARCHAR(20)   NOT NULL,   -- FK -> customer; constrained post-load
    avg_monthly_gb_download      INT            NOT NULL CONSTRAINT df_beh_gb DEFAULT 0,
    long_distance_usage_metrics  DECIMAL(10,2)  NOT NULL CONSTRAINT df_beh_ld DEFAULT 0,
    CONSTRAINT pk_behavior PRIMARY KEY (behavior_id)
);
GO


-- =============================================================================
-- TABLE 7: telecom.billing
-- Source CSV : Telco_customer_churn_services.csv  (financial columns)
-- =============================================================================
CREATE TABLE telecom.billing (
    billing_id                     NVARCHAR(20)   NOT NULL,   -- derived: 'BIL-' + customer_id
    customer_id                    NVARCHAR(20)   NOT NULL,   -- FK -> customer; constrained post-load
    monthly_charges                DECIMAL(10,2)  NOT NULL CONSTRAINT df_bil_monthly   DEFAULT 0,
    total_charges                  DECIMAL(12,2)  NOT NULL CONSTRAINT df_bil_total     DEFAULT 0,
    total_revenue                  DECIMAL(12,2)  NOT NULL CONSTRAINT df_bil_revenue   DEFAULT 0,
    total_refunds                  DECIMAL(10,2)  NOT NULL CONSTRAINT df_bil_refunds   DEFAULT 0,
    total_extra_data_charges       DECIMAL(10,2)  NOT NULL CONSTRAINT df_bil_extradata DEFAULT 0,
    total_long_distance_charges    DECIMAL(10,2)  NOT NULL CONSTRAINT df_bil_ld        DEFAULT 0,
    avg_monthly_long_dist_charges  DECIMAL(10,2)  NOT NULL CONSTRAINT df_bil_avgld     DEFAULT 0,
    CONSTRAINT pk_billing PRIMARY KEY (billing_id)
);
GO


-- =============================================================================
-- TABLE 8: telecom.customer_loyalty
-- Source CSV : Telco_customer_churn_services.csv  (referrals, tenure, offer)
--              + Telco_customer_churn.csv  (CLTV)
-- =============================================================================
CREATE TABLE telecom.customer_loyalty (
    loyalty_id           NVARCHAR(20)  NOT NULL,   -- derived: 'LOY-' + customer_id
    customer_id          NVARCHAR(20)  NOT NULL,   -- FK -> customer; constrained post-load
    billing_id           NVARCHAR(20)  NOT NULL,   -- FK -> billing;  constrained post-load
    quarter_id           NVARCHAR(20)  NOT NULL,   -- FK -> quarter;  constrained post-load
    cltv                 INT           NOT NULL CONSTRAINT df_loy_cltv    DEFAULT 0,
    tenure_months        INT           NOT NULL CONSTRAINT df_loy_tenure  DEFAULT 0,
    number_of_referrals  INT           NOT NULL CONSTRAINT df_loy_refs    DEFAULT 0,
    referral_status      BIT           NOT NULL CONSTRAINT df_loy_refstat DEFAULT 0,
    CONSTRAINT pk_customer_loyalty PRIMARY KEY (loyalty_id)
);
GO


-- =============================================================================
-- TABLE 9: telecom.churn_report
-- Source CSV : Telco_customer_churn.csv
--              (Churn Label, Churn Value, Churn Score, Churn Reason)
-- =============================================================================
CREATE TABLE telecom.churn_report (
    churn_id     NVARCHAR(20)   NOT NULL,   -- derived: 'CHU-' + customer_id
    churn_label  NVARCHAR(20)   NOT NULL,   -- 'Yes' / 'No'
    churn_value  INT            NOT NULL,   -- 0 or 1
    churn_score  INT            NOT NULL,   -- 0-100
    churn_reason NVARCHAR(255)  NULL,
    CONSTRAINT pk_churn_report PRIMARY KEY (churn_id)
);
GO


-- =============================================================================
-- TABLE 10: telecom.customer_churn_report  (Junction: customer M:M churn_report)
-- Both FKs constrained post-load
-- =============================================================================
CREATE TABLE telecom.customer_churn_report (
    customer_id  NVARCHAR(20)  NOT NULL,
    churn_id     NVARCHAR(20)  NOT NULL,
    CONSTRAINT pk_customer_churn_report PRIMARY KEY (customer_id, churn_id)
);
GO


-- =============================================================================
-- TABLE 11: telecom.customer_service  (Junction: customer M:M service)
-- Both FKs constrained post-load
-- =============================================================================
CREATE TABLE telecom.customer_service (
    customer_id  NVARCHAR(20)  NOT NULL,
    service_id   NVARCHAR(20)  NOT NULL,
    CONSTRAINT pk_customer_service PRIMARY KEY (customer_id, service_id)
);
GO


-- =============================================================================
-- ##############################################################################
-- POST-LOAD CONSTRAINTS
-- Run this entire block AFTER 02_insert_data.sql completes successfully.
-- Uncomment below and execute in SSMS or via sqlcmd.
-- ##############################################################################
-- =============================================================================


-- ── customer (self-referencing) ─────────────────────────────────────────────
ALTER TABLE telecom.customer
    ADD CONSTRAINT fk_customer_referred_by
    FOREIGN KEY (referred_by) REFERENCES telecom.customer (customer_id)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- ── location -> customer ─────────────────────────────────────────────────────
ALTER TABLE telecom.location
    ADD CONSTRAINT fk_location_customer
    FOREIGN KEY (customer_id) REFERENCES telecom.customer (customer_id)
    ON DELETE CASCADE ON UPDATE CASCADE;
GO

-- ── subscription -> customer ──────────────────────────────────────────────────
ALTER TABLE telecom.subscription
    ADD CONSTRAINT fk_subscription_customer
    FOREIGN KEY (customer_id) REFERENCES telecom.customer (customer_id)
    ON DELETE CASCADE ON UPDATE CASCADE;
GO

-- ── service -> customer ───────────────────────────────────────────────────────
ALTER TABLE telecom.service
    ADD CONSTRAINT fk_service_customer
    FOREIGN KEY (customer_id) REFERENCES telecom.customer (customer_id)
    ON DELETE CASCADE ON UPDATE CASCADE;
GO

-- ── behavior -> customer ──────────────────────────────────────────────────────
ALTER TABLE telecom.behavior
    ADD CONSTRAINT fk_behavior_customer
    FOREIGN KEY (customer_id) REFERENCES telecom.customer (customer_id)
    ON DELETE CASCADE ON UPDATE CASCADE;
GO

-- ── billing -> customer ───────────────────────────────────────────────────────
ALTER TABLE telecom.billing
    ADD CONSTRAINT fk_billing_customer
    FOREIGN KEY (customer_id) REFERENCES telecom.customer (customer_id)
    ON DELETE CASCADE ON UPDATE CASCADE;
GO

-- ── customer_loyalty -> customer ──────────────────────────────────────────────
ALTER TABLE telecom.customer_loyalty
    ADD CONSTRAINT fk_loyalty_customer
    FOREIGN KEY (customer_id) REFERENCES telecom.customer (customer_id)
    ON DELETE CASCADE ON UPDATE CASCADE;
GO

-- ── customer_loyalty -> billing ───────────────────────────────────────────────
-- NOTE: NO ACTION used here to avoid multiple cascade paths (SQL Server limitation)
ALTER TABLE telecom.customer_loyalty
    ADD CONSTRAINT fk_loyalty_billing
    FOREIGN KEY (billing_id) REFERENCES telecom.billing (billing_id)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- ── customer_loyalty -> quarter ───────────────────────────────────────────────
ALTER TABLE telecom.customer_loyalty
    ADD CONSTRAINT fk_loyalty_quarter
    FOREIGN KEY (quarter_id) REFERENCES telecom.quarter (quarter_id)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- ── customer_churn_report -> customer ─────────────────────────────────────────
ALTER TABLE telecom.customer_churn_report
    ADD CONSTRAINT fk_ccr_customer
    FOREIGN KEY (customer_id) REFERENCES telecom.customer (customer_id)
    ON DELETE CASCADE ON UPDATE CASCADE;
GO

-- ── customer_churn_report -> churn_report ─────────────────────────────────────
ALTER TABLE telecom.customer_churn_report
    ADD CONSTRAINT fk_ccr_churn
    FOREIGN KEY (churn_id) REFERENCES telecom.churn_report (churn_id)
    ON DELETE CASCADE ON UPDATE CASCADE;
GO

-- ── customer_service -> customer ──────────────────────────────────────────────
ALTER TABLE telecom.customer_service
    ADD CONSTRAINT fk_cs_customer
    FOREIGN KEY (customer_id) REFERENCES telecom.customer (customer_id)
    ON DELETE CASCADE ON UPDATE CASCADE;
GO

-- ── customer_service -> service ───────────────────────────────────────────────
ALTER TABLE telecom.customer_service
    ADD CONSTRAINT fk_cs_service
    FOREIGN KEY (service_id) REFERENCES telecom.service (service_id)
    ON DELETE CASCADE ON UPDATE CASCADE;
GO



-- =============================================================================
-- END OF FILE: 01_create_database.sql
-- =============================================================================
 