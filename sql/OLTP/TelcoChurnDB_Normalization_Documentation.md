# Telco Customer Churn — Database Normalization Documentation
**Target RDBMS:** Microsoft SQL Server  
**Source Dataset:** `WA_Fn-UseC_-Telco-Customer-Churn.csv` (7 043 rows, 21 columns)  
**Final Normal Form Achieved:** BCNF (Boyce-Codd Normal Form / 3.5NF)

---

## Table of Contents
1. [Source Data Profile](#1-source-data-profile)  
2. [1NF — First Normal Form](#2-1nf--first-normal-form)  
3. [2NF — Second Normal Form](#3-2nf--second-normal-form)  
4. [3NF — Third Normal Form](#4-3nf--third-normal-form)  
5. [BCNF — Boyce-Codd Normal Form (3.5NF)](#5-bcnf--boyce-codd-normal-form-35nf)  
6. [Final Schema — ERD Description](#6-final-schema--erd-description)  
7. [Table Definitions](#7-table-definitions)  
8. [Design Decisions & Trade-offs](#8-design-decisions--trade-offs)  
9. [Data Quality Notes](#9-data-quality-notes)

---

## 1. Source Data Profile

The original flat file contains **one row per customer** with 21 mixed-concern columns:

| Column | Type | Domain / Notes |
|--------|------|----------------|
| customerID | String | e.g., `7590-VHVEG` — natural candidate key |
| gender | String | `Male`, `Female` |
| SeniorCitizen | Int | `0` or `1` (encoded as integer, not boolean) |
| Partner | String | `Yes` / `No` |
| Dependents | String | `Yes` / `No` |
| tenure | Int | Months as customer (0–72) |
| PhoneService | String | `Yes` / `No` |
| MultipleLines | String | `Yes` / `No` / **`No phone service`** ← pseudo-value |
| InternetService | String | `DSL` / `Fiber optic` / `No` |
| OnlineSecurity | String | `Yes` / `No` / **`No internet service`** ← pseudo-value |
| OnlineBackup | String | `Yes` / `No` / **`No internet service`** |
| DeviceProtection | String | `Yes` / `No` / **`No internet service`** |
| TechSupport | String | `Yes` / `No` / **`No internet service`** |
| StreamingTV | String | `Yes` / `No` / **`No internet service`** |
| StreamingMovies | String | `Yes` / `No` / **`No internet service`** |
| Contract | String | `Month-to-month` / `One year` / `Two year` |
| PaperlessBilling | String | `Yes` / `No` |
| PaymentMethod | String | 4 distinct values |
| MonthlyCharges | Float | USD |
| TotalCharges | Float / String | 11 rows contain `" "` (space) instead of a number |
| Churn | String | `Yes` / `No` — the analytic target label |

**Key Problems Identified:**
- All 21 columns collapsed into a single flat table — zero separation of concerns.
- Categorical string columns repeated verbatim on every row (redundancy).
- Pseudo-values (`"No phone service"`, `"No internet service"`) embed a dependency *inside* a data column, hiding transitive functional dependencies.
- `SeniorCitizen` uses `0/1` integers while all other flags use `"Yes"/"No"` strings — inconsistent encoding.
- 11 rows with `TotalCharges = " "` (space-padded empty).

---

## 2. 1NF — First Normal Form

### Rules Applied
1. Every column must contain **atomic (indivisible) values**.
2. Every row must be **uniquely identifiable** (a primary key must exist).
3. **No repeating groups** (multiple values in one cell).

### Assessment of the Source Table
The source CSV already satisfies most 1NF requirements — each cell holds a single scalar value and `customerID` uniquely identifies every row. However, two fixes are required before proceeding:

| Issue | 1NF Fix |
|-------|---------|
| `SeniorCitizen` stores `0/1` integers while logically it is a boolean flag | Stored as SQL `BIT` — aligned with all other Yes/No flags |
| `TotalCharges` has 11 rows containing `" "` (a space string) instead of a numeric value | Treat these as `NULL` (unknown at migration time) |
| `Yes`/`No` strings in boolean columns | Convert to `BIT` (`1`/`0`) for atomicity and storage efficiency |

**Post-1NF state:** One table, one candidate key (`customerID`), all cells atomic.

---

## 3. 2NF — Second Normal Form

### Rules Applied
2NF requires the table to be in 1NF **and** every non-key attribute must be **fully functionally dependent** on the *entire* primary key (no partial dependencies).

### Assessment
Because the primary key is a **single column** (`customerID`), partial dependency is mathematically impossible — any FD `customerID → X` is a full FD by definition.

**However**, 2NF is the natural moment to extract **lookup tables** for low-cardinality categorical columns whose values repeat across thousands of rows. Storing the string `"Fiber optic"` in 3 274 rows wastes storage and makes updates error-prone.

### Lookup Tables Extracted

| Lookup Table | Columns | Distinct Values |
|---|---|---|
| `dim_Gender` | GenderID (PK), GenderName | 2 |
| `dim_InternetServiceType` | InternetServiceTypeID (PK), ServiceTypeName | 2 (DSL, Fiber optic — "No" becomes NULL) |
| `dim_ContractType` | ContractTypeID (PK), ContractTypeName | 3 |
| `dim_PaymentMethod` | PaymentMethodID (PK), MethodName | 4 |

Every lookup table is trivially in BCNF: a single non-key attribute fully determined by the surrogate PK, with no other FDs.

**Post-2NF state:** The flat fact table now references lookup tables via foreign keys. The table itself still contains all remaining columns.

---

## 4. 3NF — Third Normal Form

### Rules Applied
3NF requires the table to be in 2NF **and** that no non-key attribute is **transitively dependent** on the primary key (i.e., `PK → A → B` is forbidden; `B` must depend *directly* on `PK`).

### Transitive Dependencies Found

#### TD-1: PhoneService → MultipleLines
When `PhoneService = 'No'`, `MultipleLines` is always `'No phone service'`.  
The value of `MultipleLines` is **determined by** `PhoneService`, not independently by `CustomerID`.

```
customerID → PhoneService → MultipleLines (when PhoneService = No)
```

This is a transitive dependency: `MultipleLines` is partly a function of `PhoneService`.

**3NF Fix:** Move `PhoneService` and `MultipleLines` into a dedicated `CustomerPhoneService` table. Replace `'No phone service'` with `NULL` — a `NULL` `HasMultipleLines` is only valid when `HasPhoneService = 0`, enforced by a `CHECK` constraint.

#### TD-2: InternetService → {all 6 add-on flags}
When `InternetService = 'No'`, all six add-on columns are always `'No internet service'`. The add-on values are transitively determined by `InternetService`.

```
customerID → InternetService → {OnlineSecurity, OnlineBackup, DeviceProtection,
                                TechSupport, StreamingTV, StreamingMovies}
                                (when InternetService = No)
```

**3NF Fix:** Move internet service and its add-ons into `CustomerInternetService`. Replace `'No internet service'` with `NULL`. A `CHECK` constraint enforces that all add-on columns must be `NULL` when `InternetServiceTypeID IS NULL`.

### Separation by Subject Area
Beyond resolving TDs, 3NF encourages grouping attributes that describe the *same fact*. The remaining columns split naturally into three subject areas:

| Subject | Columns moved to |
|---|---|
| Demographics | `Customer` table |
| Billing & contract | `CustomerBilling` table |
| Churn outcome (analytic label) | `CustomerChurn` table |

Separating `CustomerChurn` is especially important: the churn label is an *analytic outcome* that may be updated independently of the customer's demographic or service data.

**Post-3NF state:** No transitive dependencies remain. Pseudo-values eliminated. Concerns separated into five tables.

---

## 5. BCNF — Boyce-Codd Normal Form (3.5NF)

### Rules Applied
A table is in BCNF if and only if **every determinant is a candidate key**.  
This is a stricter version of 3NF that also catches anomalies in tables with *multiple overlapping candidate keys*.

### Assessment of Each Table After 3NF

| Table | Candidate Keys | Non-trivial FDs | BCNF Violation? |
|---|---|---|---|
| `dim_Gender` | {GenderID}, {GenderName} | GenderID → GenderName; GenderName → GenderID | No — both determinants are candidate keys |
| `dim_InternetServiceType` | {InternetServiceTypeID}, {ServiceTypeName} | Same pattern | No |
| `dim_ContractType` | {ContractTypeID}, {ContractTypeName} | Same pattern | No |
| `dim_PaymentMethod` | {PaymentMethodID}, {MethodName} | Same pattern | No |
| `Customer` | {CustomerID} | CustomerID → all attributes | No |
| `CustomerPhoneService` | {CustomerID} | CustomerID → HasPhoneService, HasMultipleLines | No |
| `CustomerInternetService` | {CustomerID} | CustomerID → all attributes | No |
| `CustomerBilling` | {CustomerID} | CustomerID → all billing attributes | No |
| `CustomerChurn` | {CustomerID} | CustomerID → HasChurned | No |

**Result:** All tables are in BCNF. No further decomposition is required.

The key that elevated the design from 3NF to BCNF was the elimination of the **pseudo-value transitive dependencies** — embedding `'No phone service'` and `'No internet service'` as data values was a subtle BCNF violation disguised as a 3NF issue, because those values acted as implicit determinants within the same column.

---

## 6. Final Schema — ERD Description

```
dim_Gender ──────────────┐
                          │ FK: GenderID
dim_InternetServiceType──┤            ┌──── CustomerPhoneService
                          │ FK: ISTypeID│
dim_ContractType ────────┤    Customer ├──── CustomerInternetService
                          │            │
dim_PaymentMethod ───────┤            ├──── CustomerBilling
                          └────────────┤
                                       └──── CustomerChurn
```

- **One-to-one** relationship between `Customer` and each satellite table (`CustomerPhoneService`, `CustomerInternetService`, `CustomerBilling`, `CustomerChurn`) — each customer has exactly one record in each satellite.
- **Many-to-one** from `Customer` to `dim_Gender`.
- **Many-to-one** from `CustomerInternetService` to `dim_InternetServiceType`.
- **Many-to-one** from `CustomerBilling` to `dim_ContractType` and `dim_PaymentMethod`.

---

## 7. Table Definitions

### `dim_Gender`
| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| GenderID | TINYINT IDENTITY | PK | Surrogate key |
| GenderName | NVARCHAR(10) | UNIQUE NOT NULL | `Male`, `Female` |

### `dim_InternetServiceType`
| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| InternetServiceTypeID | TINYINT IDENTITY | PK | Surrogate key |
| ServiceTypeName | NVARCHAR(20) | UNIQUE NOT NULL | `DSL`, `Fiber optic` |

> `No` (no internet) is represented as `NULL` in `CustomerInternetService`, not as a row here.

### `dim_ContractType`
| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| ContractTypeID | TINYINT IDENTITY | PK | |
| ContractTypeName | NVARCHAR(30) | UNIQUE NOT NULL | `Month-to-month`, `One year`, `Two year` |

### `dim_PaymentMethod`
| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| PaymentMethodID | TINYINT IDENTITY | PK | |
| MethodName | NVARCHAR(40) | UNIQUE NOT NULL | 4 values |

### `Customer`
| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| CustomerID | NVARCHAR(10) | PK | Natural key (`7590-VHVEG` format) |
| GenderID | TINYINT | FK → dim_Gender | |
| IsSeniorCitizen | BIT NOT NULL | | 1 = senior |
| HasPartner | BIT NOT NULL | | 1 = has partner |
| HasDependents | BIT NOT NULL | | 1 = has dependents |
| Tenure | SMALLINT NOT NULL | CHECK ≥ 0 | Months as subscriber |

### `CustomerPhoneService`
| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| CustomerID | NVARCHAR(10) | PK, FK → Customer | |
| HasPhoneService | BIT NOT NULL | | |
| HasMultipleLines | BIT NULL | CHECK: NULL when HasPhoneService=0 | `NULL` replaces `'No phone service'` |

### `CustomerInternetService`
| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| CustomerID | NVARCHAR(10) | PK, FK → Customer | |
| InternetServiceTypeID | TINYINT NULL | FK → dim_InternetServiceType | `NULL` = no internet |
| HasOnlineSecurity | BIT NULL | | `NULL` when no internet |
| HasOnlineBackup | BIT NULL | | `NULL` when no internet |
| HasDeviceProtection | BIT NULL | | `NULL` when no internet |
| HasTechSupport | BIT NULL | | `NULL` when no internet |
| HasStreamingTV | BIT NULL | | `NULL` when no internet |
| HasStreamingMovies | BIT NULL | | `NULL` when no internet |

A `CHECK` constraint enforces that when `InternetServiceTypeID IS NULL`, all six add-on columns must also be `NULL`.

### `CustomerBilling`
| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| CustomerID | NVARCHAR(10) | PK, FK → Customer | |
| ContractTypeID | TINYINT NOT NULL | FK → dim_ContractType | |
| IsPaperless | BIT NOT NULL | | Paperless billing flag |
| PaymentMethodID | TINYINT NOT NULL | FK → dim_PaymentMethod | |
| MonthlyCharges | DECIMAL(8,2) NOT NULL | CHECK ≥ 0 | USD |
| TotalCharges | DECIMAL(10,2) NULL | CHECK ≥ 0 | NULL for 11 new customers |

### `CustomerChurn`
| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| CustomerID | NVARCHAR(10) | PK, FK → Customer | |
| HasChurned | BIT NOT NULL | | 1 = churned, 0 = active |

---

## 8. Design Decisions & Trade-offs

### Decision 1: Natural vs. Surrogate Key for Customers
`CustomerID` (`7590-VHVEG` format) was retained as a **natural key**. It is already unique and opaque (no PII encoded). A surrogate `INT IDENTITY` would add no normalization benefit here and would require a mapping layer for external integration.

### Decision 2: NULL vs. "No Service" Sentinel Values
The original data used `'No phone service'` and `'No internet service'` as string sentinels. These were replaced with **`NULL`** for three reasons:
1. Eliminates the transitive dependency (the core 3NF/BCNF violation).
2. `NULL` is the SQL-standard representation of "not applicable / unknown".
3. Aggregate queries (`COUNT`, `AVG`) and analytic models handle `NULL` correctly without special-casing a magic string.

The semantic contract is enforced by `CHECK` constraints, not just convention.

### Decision 3: Satellite 1-to-1 Tables vs. One Wide Table
Splitting into five tables (demographics, phone, internet, billing, churn) adds join complexity to queries. This is a deliberate trade-off:
- **Benefit:** Each satellite can be updated independently without row-locking the full customer record.
- **Benefit:** The churn label (`CustomerChurn`) is decoupled from service data — critical for ML pipelines that need to refresh labels without modifying historical service records.
- **Benefit:** Nullable columns are isolated into the tables where they belong, reducing `NULL`-sprawl in the core `Customer` table.
- **Mitigation:** A query `VIEW` (e.g., `vw_CustomerFullProfile`) can re-join all satellites for ad-hoc analysis.

### Decision 4: TINYINT for Lookup PKs
Lookup tables have ≤ 4 rows each. `TINYINT` (1 byte, 0–255) is sufficient and minimizes FK storage cost across 7 000+ customer rows.

### Decision 5: No 4NF / 5NF Decomposition
4NF and 5NF address **multi-valued dependencies** and **join dependencies** respectively. None were identified in this dataset — every column describes a single fact about one customer. Further decomposition would produce no normalization benefit and would unnecessarily fragment the schema.

---

## 9. Data Quality Notes

| Issue | Row Count | Resolution |
|-------|-----------|-----------|
| `TotalCharges` = `" "` (space) | 11 | Converted to `NULL` in `CustomerBilling.TotalCharges` |
| `SeniorCitizen` stored as `INT` (0/1) instead of boolean | All rows | Stored as `BIT` in schema |
| `Yes`/`No` string flags | ~15 columns | Uniformly converted to `BIT` (1/0) |
| `'No phone service'` pseudo-value in `MultipleLines` | 682 rows | Replaced with `NULL`; `HasPhoneService = 0` |
| `'No internet service'` pseudo-value in 6 add-on columns | 1 526 rows | Replaced with `NULL`; `InternetServiceTypeID IS NULL` |

---

## Summary: Normalization Steps at a Glance

```
Raw CSV (1 flat table, 21 columns, 7 043 rows)
     │
     ▼ 1NF
Atomic values confirmed; customerID as PK; booleans standardised to BIT
     │
     ▼ 2NF
Lookup tables extracted: dim_Gender, dim_InternetServiceType,
dim_ContractType, dim_PaymentMethod
(eliminates string repetition; surrogate FK keys added)
     │
     ▼ 3NF
Transitive dependencies removed:
  PhoneService → MultipleLines  →  CustomerPhoneService (NULL replaces sentinel)
  InternetService → 6 add-ons  →  CustomerInternetService (NULL replaces sentinel)
Concerns separated: Customer | CustomerBilling | CustomerChurn
     │
     ▼ BCNF (3.5NF)
Verified: every determinant in every table is a candidate key.
No further decomposition needed.
     │
     ▼ Final Schema
9 tables: 4 dim_ lookup + 5 fact/satellite tables
All constraints (PK, FK, UNIQUE, CHECK) enforced at the database level
```

---

*End of Documentation*
