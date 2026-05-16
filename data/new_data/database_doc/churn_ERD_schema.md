# Telecom Customer Analytics & Churn Analysis System
## ERD Relationships & Database Schema Mapping

> **Project:** Enterprise-Level Telecom Customer Analytics and Churn Analysis System
> **Company:** Egyptian Telecom Company
> **Author:** Senior Enterprise Data Architect
> **Date:** 2026-05-15

---

## PART 1 — Entity Relationship Definitions

### 1.1 Relationship Notation Key

```
M  = Many
1  = One
||  = Exactly One (mandatory)
|o  = Zero or One (optional)
}o  = Zero or Many (optional)
}|  = One or Many (mandatory)
```

---

### 1.2 All Relationships (Plain Text)

```
refer:            Customer       M (self-referencing) ------- M    Customer
                  (A customer can refer many customers; a customer can be referred by many customers)

have (location):  Customer       M ------- 1    Location
                  (Many customers live at/have one location; a location can have many customers)

have (behavior):  Customer       M ------- 1    Behavior
                  (Many customers exhibit one behavior profile; behavior belongs to one customer)

belong:           Customer       M ------- M    ChurnReport
                  (A customer can appear in many churn reports; a churn report can contain many customers)

buy:              Customer       M ------- M    Service
                  (A customer can buy many services; a service can be bought by many customers)

loyal:            Customer       M ------- 1    CustomerLoyalty
                  (Many customers have one loyalty record; a loyalty record belongs to one customer)

contains:         ChurnReport    1 ------- M    Behavior
                  (One churn report contains many behavior records)

behave:           ChurnReport    M ------- 1    Billing
                  (Many churn reports are linked to one billing record)

payment:          ChurnReport    M ------- 1    Billing
                  (A churn report references the payment/billing of a customer)

cost:             CustomerLoyalty  M ------- 1    Billing
                  (Many loyalty records are associated with one billing record)

TimeAtYear:       CustomerLoyalty  M ------- 1    Quarter
                  (Many loyalty records are scoped to one quarter/time period)

subscription:     Customer       M ------- 1    Subscription
                  (Many customers hold one subscription; a subscription belongs to one customer)
```

---

### 1.3 Relationship Summary Table

| Relationship Name | Entity A        | Cardinality A | Cardinality B | Entity B         | Notes                              |
|-------------------|-----------------|---------------|---------------|------------------|------------------------------------|
| refer             | Customer        | M             | M             | Customer         | Self-referencing (referral program)|
| have              | Customer        | M             | 1             | Location         | Customer's physical location       |
| have              | Customer        | M             | 1             | Behavior         | Usage behavior profile             |
| belong            | Customer        | M             | M             | ChurnReport      | Customer-to-churn report mapping   |
| buy               | Customer        | M             | M             | Service          | Services subscribed by customer    |
| loyal             | Customer        | M             | 1             | CustomerLoyalty  | Loyalty tracking per customer      |
| contains          | ChurnReport     | 1             | M             | Behavior         | Behaviors logged in a churn report |
| behave            | ChurnReport     | M             | 1             | Billing          | Billing linked to churn report     |
| payment           | ChurnReport     | M             | 1             | Billing          | Payment info tied to churn event   |
| cost              | CustomerLoyalty | M             | 1             | Billing          | Billing cost tied to loyalty cycle |
| TimeAtYear        | CustomerLoyalty | M             | 1             | Quarter          | Loyalty scoped to fiscal quarter   |
| subscription      | Customer        | M             | 1             | Subscription     | Customer's service subscription    |

---

## PART 2 — Database Schema Mapping

> All Primary Keys (PK) are underlined by convention. Foreign Keys (FK) are explicitly marked.
> Naming convention: `snake_case`. Data types are ANSI SQL-compatible.

---

### Table 1: `customer`

| Column Name      | Data Type      | Constraints          | Description                        |
|------------------|----------------|----------------------|------------------------------------|
| customer_id      | VARCHAR(20)    | PK, NOT NULL         | Unique customer identifier         |
| age              | INT            | NOT NULL             | Customer age                       |
| gender           | VARCHAR(10)    | NOT NULL             | Gender (Male/Female/Other)         |
| marital_status   | VARCHAR(20)    |                      | Married, Single, Divorced          |
| senior_citizen   | BOOLEAN        | DEFAULT FALSE        | Whether customer is senior citizen |
| dependents       | INT            | DEFAULT 0            | Number of dependents               |
| no_dependents    | BOOLEAN        |                      | Flag: no dependents                |
| partner_status   | VARCHAR(20)    |                      | Has partner or not                 |
| referral_info    | VARCHAR(255)   |                      | Referral source details            |
| referred_by      | VARCHAR(20)    | FK → customer(customer_id) | Self-referencing referral FK  |

