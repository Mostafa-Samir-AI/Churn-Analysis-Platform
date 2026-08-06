-- =============================================================================
-- FILE: 05_jobs.sql
-- PROJECT: Telecom Customer Analytics & Churn Analysis System
-- DESCRIPTION: SQL Server Agent jobs. Each job performs maintenance/reporting
--              work that is NOT already handled by the CRUD stored procedures,
--              functions, or triggers (those act on individual rows at DML
--              time; these jobs act on the whole database on a schedule).
--
--              Requires SQL Server Agent to be running and msdb accessible.
--              Re-runnable: each job is dropped first if it already exists.
-- DBMS: Microsoft SQL Server 2016+
-- =============================================================================

USE msdb;
GO

DECLARE @JobId UNIQUEIDENTIFIER;

-- =============================================================================
-- JOB 1: Telecom - Nightly Audit Log Purge
--    Deletes telecom.audit_log rows older than 90 days so the audit table
--    does not grow unbounded. Runs daily at 02:00.
-- =============================================================================
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'Telecom - Nightly Audit Log Purge')
    EXEC msdb.dbo.sp_delete_job @job_name = N'Telecom - Nightly Audit Log Purge', @delete_unused_schedule = 1;
GO

EXEC msdb.dbo.sp_add_job
    @job_name        = N'Telecom - Nightly Audit Log Purge',
    @enabled          = 1,
    @description      = N'Purges telecom.audit_log entries older than 90 days.',
    @category_name    = N'Database Maintenance',
    @owner_login_name = N'sa';
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name        = N'Telecom - Nightly Audit Log Purge',
    @step_name        = N'Purge old audit rows',
    @subsystem        = N'TSQL',
    @database_name    = N'telecom_churn_db',
    @command          = N'
DELETE FROM telecom.audit_log
WHERE changed_at < DATEADD(DAY, -90, SYSDATETIME());
',
    @on_success_action = 1,
    @on_fail_action     = 2;
GO

EXEC msdb.dbo.sp_add_schedule
    @schedule_name     = N'Daily_0200',
    @freq_type          = 4,          -- daily
    @freq_interval      = 1,
    @active_start_time  = 020000;
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name      = N'Telecom - Nightly Audit Log Purge',
    @schedule_name  = N'Daily_0200';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name    = N'Telecom - Nightly Audit Log Purge',
    @server_name  = N'(LOCAL)';
GO


-- =============================================================================
-- JOB 2: Telecom - Weekly Data Integrity Check
--    Scans for cross-table inconsistencies that constraints don't already
--    prevent (e.g. orphaned junction rows, out-of-range churn scores,
--    dependents/no_dependents mismatches) and logs findings to
--    telecom.audit_log so they can be reviewed and cleaned up.
--    Runs weekly, Sunday at 03:00.
-- =============================================================================
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'Telecom - Weekly Data Integrity Check')
    EXEC msdb.dbo.sp_delete_job @job_name = N'Telecom - Weekly Data Integrity Check', @delete_unused_schedule = 1;
GO

EXEC msdb.dbo.sp_add_job
    @job_name        = N'Telecom - Weekly Data Integrity Check',
    @enabled          = 1,
    @description      = N'Scans for data-quality issues and logs findings to telecom.audit_log.',
    @category_name    = N'Database Maintenance',
    @owner_login_name = N'sa';
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name        = N'Telecom - Weekly Data Integrity Check',
    @step_name        = N'Run integrity scan',
    @subsystem        = N'TSQL',
    @database_name    = N'telecom_churn_db',
    @command          = N'
-- Customers whose dependents flag disagrees with no_dependents count
INSERT INTO telecom.audit_log (table_name, operation, record_id, details)
SELECT ''customer'', ''INTEGRITY_CHECK'', customer_id,
       CONCAT(''dependents/no_dependents mismatch: dependents='', dependents, '', no_dependents='', no_dependents)
FROM telecom.customer
WHERE (no_dependents > 0 AND dependents = 0)
   OR (no_dependents = 0 AND dependents = 1);

-- Churn scores outside the valid 0-100 range
INSERT INTO telecom.audit_log (table_name, operation, record_id, details)
SELECT ''churn_report'', ''INTEGRITY_CHECK'', churn_id,
       CONCAT(''churn_score out of range: '', churn_score)
FROM telecom.churn_report
WHERE churn_score < 0 OR churn_score > 100;

