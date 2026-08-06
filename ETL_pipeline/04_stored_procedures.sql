-- =============================================================================
-- FILE: 02_stored_procedures.sql
-- PROJECT: Telecom Customer Analytics & Churn Analysis System
-- DESCRIPTION: Generic CRUD stored procedures. Per the requirement, ALL tables
--              are handled by a SINGLE stored procedure per operation
--              (Select / Insert / Update / Delete). Each procedure dispatches
--              internally on @TableName.
--
--              Composite-key junction tables (customer_churn_report,
--              customer_service) use @Id1/@Id2 for both key columns.
--              Single-PK tables only use @Id1.
--
-- DBMS: Microsoft SQL Server 2016+ (uses OPENJSON / JSON_VALUE)
-- =============================================================================

USE telecom_churn_db;
GO

-- =============================================================================
-- 1) telecom.usp_Select
--    Generic SELECT for all tables.
--    @Id1 = NULL  -> returns all rows
--    @Id1 given (+ @Id2 for junction tables) -> returns matching row(s)
-- =============================================================================
CREATE OR ALTER PROCEDURE telecom.usp_Select
    @TableName NVARCHAR(50),
    @Id1       NVARCHAR(20) = NULL,
    @Id2       NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @TableName = 'customer'
    BEGIN
        IF @Id1 IS NULL SELECT * FROM telecom.customer;
        ELSE            SELECT * FROM telecom.customer WHERE customer_id = @Id1;
    END
    ELSE IF @TableName = 'location'
    BEGIN
        IF @Id1 IS NULL SELECT * FROM telecom.location;
        ELSE            SELECT * FROM telecom.location WHERE location_id = @Id1;
    END
    ELSE IF @TableName = 'quarter'
    BEGIN
        IF @Id1 IS NULL SELECT * FROM telecom.quarter;
        ELSE            SELECT * FROM telecom.quarter WHERE quarter_id = @Id1;
    END
    ELSE IF @TableName = 'subscription'
    BEGIN
        IF @Id1 IS NULL SELECT * FROM telecom.subscription;
        ELSE            SELECT * FROM telecom.subscription WHERE sub_id = @Id1;
    END
    ELSE IF @TableName = 'service'
    BEGIN
        IF @Id1 IS NULL SELECT * FROM telecom.service;
        ELSE            SELECT * FROM telecom.service WHERE service_id = @Id1;
    END
    ELSE IF @TableName = 'behavior'
    BEGIN
        IF @Id1 IS NULL SELECT * FROM telecom.behavior;
        ELSE            SELECT * FROM telecom.behavior WHERE behavior_id = @Id1;
    END
    ELSE IF @TableName = 'billing'
    BEGIN
        IF @Id1 IS NULL SELECT * FROM telecom.billing;
        ELSE            SELECT * FROM telecom.billing WHERE billing_id = @Id1;
    END
    ELSE IF @TableName = 'customer_loyalty'
    BEGIN
        IF @Id1 IS NULL SELECT * FROM telecom.customer_loyalty;
        ELSE            SELECT * FROM telecom.customer_loyalty WHERE loyalty_id = @Id1;
    END
    ELSE IF @TableName = 'churn_report'
    BEGIN
        IF @Id1 IS NULL SELECT * FROM telecom.churn_report;
        ELSE            SELECT * FROM telecom.churn_report WHERE churn_id = @Id1;
    END
    ELSE IF @TableName = 'customer_churn_report'
    BEGIN
        IF @Id1 IS NULL
            SELECT * FROM telecom.customer_churn_report;
        ELSE IF @Id2 IS NULL
            SELECT * FROM telecom.customer_churn_report WHERE customer_id = @Id1;
        ELSE
            SELECT * FROM telecom.customer_churn_report WHERE customer_id = @Id1 AND churn_id = @Id2;
    END
    ELSE IF @TableName = 'customer_service'
    BEGIN
        IF @Id1 IS NULL
            SELECT * FROM telecom.customer_service;
        ELSE IF @Id2 IS NULL
            SELECT * FROM telecom.customer_service WHERE customer_id = @Id1;
        ELSE
            SELECT * FROM telecom.customer_service WHERE customer_id = @Id1 AND service_id = @Id2;
    END
    ELSE
    BEGIN
        RAISERROR('usp_Select: Unknown @TableName ''%s''.', 16, 1, @TableName);
        RETURN -1;
    END