---

### Table 2: `location`

| Column Name | Data Type    | Constraints  | Description                      |
|-------------|--------------|--------------|----------------------------------|
| location_id | VARCHAR(20)  | PK, NOT NULL | Unique location identifier       |
| address     | VARCHAR(255) | NOT NULL     | Street address                   |
| latitude    | DECIMAL(9,6) |              | Geographic latitude              |
| longitude   | DECIMAL(9,6) |              | Geographic longitude             |
| population  | INT          |              | Population density of area       |
| age         | INT          |              | Avg. age of area (demographic)   |
| gender      | VARCHAR(10)  |              | Dominant gender in area          |
| no_dependents | INT        |              | Avg. dependents in area          |
| customer_id | VARCHAR(20)  | FK → customer(customer_id) | Owning customer FK |

---

### Table 3: `subscription`

| Column Name              | Data Type    | Constraints              | Description                      |
|--------------------------|--------------|--------------------------|----------------------------------|
| sub_id                   | VARCHAR(20)  | PK, NOT NULL             | Unique subscription identifier   |
| customer_id              | VARCHAR(20)  | FK → customer(customer_id) | Owning customer                |
| contract_type            | VARCHAR(50)  | NOT NULL                 | Month-to-month, One year, Two year|
| offer_details            | VARCHAR(255) |                          | Promotion or offer details       |
| payment_method           | VARCHAR(50)  |                          | Credit card, Bank transfer, etc. |
| paperless_billing_option | BOOLEAN      | DEFAULT FALSE            | Enrolled in paperless billing    |

---

### Table 4: `service`

| Column Name           | Data Type    | Constraints   | Description                            |
|-----------------------|--------------|---------------|----------------------------------------|
| service_id            | VARCHAR(20)  | PK, NOT NULL  | Unique service identifier              |
| phone_service         | BOOLEAN      |               | Has phone service                      |
| internet_type         | VARCHAR(50)  |               | DSL, Fiber Optic, None                 |
| internet_service      | BOOLEAN      |               | Has internet service                   |
| multiple_lines        | BOOLEAN      |               | Multiple phone lines                   |
| unlimited_data        | BOOLEAN      |               | Unlimited data plan                    |
| streaming_tv          | BOOLEAN      |               | Streaming TV service                   |
| streaming_movies      | BOOLEAN      |               | Streaming movies service               |
| streaming_music       | BOOLEAN      |               | Streaming music service                |
| online_security       | BOOLEAN      |               | Online security add-on                 |
| online_backup         | BOOLEAN      |               | Online backup add-on                   |
| device_protection     | BOOLEAN      |               | Device protection add-on              |
| device_protection_plan| VARCHAR(50)  |               | Tier of device protection plan         |
| tech_support          | BOOLEAN      |               | Tech support add-on                    |
| premium_tech_support  | BOOLEAN      |               | Premium tech support tier              |

---

### Table 5: `customer_service` *(Junction Table — M:M between customer and service)*

| Column Name | Data Type   | Constraints               | Description               |
|-------------|-------------|---------------------------|---------------------------|
| customer_id | VARCHAR(20) | PK, FK → customer(customer_id) | Customer reference   |
| service_id  | VARCHAR(20) | PK, FK → service(service_id)   | Service reference    |
| start_date  | DATE        |                           | Service subscription date |
| status      | VARCHAR(20) | DEFAULT 'Active'          | Active, Cancelled, Paused |

---

### Table 6: `behavior`

| Column Name               | Data Type      | Constraints                   | Description                        |
|---------------------------|----------------|-------------------------------|------------------------------------|
| behavior_id               | VARCHAR(20)    | PK, NOT NULL                  | Unique behavior record identifier  |
| customer_id               | VARCHAR(20)    | FK → customer(customer_id)    | Owning customer                    |
| avg_monthly_gb_download   | DECIMAL(10,2)  |                               | Average monthly data download (GB) |
| long_distance_usage_metrics | DECIMAL(10,2)|                               | Long-distance call metrics         |

---

### Table 7: `churn_report`

| Column Name  | Data Type    | Constraints  | Description                              |
|--------------|--------------|--------------|------------------------------------------|
| churn_id     | VARCHAR(20)  | PK, NOT NULL | Unique churn report identifier           |
| churn_label  | VARCHAR(20)  | NOT NULL     | Churned / Stayed                         |
| churn_value  | DECIMAL(5,2) |              | Probability or score value (0.0–1.0)     |
| churn_score  | INT          |              | Computed churn score (0–100)             |
| churn_reason | VARCHAR(255) |              | Primary reason for churn                 |

---

### Table 8: `customer_churn_report` *(Junction Table — M:M between customer and churn_report)*

