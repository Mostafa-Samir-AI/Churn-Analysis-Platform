-- =============================================================================
-- FILE: 04_triggers.sql
-- PROJECT: Telecom Customer Analytics & Churn Analysis System
-- DESCRIPTION: Triggers for consistency enforcement, derived-value maintenance,
--              validation, and audit logging. Each trigger does something the
--              CRUD stored procedures and functions do NOT already do:
--                - SPs move data in/out; they do not enforce cross-column
--                  business rules or maintain derived columns.
--                - Functions are read-only helpers; they do not write data.
--              Triggers fire on the base tables regardless of whether the
--              DML came from the generic SPs, ad-hoc statements, or the
--              nightly jobs, so the rules below are always enforced.
-- DBMS: Microsoft SQL Server 2016+ (RECURSIVE_TRIGGERS is OFF by default,
--       so same-table AFTER-trigger updates below do not self-recurse)
-- =============================================================================

USE telecom_churn_db;
GO

-- =============================================================================
-- 0) SUPPORT TABLE: telecom.audit_log
--    Generic audit trail used by the audit trigger(s) below and by the
--    maintenance jobs (05_jobs.sql) for integrity-check findings.
-- =============================================================================
IF OBJECT_ID('telecom.audit_log', 'U') IS NULL
BEGIN
    CREATE TABLE telecom.audit_log (
        log_id      INT IDENTITY(1,1) NOT NULL,
        table_name  NVARCHAR(50)      NOT NULL,
        operation   NVARCHAR(20)      NOT NULL,   -- 'INSERT' / 'UPDATE' / 'DELETE' / 'INTEGRITY_CHECK'
        record_id   NVARCHAR(100)     NULL,
        changed_by  NVARCHAR(128)     NOT NULL CONSTRAINT df_audit_changed_by DEFAULT SUSER_SNAME(),
        changed_at  DATETIME2(3)      NOT NULL CONSTRAINT df_audit_changed_at DEFAULT SYSDATETIME(),
        details     NVARCHAR(MAX)     NULL,
        CONSTRAINT pk_audit_log PRIMARY KEY (log_id)
    );
END
GO


-- =============================================================================
-- 1) trg_customer_DependentsConsistency
--    Table: telecom.customer | Event: AFTER INSERT, UPDATE
--    Keeps the `dependents` BIT flag consistent with `no_dependents` count:
--      - no_dependents > 0  => dependents must be 1
--      - no_dependents = 0  => dependents must be 0
-- =============================================================================
CREATE OR ALTER TRIGGER telecom.trg_customer_DependentsConsistency
ON telecom.customer
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE c
    SET c.dependents = CASE WHEN i.no_dependents > 0 THEN 1 ELSE 0 END
    FROM telecom.customer c
    INNER JOIN inserted i ON i.customer_id = c.customer_id
    WHERE c.dependents <> CASE WHEN i.no_dependents > 0 THEN 1 ELSE 0 END;
END
GO


-- =============================================================================
-- 2) trg_billing_CalcNetRevenue
--    Table: telecom.billing | Event: AFTER INSERT, UPDATE
--    Auto-derives total_revenue whenever the charges/refunds that feed it
--    change, using the same formula exposed by telecom.ufn_NetRevenue plus
--    the recurring long-distance component.
-- =============================================================================
CREATE OR ALTER TRIGGER telecom.trg_billing_CalcNetRevenue
ON telecom.billing
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(total_charges) AND NOT UPDATE(total_refunds)
       AND NOT UPDATE(total_extra_data_charges) AND NOT UPDATE(total_long_distance_charges)
       AND NOT UPDATE(monthly_charges)
        RETURN;

    UPDATE b
    SET b.total_revenue = i.total_charges - i.total_refunds
                           + i.total_extra_data_charges + i.total_long_distance_charges
    FROM telecom.billing b
    INNER JOIN inserted i ON i.billing_id = b.billing_id;
END
GO


-- =============================================================================
-- 3) trg_customerloyalty_ReferralStatus
--    Table: telecom.customer_loyalty | Event: AFTER INSERT, UPDATE
--    Automatically flags referral_status = 1 whenever number_of_referrals > 0.
-- =============================================================================
CREATE OR ALTER TRIGGER telecom.trg_customerloyalty_ReferralStatus
ON telecom.customer_loyalty
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(number_of_referrals)
        RETURN;

    UPDATE cl
    SET cl.referral_status = CASE WHEN i.number_of_referrals > 0 THEN 1 ELSE 0 END
    FROM telecom.customer_loyalty cl
    INNER JOIN inserted i ON i.loyalty_id = cl.loyalty_id
    WHERE cl.referral_status <> CASE WHEN i.number_of_referrals > 0 THEN 1 ELSE 0 END;
END
GO


-- =============================================================================
-- 4) trg_churnreport_ValidateScore
--    Table: telecom.churn_report | Event: INSTEAD OF INSERT, UPDATE
--    Rejects rows where churn_score is outside 0-100, or where churn_label
--    disagrees with churn_value ('Yes' must pair with 1, 'No' with 0).
-- =============================================================================
CREATE OR ALTER TRIGGER telecom.trg_churnreport_ValidateScore
ON telecom.churn_report
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted WHERE churn_score < 0 OR churn_score > 100)
    BEGIN
        RAISERROR('trg_churnreport_ValidateScore: churn_score must be between 0 and 100.', 16, 1);
        RETURN;
    END

    IF EXISTS (
        SELECT 1 FROM inserted
        WHERE (churn_value = 1 AND churn_label <> 'Yes')
           OR (churn_value = 0 AND churn_label <> 'No')
    )
    BEGIN
        RAISERROR('trg_churnreport_ValidateScore: churn_label must match churn_value (Yes=1 / No=0).', 16, 1);
        RETURN;
    END

    -- Validation passed: perform the real write.
    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        -- UPDATE path
        UPDATE cr
        SET churn_label  = i.churn_label,
            churn_value   = i.churn_value,
            churn_score   = i.churn_score,
            churn_reason  = i.churn_reason
        FROM telecom.churn_report cr
        INNER JOIN inserted i ON i.churn_id = cr.churn_id;
    END
    ELSE
    BEGIN
        -- INSERT path
        INSERT INTO telecom.churn_report (churn_id, churn_label, churn_value, churn_score, churn_reason)
        SELECT churn_id, churn_label, churn_value, churn_score, churn_reason
        FROM inserted;
    END
END
GO


-- =============================================================================
-- 5) trg_customer_AuditDelete
--    Table: telecom.customer | Event: AFTER DELETE
--    Writes a permanent audit trail entry whenever a customer row is removed
--    (customer deletion cascades to most other tables, so this is the single
--    most important delete to track).
-- =============================================================================
CREATE OR ALTER TRIGGER telecom.trg_customer_AuditDelete
ON telecom.customer
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO telecom.audit_log (table_name, operation, record_id, details)
    SELECT
        'customer',
        'DELETE',
        d.customer_id,
        CONCAT('gender=', d.gender, '; age=', d.age, '; referred_by=', ISNULL(d.referred_by, 'NULL'))
    FROM deleted d;
END
GO

-- =============================================================================
-- END OF FILE: 04_triggers.sql
-- =============================================================================