END
GO


-- =============================================================================
-- 2) telecom.usp_Insert
--    Generic INSERT for all tables. Row data is passed as a JSON object in
--    @Json, e.g.:
--    EXEC telecom.usp_Insert
--         @TableName = 'customer',
--         @Json = N'{"customer_id":"C-0001","gender":"Male","age":34,
--                     "under_30":0,"senior_citizen":0,"married":1,
--                     "dependents":0,"no_dependents":0,"referred_by":null}';
-- =============================================================================
CREATE OR ALTER PROCEDURE telecom.usp_Insert
    @TableName NVARCHAR(50),
    @Json      NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    IF ISJSON(@Json) = 0
    BEGIN
        RAISERROR('usp_Insert: @Json is not valid JSON.', 16, 1);
        RETURN -1;
    END

    IF @TableName = 'customer'
    BEGIN
        INSERT INTO telecom.customer
            (customer_id, gender, age, under_30, senior_citizen, married, dependents, no_dependents, referred_by)
        SELECT customer_id, gender, age, under_30, senior_citizen, married, dependents, no_dependents, referred_by
        FROM OPENJSON(@Json)
        WITH (
            customer_id     NVARCHAR(20)  '$.customer_id',
            gender          NVARCHAR(10)  '$.gender',
            age             INT           '$.age',
            under_30        BIT           '$.under_30',
            senior_citizen  BIT           '$.senior_citizen',
            married         BIT           '$.married',
            dependents      BIT           '$.dependents',
            no_dependents   INT           '$.no_dependents',
            referred_by     NVARCHAR(20)  '$.referred_by'
        );
    END
    ELSE IF @TableName = 'location'
    BEGIN
        INSERT INTO telecom.location
            (location_id, customer_id, country, state, city, zip_code, lat_long, latitude, longitude)
        SELECT location_id, customer_id, country, state, city, zip_code, lat_long, latitude, longitude
        FROM OPENJSON(@Json)
        WITH (
            location_id  NVARCHAR(20)  '$.location_id',
            customer_id  NVARCHAR(20)  '$.customer_id',
            country      NVARCHAR(100) '$.country',
            state        NVARCHAR(100) '$.state',
            city         NVARCHAR(100) '$.city',
            zip_code     NVARCHAR(10)  '$.zip_code',
            lat_long     NVARCHAR(50)  '$.lat_long',
            latitude     DECIMAL(9,6)  '$.latitude',
            longitude    DECIMAL(9,6)  '$.longitude'
        );
    END
    ELSE IF @TableName = 'quarter'
    BEGIN
        INSERT INTO telecom.quarter (quarter_id, quarter_name)
        SELECT quarter_id, quarter_name
        FROM OPENJSON(@Json)
        WITH (
            quarter_id   NVARCHAR(20) '$.quarter_id',
            quarter_name NVARCHAR(20) '$.quarter_name'
        );
    END
    ELSE IF @TableName = 'subscription'
    BEGIN
        INSERT INTO telecom.subscription
            (sub_id, customer_id, contract_type, offer_details, payment_method, paperless_billing_option)
        SELECT sub_id, customer_id, contract_type, offer_details, payment_method, paperless_billing_option
        FROM OPENJSON(@Json)
        WITH (
            sub_id                    NVARCHAR(20)  '$.sub_id',
            customer_id               NVARCHAR(20)  '$.customer_id',
            contract_type             NVARCHAR(50)  '$.contract_type',
            offer_details             NVARCHAR(255) '$.offer_details',
            payment_method            NVARCHAR(50)  '$.payment_method',
            paperless_billing_option  BIT           '$.paperless_billing_option'
        );
    END
    ELSE IF @TableName = 'service'
    BEGIN
        INSERT INTO telecom.service
            (service_id, customer_id, phone_service, avg_monthly_ld_charges, multiple_lines, internet_service,
             internet_type, avg_monthly_gb_download, online_security, online_backup, device_protection_plan,
             premium_tech_support, streaming_tv, streaming_movies, streaming_music, unlimited_data)
        SELECT service_id, customer_id, phone_service, avg_monthly_ld_charges, multiple_lines, internet_service,
               internet_type, avg_monthly_gb_download, online_security, online_backup, device_protection_plan,
               premium_tech_support, streaming_tv, streaming_movies, streaming_music, unlimited_data
        FROM OPENJSON(@Json)
        WITH (
            service_id               NVARCHAR(20)  '$.service_id',
            customer_id               NVARCHAR(20) '$.customer_id',
            phone_service             BIT          '$.phone_service',
            avg_monthly_ld_charges    DECIMAL(10,2)'$.avg_monthly_ld_charges',
            multiple_lines            BIT          '$.multiple_lines',
            internet_service          BIT          '$.internet_service',
            internet_type             NVARCHAR(50) '$.internet_type',
            avg_monthly_gb_download   INT          '$.avg_monthly_gb_download',
            online_security           BIT          '$.online_security',
            online_backup             BIT          '$.online_backup',
            device_protection_plan    NVARCHAR(50) '$.device_protection_plan',
            premium_tech_support      BIT          '$.premium_tech_support',
            streaming_tv              BIT          '$.streaming_tv',
            streaming_movies          BIT          '$.streaming_movies',
            streaming_music           BIT          '$.streaming_music',
            unlimited_data            BIT          '$.unlimited_data'
        );
    END
    ELSE IF @TableName = 'behavior'
    BEGIN
        INSERT INTO telecom.behavior
            (behavior_id, customer_id, avg_monthly_gb_download, long_distance_usage_metrics)
        SELECT behavior_id, customer_id, avg_monthly_gb_download, long_distance_usage_metrics
        FROM OPENJSON(@Json)
        WITH (
            behavior_id                 NVARCHAR(20)  '$.behavior_id',
            customer_id                 NVARCHAR(20)  '$.customer_id',
            avg_monthly_gb_download     INT           '$.avg_monthly_gb_download',
            long_distance_usage_metrics DECIMAL(10,2) '$.long_distance_usage_metrics'
        );
    END
    ELSE IF @TableName = 'billing'
    BEGIN
        INSERT INTO telecom.billing
            (billing_id, customer_id, monthly_charges, total_charges, total_revenue, total_refunds,
             total_extra_data_charges, total_long_distance_charges, avg_monthly_long_dist_charges)
        SELECT billing_id, customer_id, monthly_charges, total_charges, total_revenue, total_refunds,
               total_extra_data_charges, total_long_distance_charges, avg_monthly_long_dist_charges
        FROM OPENJSON(@Json)
        WITH (
            billing_id                     NVARCHAR(20)  '$.billing_id',
            customer_id                    NVARCHAR(20)  '$.customer_id',
            monthly_charges                DECIMAL(10,2) '$.monthly_charges',
            total_charges                  DECIMAL(12,2) '$.total_charges',
            total_revenue                  DECIMAL(12,2) '$.total_revenue',
            total_refunds                  DECIMAL(10,2) '$.total_refunds',
            total_extra_data_charges       DECIMAL(10,2) '$.total_extra_data_charges',
            total_long_distance_charges    DECIMAL(10,2) '$.total_long_distance_charges',
            avg_monthly_long_dist_charges  DECIMAL(10,2) '$.avg_monthly_long_dist_charges'
        );
    END
    ELSE IF @TableName = 'customer_loyalty'
    BEGIN
        INSERT INTO telecom.customer_loyalty
            (loyalty_id, customer_id, billing_id, quarter_id, cltv, tenure_months, number_of_referrals, referral_status)
        SELECT loyalty_id, customer_id, billing_id, quarter_id, cltv, tenure_months, number_of_referrals, referral_status
        FROM OPENJSON(@Json)
        WITH (
            loyalty_id           NVARCHAR(20) '$.loyalty_id',
            customer_id          NVARCHAR(20) '$.customer_id',
            billing_id           NVARCHAR(20) '$.billing_id',
            quarter_id           NVARCHAR(20) '$.quarter_id',
            cltv                 INT          '$.cltv',
            tenure_months        INT          '$.tenure_months',
            number_of_referrals  INT          '$.number_of_referrals',
            referral_status      BIT          '$.referral_status'
        );
    END
    ELSE IF @TableName = 'churn_report'
    BEGIN
        INSERT INTO telecom.churn_report (churn_id, churn_label, churn_value, churn_score, churn_reason)
        SELECT churn_id, churn_label, churn_value, churn_score, churn_reason
        FROM OPENJSON(@Json)
        WITH (
            churn_id     NVARCHAR(20)  '$.churn_id',
            churn_label  NVARCHAR(20)  '$.churn_label',
            churn_value  INT           '$.churn_value',
            churn_score  INT           '$.churn_score',
            churn_reason NVARCHAR(255) '$.churn_reason'
        );
    END
    ELSE IF @TableName = 'customer_churn_report'
    BEGIN
        INSERT INTO telecom.customer_churn_report (customer_id, churn_id)
        SELECT customer_id, churn_id
        FROM OPENJSON(@Json)
        WITH (
            customer_id NVARCHAR(20) '$.customer_id',
            churn_id    NVARCHAR(20) '$.churn_id'
        );
    END
    ELSE IF @TableName = 'customer_service'
    BEGIN
        INSERT INTO telecom.customer_service (customer_id, service_id)
        SELECT customer_id, service_id
        FROM OPENJSON(@Json)
        WITH (
            customer_id NVARCHAR(20) '$.customer_id',
            service_id  NVARCHAR(20) '$.service_id'
        );
    END
    ELSE
    BEGIN
        RAISERROR('usp_Insert: Unknown @TableName ''%s''.', 16, 1, @TableName);
        RETURN -1;
    END