| Column Name  | Data Type   | Constraints                         | Description             |
|--------------|-------------|-------------------------------------|-------------------------|
| customer_id  | VARCHAR(20) | PK, FK → customer(customer_id)      | Customer reference      |
| churn_id     | VARCHAR(20) | PK, FK → churn_report(churn_id)     | Churn report reference  |
| report_date  | DATE        |                                     | Date report was created |

---

### Table 9: `billing`

| Column Name                   | Data Type      | Constraints  | Description                             |
|-------------------------------|----------------|--------------|-----------------------------------------|
| billing_id                    | VARCHAR(20)    | PK, NOT NULL | Unique billing record identifier        |
| customer_id                   | VARCHAR(20)    | FK → customer(customer_id) | Owning customer         |
| total_charges                 | DECIMAL(12,2)  |              | Cumulative total charges                |
| total_revenue                 | DECIMAL(12,2)  |              | Total revenue from customer             |
| monthly_charges               | DECIMAL(10,2)  |              | Monthly recurring charge                |
| total_extra_data_charges      | DECIMAL(10,2)  |              | Extra data overage charges              |
| total_long_distance_charges   | DECIMAL(10,2)  |              | Long-distance call charges              |
| avg_monthly_long_dist_charges | DECIMAL(10,2)  |              | Average monthly long-distance charges   |
| total_refunds                 | DECIMAL(10,2)  | DEFAULT 0    | Total refund amount issued              |

---

### Table 10: `customer_loyalty`

| Column Name        | Data Type    | Constraints                      | Description                       |
|--------------------|--------------|----------------------------------|-----------------------------------|
| loyalty_id         | VARCHAR(20)  | PK, NOT NULL                     | Unique loyalty record identifier  |
| customer_id        | VARCHAR(20)  | FK → customer(customer_id)       | Owning customer                   |
| billing_id         | VARCHAR(20)  | FK → billing(billing_id)         | Associated billing record         |
| quarter_id         | VARCHAR(20)  | FK → quarter(quarter_id)         | Associated fiscal quarter         |
| cltv               | DECIMAL(12,2)|                                  | Customer Lifetime Value (CLTV)    |
| tenure_months      | INT          |                                  | Months customer has been active   |
| number_of_referrals| INT          | DEFAULT 0                        | Total referrals made              |
| referral_status    | VARCHAR(20)  |                                  | Active, Inactive, Pending         |

---

### Table 11: `quarter`

| Column Name  | Data Type   | Constraints  | Description                       |
|--------------|-------------|--------------|-----------------------------------|
| quarter_id   | VARCHAR(20) | PK, NOT NULL | Unique quarter identifier         |
| quarter_name | VARCHAR(20) | NOT NULL     | e.g., Q1-2025, Q2-2025            |
| start_date   | DATE        |              | Quarter start date                |
| end_date     | DATE        |              | Quarter end date                  |
| fiscal_year  | INT         |              | Fiscal year number                |

---

## PART 3 — Foreign Key Summary (All Constraints)

| FK Column                         | References Table      | Referenced PK   |
|-----------------------------------|-----------------------|-----------------|
| customer.referred_by              | customer              | customer_id     |
| location.customer_id              | customer              | customer_id     |
| subscription.customer_id          | customer              | customer_id     |
| customer_service.customer_id      | customer              | customer_id     |
| customer_service.service_id       | service               | service_id      |
| behavior.customer_id              | customer              | customer_id     |
| customer_churn_report.customer_id | customer              | customer_id     |
| customer_churn_report.churn_id    | churn_report          | churn_id        |
| billing.customer_id               | customer              | customer_id     |
| customer_loyalty.customer_id      | customer              | customer_id     |
| customer_loyalty.billing_id       | billing               | billing_id      |
| customer_loyalty.quarter_id       | quarter               | quarter_id      |

---

## PART 4 — Entity Glossary

| Entity            | Description                                                                 |
|-------------------|-----------------------------------------------------------------------------|
| Customer          | Core entity representing a telecom subscriber with demographic attributes   |
| Location          | Geographic location data tied to a customer (city, coordinates, population) |
| Subscription      | Commercial subscription details (contract type, payment method, offers)     |
| Service           | Telecom services and add-ons available/subscribed (internet, phone, TV)     |
| Behavior          | Usage metrics (data usage, long-distance calls) for churn modeling          |
| ChurnReport       | Analytical report capturing churn labels, scores, reasons per customer      |
| Billing           | Financial record of all charges, revenue, and refunds per customer          |
| CustomerLoyalty   | Loyalty tracking: tenure, CLTV, referrals, and time-based loyalty scores    |
| Quarter           | Fiscal time periods used for loyalty and financial aggregation               |

---

*Document generated by Senior Enterprise Data Architect — Egyptian Telecom Churn Analytics Project*
