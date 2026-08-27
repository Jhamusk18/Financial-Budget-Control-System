-- ============================================================
-- Financial Performance & Budget Control System
-- 01_schema.sql  —  table definitions (ANSI SQL / PostgreSQL / SQL Server 2012+)
-- ============================================================

DROP TABLE IF EXISTS fact_actuals;
DROP TABLE IF EXISTS fact_budget;
DROP TABLE IF EXISTS dim_department;

-- Department master ------------------------------------------------
CREATE TABLE dim_department (
    department_id    INT           PRIMARY KEY,
    department_name  VARCHAR(60)   NOT NULL,
    cost_center      VARCHAR(20)   NOT NULL,
    region           VARCHAR(20)   NOT NULL
);

-- Planned budget (one row per dept x month x category) -------------
CREATE TABLE fact_budget (
    budget_id        INT           PRIMARY KEY,
    department_id    INT           NOT NULL REFERENCES dim_department(department_id),
    period           DATE          NOT NULL,          -- first day of month
    category         VARCHAR(40)   NOT NULL,
    budget_amount    DECIMAL(14,2) NOT NULL
);

-- Actual spend transactions ---------------------------------------
CREATE TABLE fact_actuals (
    txn_id           INT           PRIMARY KEY,
    department_id    INT           NOT NULL REFERENCES dim_department(department_id),
    period           DATE          NOT NULL,          -- first day of month
    category         VARCHAR(40)   NOT NULL,
    txn_date         DATE          NOT NULL,
    vendor           VARCHAR(60),
    amount           DECIMAL(14,2) NOT NULL
);

-- Helpful indexes for the analytical queries ----------------------
CREATE INDEX ix_budget_dept_period  ON fact_budget (department_id, period, category);
CREATE INDEX ix_actuals_dept_period ON fact_actuals (department_id, period, category);