END
GO


-- =============================================================================
-- 3) telecom.usp_Update
--    Generic UPDATE for all tables. Only fields present in @Json are changed;
--    everything else keeps its current value (partial/PATCH-style update).
--    @Id1 (+ @Id2 for junction tables) identifies the row to update.
--    Example:
--    EXEC telecom.usp_Update
--         @TableName = 'billing', @Id1 = 'BIL-0001',
--         @Json = N'{"monthly_charges":79.99,"total_refunds":0}';
-- =============================================================================
CREATE OR ALTER PROCEDURE telecom.usp_Update
    @TableName NVARCHAR(50),
    @Id1       NVARCHAR(20),
    @Id2       NVARCHAR(20) = NULL,
    @Json      NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    IF ISJSON(@Json) = 0
    BEGIN
        RAISERROR('usp_Update: @Json is not valid JSON.', 16, 1);
        RETURN -1;
    END

    IF @TableName = 'customer'
    BEGIN
        UPDATE telecom.customer
        SET gender          = COALESCE(JSON_VALUE(@Json,'$.gender'), gender),
            age              = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.age') AS INT), age),
            under_30         = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.under_30') AS BIT), under_30),
            senior_citizen   = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.senior_citizen') AS BIT), senior_citizen),
            married          = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.married') AS BIT), married),
            dependents       = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.dependents') AS BIT), dependents),
            no_dependents    = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.no_dependents') AS INT), no_dependents),
            referred_by      = COALESCE(JSON_VALUE(@Json,'$.referred_by'), referred_by)
        WHERE customer_id = @Id1;
    END
    ELSE IF @TableName = 'location'
    BEGIN
        UPDATE telecom.location
        SET country    = COALESCE(JSON_VALUE(@Json,'$.country'), country),
            state       = COALESCE(JSON_VALUE(@Json,'$.state'), state),
            city        = COALESCE(JSON_VALUE(@Json,'$.city'), city),
            zip_code    = COALESCE(JSON_VALUE(@Json,'$.zip_code'), zip_code),
            lat_long    = COALESCE(JSON_VALUE(@Json,'$.lat_long'), lat_long),
            latitude    = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.latitude') AS DECIMAL(9,6)), latitude),
            longitude   = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.longitude') AS DECIMAL(9,6)), longitude)
        WHERE location_id = @Id1;
    END
    ELSE IF @TableName = 'quarter'
    BEGIN
        UPDATE telecom.quarter
        SET quarter_name = COALESCE(JSON_VALUE(@Json,'$.quarter_name'), quarter_name)
        WHERE quarter_id = @Id1;
    END
    ELSE IF @TableName = 'subscription'
    BEGIN
        UPDATE telecom.subscription
        SET contract_type            = COALESCE(JSON_VALUE(@Json,'$.contract_type'), contract_type),
            offer_details             = COALESCE(JSON_VALUE(@Json,'$.offer_details'), offer_details),
            payment_method            = COALESCE(JSON_VALUE(@Json,'$.payment_method'), payment_method),
            paperless_billing_option  = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.paperless_billing_option') AS BIT), paperless_billing_option)
        WHERE sub_id = @Id1;
    END
    ELSE IF @TableName = 'service'
    BEGIN
        UPDATE telecom.service
        SET phone_service            = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.phone_service') AS BIT), phone_service),
            avg_monthly_ld_charges    = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.avg_monthly_ld_charges') AS DECIMAL(10,2)), avg_monthly_ld_charges),
            multiple_lines            = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.multiple_lines') AS BIT), multiple_lines),
            internet_service          = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.internet_service') AS BIT), internet_service),
            internet_type             = COALESCE(JSON_VALUE(@Json,'$.internet_type'), internet_type),
            avg_monthly_gb_download   = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.avg_monthly_gb_download') AS INT), avg_monthly_gb_download),
            online_security           = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.online_security') AS BIT), online_security),
            online_backup             = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.online_backup') AS BIT), online_backup),
            device_protection_plan    = COALESCE(JSON_VALUE(@Json,'$.device_protection_plan'), device_protection_plan),
            premium_tech_support      = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.premium_tech_support') AS BIT), premium_tech_support),
            streaming_tv              = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.streaming_tv') AS BIT), streaming_tv),
            streaming_movies          = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.streaming_movies') AS BIT), streaming_movies),
            streaming_music           = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.streaming_music') AS BIT), streaming_music),
            unlimited_data            = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.unlimited_data') AS BIT), unlimited_data)
        WHERE service_id = @Id1;
    END
    ELSE IF @TableName = 'behavior'
    BEGIN
        UPDATE telecom.behavior
        SET avg_monthly_gb_download      = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.avg_monthly_gb_download') AS INT), avg_monthly_gb_download),
            long_distance_usage_metrics   = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.long_distance_usage_metrics') AS DECIMAL(10,2)), long_distance_usage_metrics)
        WHERE behavior_id = @Id1;
    END
    ELSE IF @TableName = 'billing'
    BEGIN
        UPDATE telecom.billing
        SET monthly_charges                = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.monthly_charges') AS DECIMAL(10,2)), monthly_charges),
            total_charges                   = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.total_charges') AS DECIMAL(12,2)), total_charges),
            total_revenue                   = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.total_revenue') AS DECIMAL(12,2)), total_revenue),
            total_refunds                   = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.total_refunds') AS DECIMAL(10,2)), total_refunds),
            total_extra_data_charges        = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.total_extra_data_charges') AS DECIMAL(10,2)), total_extra_data_charges),
            total_long_distance_charges     = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.total_long_distance_charges') AS DECIMAL(10,2)), total_long_distance_charges),
            avg_monthly_long_dist_charges   = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.avg_monthly_long_dist_charges') AS DECIMAL(10,2)), avg_monthly_long_dist_charges)
        WHERE billing_id = @Id1;
    END
    ELSE IF @TableName = 'customer_loyalty'
    BEGIN
        UPDATE telecom.customer_loyalty
        SET billing_id            = COALESCE(JSON_VALUE(@Json,'$.billing_id'), billing_id),
            quarter_id             = COALESCE(JSON_VALUE(@Json,'$.quarter_id'), quarter_id),
            cltv                   = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.cltv') AS INT), cltv),
            tenure_months          = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.tenure_months') AS INT), tenure_months),
            number_of_referrals    = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.number_of_referrals') AS INT), number_of_referrals),
            referral_status        = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.referral_status') AS BIT), referral_status)
        WHERE loyalty_id = @Id1;
    END
    ELSE IF @TableName = 'churn_report'
    BEGIN
        UPDATE telecom.churn_report
        SET churn_label   = COALESCE(JSON_VALUE(@Json,'$.churn_label'), churn_label),
            churn_value    = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.churn_value') AS INT), churn_value),
            churn_score    = COALESCE(TRY_CAST(JSON_VALUE(@Json,'$.churn_score') AS INT), churn_score),
            churn_reason   = COALESCE(JSON_VALUE(@Json,'$.churn_reason'), churn_reason)
        WHERE churn_id = @Id1;
    END
    ELSE IF @TableName = 'customer_churn_report'
    BEGIN
        -- Composite-key junction row: only churn_id may be repointed for a given customer_id.
        UPDATE telecom.customer_churn_report
        SET churn_id = COALESCE(JSON_VALUE(@Json,'$.churn_id'), churn_id)
        WHERE customer_id = @Id1 AND churn_id = @Id2;
    END
    ELSE IF @TableName = 'customer_service'
    BEGIN
        -- Composite-key junction row: only service_id may be repointed for a given customer_id.
        UPDATE telecom.customer_service
        SET service_id = COALESCE(JSON_VALUE(@Json,'$.service_id'), service_id)
        WHERE customer_id = @Id1 AND service_id = @Id2;
    END
    ELSE
    BEGIN
        RAISERROR('usp_Update: Unknown @TableName ''%s''.', 16, 1, @TableName);
        RETURN -1;
    END