-- Customers with a subscription/billing/service row pointing at a
-- non-existent customer (should be impossible under FKs, kept as a safety net)
INSERT INTO telecom.audit_log (table_name, operation, record_id, details)
SELECT ''billing'', ''INTEGRITY_CHECK'', b.billing_id, ''Orphaned billing row: no matching customer_id''
FROM telecom.billing b
WHERE NOT EXISTS (SELECT 1 FROM telecom.customer c WHERE c.customer_id = b.customer_id);

-- customer_loyalty rows with cltv <= 0 (suspicious / needs review)
INSERT INTO telecom.audit_log (table_name, operation, record_id, details)
SELECT ''customer_loyalty'', ''INTEGRITY_CHECK'', loyalty_id,
       CONCAT(''Non-positive CLTV: '', cltv)
FROM telecom.customer_loyalty
WHERE cltv <= 0;
',
    @on_success_action = 1,
    @on_fail_action     = 2;
GO

EXEC msdb.dbo.sp_add_schedule
    @schedule_name     = N'Weekly_Sun_0300',
    @freq_type          = 8,          -- weekly
    @freq_interval      = 1,          -- Sunday
    @freq_recurrence_factor = 1,
    @active_start_time  = 030000;
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name      = N'Telecom - Weekly Data Integrity Check',
    @schedule_name  = N'Weekly_Sun_0300';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name    = N'Telecom - Weekly Data Integrity Check',
    @server_name  = N'(LOCAL)';
GO


-- =============================================================================
-- JOB 3: Telecom - Monthly CLTV & Churn Risk Report
--    Uses telecom.ufn_CLTVTier / telecom.ufn_ChurnRiskLevel to summarize the
--    customer base into tiers/risk bands and logs the counts to
--    telecom.audit_log as a lightweight monthly snapshot report.
--    Runs on the 1st of every month at 04:00.
-- =============================================================================
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'Telecom - Monthly CLTV & Churn Risk Report')
    EXEC msdb.dbo.sp_delete_job @job_name = N'Telecom - Monthly CLTV & Churn Risk Report', @delete_unused_schedule = 1;
GO

EXEC msdb.dbo.sp_add_job
    @job_name        = N'Telecom - Monthly CLTV & Churn Risk Report',
    @enabled          = 1,
    @description      = N'Summarizes CLTV tiers and churn risk bands and logs the snapshot.',
    @category_name    = N'Data Collector',
    @owner_login_name = N'sa';
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name        = N'Telecom - Monthly CLTV & Churn Risk Report',
    @step_name        = N'Build snapshot summary',
    @subsystem        = N'TSQL',
    @database_name    = N'telecom_churn_db',
    @command          = N'
DECLARE @CltvSummary NVARCHAR(MAX);
DECLARE @RiskSummary NVARCHAR(MAX);

SELECT @CltvSummary = (
    SELECT telecom.ufn_CLTVTier(cl.cltv) AS cltv_tier, COUNT(*) AS customer_count
    FROM telecom.customer_loyalty cl
    GROUP BY telecom.ufn_CLTVTier(cl.cltv)
    FOR JSON PATH
);

SELECT @RiskSummary = (
    SELECT telecom.ufn_ChurnRiskLevel(cr.churn_score) AS churn_risk_level, COUNT(*) AS customer_count
    FROM telecom.churn_report cr
    GROUP BY telecom.ufn_ChurnRiskLevel(cr.churn_score)
    FOR JSON PATH
);

INSERT INTO telecom.audit_log (table_name, operation, record_id, details)
VALUES (
    ''ALL'', ''INTEGRITY_CHECK'', ''MONTHLY_SNAPSHOT'',
    CONCAT(
        ''{"cltv_tiers":'', ISNULL(@CltvSummary, ''[]''),
        '',"churn_risk_levels":'', ISNULL(@RiskSummary, ''[]''), ''}''
    )
);
',
    @on_success_action = 1,
    @on_fail_action     = 2;
GO

EXEC msdb.dbo.sp_add_schedule
    @schedule_name     = N'Monthly_Day1_0400',
    @freq_type          = 16,         -- monthly
    @freq_interval      = 1,          -- day 1 of month
    @freq_recurrence_factor = 1,
    @active_start_time  = 040000;
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name      = N'Telecom - Monthly CLTV & Churn Risk Report',
    @schedule_name  = N'Monthly_Day1_0400';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name    = N'Telecom - Monthly CLTV & Churn Risk Report',
    @server_name  = N'(LOCAL)';
GO

-- =============================================================================
-- END OF FILE: 05_jobs.sql
-- =============================================================================
