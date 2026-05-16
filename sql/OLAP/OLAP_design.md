# OLAP System Design
## Telecom Customer Analytics & Churn Analysis System
### Egyptian Telecom Company — Data Warehouse Layer

> **Author:** Senior Enterprise Data Architect
> **DBMS:** Microsoft SQL Server 2016+ / Azure SQL Database
> **Source:** OLTP schema `telecom.*` (11 tables, 7,043 customers)
> **Target:** OLAP schema `olap.*` — optimised for Power BI dashboards

---

## 1. What Was Done

This document covers the full design and implementation of an OLAP (Online Analytical Processing) data warehouse layer built on top of the existing OLTP `telecom.*` schema. The OLAP layer lives in a separate schema (`olap`) within the **same SQL Server database**, populated entirely via `INSERT ... SELECT` from the OLTP tables — no ETL tool required.

The OLAP layer transforms the normalised, write-optimised OLTP structure into a read-optimised analytical structure that Power BI can query directly with maximum performance and minimum DAX complexity.

---

## 2. Schema Type Decision — Star Schema

### Chosen: ⭐ Star Schema

### Why Not Snowflake Schema?

| Factor | Star Schema | Snowflake Schema |
|--------|-------------|-----------------|
| Query complexity | Simple single-join per dimension | Multi-join chains across normalised dims |
| Power BI performance | Excellent — VertiPaq engine loves flat dims | Slower — more relationships to traverse |
| DAX complexity | Low — measures written against flat tables | Higher — requires USERELATIONSHIP chains |
| Storage overhead | Slight denormalisation (~MB range for 7K rows) | Minimal storage saving at this data scale |
| Maintenance | Simple | Complex dim hierarchies to maintain |
| Data scale | **7,043 rows** — small/medium | Snowflake benefit only appears at 100M+ rows |

**Verdict:** At 7,043 customers with moderate attribute counts, the storage overhead of denormalisation is negligible (well under 10 MB). The query simplicity, Power BI compatibility, and DAX readability gains of a Star Schema far outweigh any normalisation benefit a Snowflake Schema would provide. A Snowflake Schema would add join complexity for no measurable storage or performance gain at this scale.

### Why Not Galaxy / Fact Constellation?

A Galaxy Schema (multiple fact tables sharing dimension tables) was considered but rejected because all analytical questions in this domain converge on the **customer churn event** as the single grain. A second fact table (e.g., for billing transactions) would be warranted only if we were tracking individual invoice line items — which the source data does not support. The current billing data is aggregated per customer, making it a natural measure group within the single fact table.

---

## 3. Analytical Decisions & Design Principles

### 3.1 Grain Definition
The **fact table grain** is: **one row per customer** — representing the complete observable state of that customer across their lifecycle with the telecom company. This is a **snapshot fact table** (not a transactional or accumulating snapshot), appropriate because the source data represents a point-in-time customer assessment, not event streams.

### 3.2 Slowly Changing Dimensions (SCD)
Given the source data is a static CSV snapshot (not a live feed), all dimensions are treated as **SCD Type 1** (overwrite). No history tracking is implemented. If the system is extended to receive live feeds, `dim_customer` and `dim_subscription` would be candidates for SCD Type 2 (add new row on change).

### 3.3 Surrogate Keys
All dimension tables use **integer surrogate keys** (`INT IDENTITY`) as their primary keys. Natural business keys (e.g., `customer_id`, `location_id`) are retained as alternate keys for traceability back to the OLTP system. This is critical for:
- Joining performance (INT vs NVARCHAR join)
- SCD Type 2 future-proofing
- Power BI relationship efficiency

### 3.4 Conformed Dimensions
`dim_customer`, `dim_date` (quarter), and `dim_location` are designed as conformed dimensions — they could be reused across future fact tables (e.g., a billing fact, a support ticket fact) without modification.

### 3.5 Degenerate Dimensions
`churn_reason` and `churn_label` live in the fact table as degenerate dimensions (no separate dimension table). They have low cardinality (few distinct values) and are most useful as slicer/filter attributes on the fact itself in Power BI.

### 3.6 Measures Pre-computed vs Derived
Pre-computed measures stored in the fact table:
- All financial totals (charges, revenue, refunds)
- Churn score, churn value
- Count metrics (referrals, dependents)

Derived measures (to be built as DAX measures in Power BI):
- Churn rate % = `SUM(churn_value) / COUNT(customer_sk)`
- ARPU = `SUM(monthly_charges) / COUNT(customer_sk)`
- Revenue at risk = `SUM(monthly_charges) WHERE churn_value = 1`
- Average CLTV by segment

### 3.7 Power BI Optimisation Decisions
- All `BIT` columns in OLTP are converted to `NVARCHAR(3)` (`'Yes'`/`'No'`) in dimensions — Power BI renders these as clean slicer values without needing calculated columns
- Age is stored both as raw integer AND as an `age_band` string (`'18-30'`, `'31-45'`, etc.) — enables instant demographic segmentation without DAX binning
- `tenure_band` computed at load time for the same reason
- `service_count` (number of active services per customer) pre-computed in fact — common KPI in telecom dashboards
- All dimension tables have a descriptive `_label` or `_name` column suitable for Power BI axis/legend rendering

---

## 4. OLAP Schema Structure

### 4.1 Tables Overview

