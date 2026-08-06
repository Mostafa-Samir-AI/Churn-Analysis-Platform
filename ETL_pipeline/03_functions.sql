-- =============================================================================
-- FILE: 03_functions.sql
-- PROJECT: Telecom Customer Analytics & Churn Analysis System
-- DESCRIPTION: Reusable scalar and table-valued functions. None of these
--              duplicate logic already implemented by the CRUD stored
--              procedures, triggers, or jobs -- they are read-only helpers
--              meant to be called from queries, reports, or other objects.
-- DBMS: Microsoft SQL Server 2016+
-- =============================================================================

USE telecom_churn_db;
GO

-- =============================================================================
-- 1) telecom.ufn_ChurnRiskLevel
--    Classifies a churn_score (0-100) into a business-friendly risk band.
-- =============================================================================
CREATE OR ALTER FUNCTION telecom.ufn_ChurnRiskLevel (@churn_score INT)
RETURNS NVARCHAR(20)
AS
BEGIN
    DECLARE @Level NVARCHAR(20);

    SET @Level = CASE
        WHEN @churn_score IS NULL       THEN 'Unknown'
        WHEN @churn_score >= 80         THEN 'Critical'
        WHEN @churn_score >= 60         THEN 'High'
        WHEN @churn_score >= 40         THEN 'Medium'
        ELSE                                  'Low'
    END;

    RETURN @Level;
END
GO


-- =============================================================================
-- 2) telecom.ufn_TenureYears
--    Converts tenure in months (customer_loyalty.tenure_months) to years,
--    rounded to 2 decimal places -- useful for reporting/grouping.
-- =============================================================================
CREATE OR ALTER FUNCTION telecom.ufn_TenureYears (@tenure_months INT)
RETURNS DECIMAL(6,2)
AS
BEGIN
    DECLARE @Years DECIMAL(6,2);

    SET @Years = CASE
        WHEN @tenure_months IS NULL THEN 0
        ELSE CAST(@tenure_months AS DECIMAL(8,2)) / 12.0
    END;

    RETURN @Years;
END
GO


-- =============================================================================
-- 3) telecom.ufn_CLTVTier
--    Buckets a customer_loyalty.cltv value into a marketing tier.
-- =============================================================================
CREATE OR ALTER FUNCTION telecom.ufn_CLTVTier (@cltv INT)
RETURNS NVARCHAR(20)
AS
BEGIN
    DECLARE @Tier NVARCHAR(20);

    SET @Tier = CASE
        WHEN @cltv IS NULL   THEN 'Unknown'
        WHEN @cltv >= 5000   THEN 'Platinum'
        WHEN @cltv >= 3000   THEN 'Gold'
        WHEN @cltv >= 1500   THEN 'Silver'
        ELSE                      'Bronze'
    END;

    RETURN @Tier;
END
GO


-- =============================================================================
-- 4) telecom.ufn_NetRevenue
--    Computes net revenue for a billing row: revenue minus refunds and
--    extra/one-off charges are kept separate on purpose (extra data charges
--    are additional revenue, not a deduction).
-- =============================================================================
CREATE OR ALTER FUNCTION telecom.ufn_NetRevenue
(
    @total_revenue DECIMAL(12,2),
    @total_refunds DECIMAL(10,2)
)
RETURNS DECIMAL(12,2)
AS
BEGIN
    RETURN ISNULL(@total_revenue, 0) - ISNULL(@total_refunds, 0);
END
GO


-- =============================================================================
-- 5) telecom.ufn_CustomerFinancialSummary
--    Inline table-valued function returning a one-row financial + loyalty +
--    churn snapshot for a given customer_id. Combines several tables so
--    reports don't need to repeat the join logic.
-- =============================================================================
CREATE OR ALTER FUNCTION telecom.ufn_CustomerFinancialSummary (@customer_id NVARCHAR(20))
RETURNS TABLE
AS
RETURN
(
    SELECT
        c.customer_id,
        c.gender,
        c.age,
        b.monthly_charges,
        b.total_charges,
        telecom.ufn_NetRevenue(b.total_revenue, b.total_refunds) AS net_revenue,
        cl.cltv,
        telecom.ufn_CLTVTier(cl.cltv)                            AS cltv_tier,
        cl.tenure_months,
        telecom.ufn_TenureYears(cl.tenure_months)                AS tenure_years,
        cr.churn_score,
        telecom.ufn_ChurnRiskLevel(cr.churn_score)                AS churn_risk_level,
        cr.churn_label
    FROM telecom.customer c
    LEFT JOIN telecom.billing b
           ON b.customer_id = c.customer_id
    LEFT JOIN telecom.customer_loyalty cl
           ON cl.customer_id = c.customer_id
    LEFT JOIN telecom.customer_churn_report ccr
           ON ccr.customer_id = c.customer_id
    LEFT JOIN telecom.churn_report cr
           ON cr.churn_id = ccr.churn_id
    WHERE c.customer_id = @customer_id
);
GO

-- =============================================================================
-- END OF FILE: 03_functions.sql
-- =============================================================================