END
GO


-- =============================================================================
-- 4) telecom.usp_Delete
--    Generic DELETE for all tables.
--    @Id1 (+ @Id2 for junction tables) identifies the row to delete.
-- =============================================================================
CREATE OR ALTER PROCEDURE telecom.usp_Delete
    @TableName NVARCHAR(50),
    @Id1       NVARCHAR(20),
    @Id2       NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @TableName = 'customer'
        DELETE FROM telecom.customer WHERE customer_id = @Id1;
    ELSE IF @TableName = 'location'
        DELETE FROM telecom.location WHERE location_id = @Id1;
    ELSE IF @TableName = 'quarter'
        DELETE FROM telecom.quarter WHERE quarter_id = @Id1;
    ELSE IF @TableName = 'subscription'
        DELETE FROM telecom.subscription WHERE sub_id = @Id1;
    ELSE IF @TableName = 'service'
        DELETE FROM telecom.service WHERE service_id = @Id1;
    ELSE IF @TableName = 'behavior'
        DELETE FROM telecom.behavior WHERE behavior_id = @Id1;
    ELSE IF @TableName = 'billing'
        DELETE FROM telecom.billing WHERE billing_id = @Id1;
    ELSE IF @TableName = 'customer_loyalty'
        DELETE FROM telecom.customer_loyalty WHERE loyalty_id = @Id1;
    ELSE IF @TableName = 'churn_report'
        DELETE FROM telecom.churn_report WHERE churn_id = @Id1;
    ELSE IF @TableName = 'customer_churn_report'
        DELETE FROM telecom.customer_churn_report WHERE customer_id = @Id1 AND churn_id = @Id2;
    ELSE IF @TableName = 'customer_service'
        DELETE FROM telecom.customer_service WHERE customer_id = @Id1 AND service_id = @Id2;
    ELSE
    BEGIN
        RAISERROR('usp_Delete: Unknown @TableName ''%s''.', 16, 1, @TableName);
        RETURN -1;
    END
END
GO

-- =============================================================================
-- END OF FILE: 02_stored_procedures.sql
-- =============================================================================