```
                         ┌─────────────────┐
                         │   dim_date      │
                         │  (quarter dim)  │
                         └────────┬────────┘
                                  │ date_sk
              ┌───────────────────┼───────────────────┐
              │                   │                   │
   ┌──────────┴──────┐   ┌────────▼────────┐  ┌──────┴──────────┐
   │  dim_customer   │   │   fact_churn    │  │  dim_location   │
   │  (demographics) │   │  (central fact) │  │  (geography)    │
   └──────────┬──────┘   └────────┬────────┘  └─────────────────┘
              │ customer_sk       │ service_sk
              │          ┌────────┴────────┐
              │          │  dim_service    │
              │          │  (add-ons)      │
              │          └─────────────────┘
              │          subscription_sk
              │          ┌────────┴────────┐
              │          │ dim_subscription│
              │          │ (contract/pay)  │
              └──────────┘─────────────────┘
```

### 4.2 Dimension Tables (5 dims)

| Table | Grain | Source OLTP Tables | Rows |
|-------|-------|-------------------|------|
| `dim_customer` | 1 row per customer | `customer` | 7,043 |
| `dim_location` | 1 row per location | `location` | 7,043 |
| `dim_service` | 1 row per service record | `service` | 7,043 |
| `dim_subscription` | 1 row per subscription | `subscription` | 7,043 |
| `dim_date` | 1 row per quarter | `quarter` | 4 |

### 4.3 Fact Table (1 fact)

| Table | Grain | Measures | Foreign Keys |
|-------|-------|----------|-------------|
| `fact_churn` | 1 row per customer | 15 measures | 5 dim keys |

---

## 5. Fact Table Measures Catalogue

| Measure Column | Type | Description | Power BI Use |
|----------------|------|-------------|-------------|
| `churn_value` | INT | 1=churned, 0=retained | Churn rate denominator |
| `churn_score` | INT | Model score 0-100 | Risk histogram |
| `cltv` | INT | Customer lifetime value | Revenue segmentation |
| `tenure_months` | INT | Months as subscriber | Cohort analysis |
| `number_of_referrals` | INT | Referrals made | Loyalty KPI |
| `monthly_charges` | DECIMAL | Recurring monthly fee | ARPU, revenue at risk |
| `total_charges` | DECIMAL | Cumulative charges | LTV approximation |
| `total_revenue` | DECIMAL | Total revenue | Revenue dashboard |
| `total_refunds` | DECIMAL | Total refunds issued | Quality KPI |
| `total_extra_data_charges` | DECIMAL | Overage fees | Usage KPI |
| `total_long_distance_charges` | DECIMAL | LD call charges | Usage KPI |
| `avg_monthly_gb_download` | INT | Avg GB/month | Usage segmentation |
| `avg_monthly_ld_charges` | DECIMAL | Avg LD charges/month | Usage KPI |
| `service_count` | INT | Count of active services | Upsell analysis |
| `customer_count` | INT | Always 1 (additive count) | Customer count measure |

---

## 6. Power BI Dashboard Enablement

The schema directly supports these dashboard pages:

| Dashboard Page | Dimensions Used | Measures Used |
|---------------|-----------------|---------------|
| **Executive Churn Overview** | dim_customer (gender, age_band), dim_date | churn_value, churn_score, cltv, monthly_charges |
| **Geographic Churn Map** | dim_location (city, state, lat, long) | churn_value, customer_count |
| **Service Adoption & Churn** | dim_service (all service flags) | churn_value, service_count, monthly_charges |
| **Revenue at Risk** | dim_subscription (contract_type), dim_customer | monthly_charges, total_revenue, total_refunds |
| **Customer Loyalty** | dim_customer (tenure_band, senior_citizen) | cltv, number_of_referrals, tenure_months |
| **Churn Reason Analysis** | fact_churn (churn_reason, churn_label) | churn_value, count |
| **Demographic Deep-dive** | dim_customer (age_band, married, dependents) | churn_value, monthly_charges |

---

## 7. Execution Steps

```
Step 1 — Ensure OLTP data is loaded
         (01_create_database.sql + 02_insert_data.sql + 03_add_fk_constraints.sql)

Step 2 — Run OLAP.sql
         This file:
           a) Creates the olap schema
           b) Drops and recreates all dim + fact tables
           c) Populates dims from OLTP via INSERT...SELECT
           d) Populates fact_churn via a single joined INSERT...SELECT
           e) Creates non-clustered indexes for Power BI query patterns

Step 3 — Connect Power BI Desktop
         Server: your SQL Server instance
         Database: telecom_churn_db
         Import tables: olap.dim_* and olap.fact_churn

Step 4 — Build relationships in Power BI
         fact_churn[customer_sk]     → dim_customer[customer_sk]
         fact_churn[location_sk]     → dim_location[location_sk]
         fact_churn[service_sk]      → dim_service[service_sk]
         fact_churn[subscription_sk] → dim_subscription[subscription_sk]
         fact_churn[date_sk]         → dim_date[date_sk]

Step 5 — Create DAX measures (examples)
         Churn Rate    = DIVIDE(SUM(fact_churn[churn_value]), COUNT(fact_churn[customer_count]))
         ARPU          = DIVIDE(SUM(fact_churn[monthly_charges]), COUNT(fact_churn[customer_count]))
         Revenue@Risk  = CALCULATE(SUM(fact_churn[monthly_charges]), fact_churn[churn_value]=1)
         Avg CLTV      = AVERAGE(fact_churn[cltv])
```

---

## 8. File Index

| File | Purpose |
|------|---------|
| `01_create_database.sql` | OLTP schema creation (T-SQL) |
| `02_insert_data.sql` | OLTP data injection (generated by notebook) |
| `03_add_fk_constraints.sql` | OLTP FK constraints post-load |
| `churn_etl_pipeline.ipynb` | Python notebook: CSV → SQL injection script |
| `OLAP.sql` | **OLAP schema: dims + fact creation + data load** |
| `churn_ERD_schema.md` | OLTP ERD relationships + schema mapping |
| `OLAP_design.md` | **This document** |

---

*Document prepared by Senior Enterprise Data Architect — Egyptian Telecom Churn Analytics Project*
