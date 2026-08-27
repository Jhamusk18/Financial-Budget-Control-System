-- ============================================================
-- Financial Performance & Budget Control System
-- 03_analysis_queries.sql
--
-- Each query is standalone and commented. They are grouped into the
-- three analytical roles the project is built around:
--   A. Budget vs Actual comparison
--   B. Statistical outlier / anomaly detection
--   C. Financial summaries by department and period
--
-- Written for PostgreSQL / SQL Server 2012+ (window functions, CTEs).
-- Notes flag the few dialect differences (STDEV vs STDDEV, etc.).
-- ============================================================


-- ============================================================
-- A. BUDGET vs ACTUAL
-- ============================================================

-- A1) Monthly budget vs actual per department & category, with variance.
--     Positive variance = overspend. This is the core reconciliation view
--     and the primary source table for the Power BI "Budget vs Actual" page.
WITH actual_monthly AS (
    SELECT department_id, period, category,
           SUM(amount) AS actual_amount
    FROM   fact_actuals
    GROUP  BY department_id, period, category
)
SELECT  d.department_name,
        b.period,
        b.category,
        b.budget_amount,
        COALESCE(a.actual_amount, 0)                          AS actual_amount,
        COALESCE(a.actual_amount, 0) - b.budget_amount        AS variance,
        ROUND( 100.0 * (COALESCE(a.actual_amount,0) - b.budget_amount)
               / NULLIF(b.budget_amount, 0), 1)               AS variance_pct,
        CASE
            WHEN COALESCE(a.actual_amount,0) > b.budget_amount THEN 'Over Budget'
            WHEN COALESCE(a.actual_amount,0) < b.budget_amount THEN 'Under Budget'
            ELSE 'On Budget'
        END                                                    AS status
FROM        fact_budget b
JOIN        dim_department d ON d.department_id = b.department_id
LEFT JOIN   actual_monthly  a ON a.department_id = b.department_id
                             AND a.period        = b.period
                             AND a.category      = b.category
ORDER BY    b.period, d.department_name, b.category;


-- A2) Departments currently over budget for the latest available month,
--     ranked by overspend amount. Feeds the dashboard's "top overspenders" card.
WITH latest AS (
    SELECT MAX(period) AS max_period FROM fact_budget
),
actual_monthly AS (
    SELECT department_id, period, SUM(amount) AS actual_amount
    FROM fact_actuals GROUP BY department_id, period
),
budget_monthly AS (
    SELECT department_id, period, SUM(budget_amount) AS budget_amount
    FROM fact_budget GROUP BY department_id, period
)
SELECT  d.department_name,
        bm.budget_amount,
        am.actual_amount,
        am.actual_amount - bm.budget_amount AS overspend,
        RANK() OVER (ORDER BY am.actual_amount - bm.budget_amount DESC) AS overspend_rank
FROM        budget_monthly bm
JOIN        actual_monthly am ON am.department_id = bm.department_id
                             AND am.period        = bm.period
JOIN        dim_department d  ON d.department_id  = bm.department_id
CROSS JOIN  latest l
WHERE       bm.period = l.max_period
  AND       am.actual_amount > bm.budget_amount
ORDER BY    overspend DESC;


-- A3) Year-to-date (cumulative) budget vs actual per department,
--     using a running total window. Shows whether a department is
--     drifting off-plan cumulatively even if a single month looks fine.
WITH monthly AS (
    SELECT  b.department_id, b.period,
            SUM(b.budget_amount) AS budget_amount,
            SUM(COALESCE(a.actual_amount,0)) AS actual_amount
    FROM    fact_budget b
    LEFT JOIN (
                SELECT department_id, period, category, SUM(amount) AS actual_amount
                FROM fact_actuals GROUP BY department_id, period, category
             ) a
           ON a.department_id = b.department_id
          AND a.period        = b.period
          AND a.category      = b.category
    GROUP BY b.department_id, b.period
)
SELECT  d.department_name,
        m.period,
        SUM(m.budget_amount) OVER (PARTITION BY m.department_id
                                   ORDER BY m.period) AS ytd_budget,
        SUM(m.actual_amount) OVER (PARTITION BY m.department_id
                                   ORDER BY m.period) AS ytd_actual
FROM    monthly m
JOIN    dim_department d ON d.department_id = m.department_id
ORDER BY d.department_name, m.period;


-- ============================================================
-- B. STATISTICAL OUTLIER / ANOMALY DETECTION
-- ============================================================

-- B1) Z-score method.
--     For each department+category, compute the mean and standard deviation
--     of monthly actual spend across history, then flag any month whose
--     spend sits more than 2 standard deviations from that mean.
--     (PostgreSQL: STDDEV_SAMP ; SQL Server: STDEV)
WITH monthly_spend AS (
    SELECT department_id, category, period, SUM(amount) AS actual_amount
    FROM   fact_actuals
    GROUP  BY department_id, category, period
),
stats AS (
    SELECT department_id, category,
           AVG(actual_amount)          AS mean_spend,
           STDDEV_SAMP(actual_amount)  AS sd_spend      -- SQL Server: STDEV(actual_amount)
    FROM   monthly_spend
    GROUP  BY department_id, category
)
SELECT  d.department_name,
        ms.category,
        ms.period,
        ms.actual_amount,
        ROUND(s.mean_spend, 2)                                    AS mean_spend,
        ROUND( (ms.actual_amount - s.mean_spend)
               / NULLIF(s.sd_spend, 0), 2)                        AS z_score,
        CASE WHEN ABS( (ms.actual_amount - s.mean_spend)
                        / NULLIF(s.sd_spend,0) ) > 2
             THEN 'Outlier' ELSE 'Normal' END                     AS flag
FROM        monthly_spend ms
JOIN        stats s        ON s.department_id = ms.department_id
                          AND s.category      = ms.category
JOIN        dim_department d ON d.department_id = ms.department_id
WHERE       ABS( (ms.actual_amount - s.mean_spend) / NULLIF(s.sd_spend,0) ) > 2
ORDER BY    ABS( (ms.actual_amount - s.mean_spend) / NULLIF(s.sd_spend,0) ) DESC;


-- B2) IQR (interquartile range) method — a non-parametric alternative to Z-score,
--     more robust when spend is skewed. Flags months outside
--     [Q1 - 1.5*IQR , Q3 + 1.5*IQR]. Uses PERCENTILE_CONT.
--     (PostgreSQL supports WITHIN GROUP; SQL Server 2012+ has PERCENTILE_CONT as a window fn.)
WITH monthly_spend AS (
    SELECT department_id, category, period, SUM(amount) AS actual_amount
    FROM   fact_actuals
    GROUP  BY department_id, category, period
),
quartiles AS (
    SELECT department_id, category,
           PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY actual_amount) AS q1,
           PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY actual_amount) AS q3
    FROM   monthly_spend
    GROUP  BY department_id, category
)
SELECT  d.department_name,
        ms.category,
        ms.period,
        ms.actual_amount,
        ROUND(q.q1,2) AS q1,
        ROUND(q.q3,2) AS q3,
        'Outlier' AS flag
FROM        monthly_spend ms
JOIN        quartiles q     ON q.department_id = ms.department_id
                          AND q.category      = ms.category
JOIN        dim_department d ON d.department_id = ms.department_id
WHERE       ms.actual_amount < q.q1 - 1.5 * (q.q3 - q.q1)
   OR       ms.actual_amount > q.q3 + 1.5 * (q.q3 - q.q1)
ORDER BY    d.department_name, ms.category, ms.period;


-- B3) Month-over-month spike detection using LAG().
--     Flags any category whose spend jumped more than 40% versus the prior month —
--     a fast "sudden change" alert independent of the full-history distribution.
WITH monthly_spend AS (
    SELECT department_id, category, period, SUM(amount) AS actual_amount
    FROM   fact_actuals
    GROUP  BY department_id, category, period
),
with_prev AS (
    SELECT department_id, category, period, actual_amount,
           LAG(actual_amount) OVER (PARTITION BY department_id, category
                                    ORDER BY period) AS prev_amount
    FROM monthly_spend
)
SELECT  d.department_name,
        w.category,
        w.period,
        w.prev_amount,
        w.actual_amount,
        ROUND(100.0 * (w.actual_amount - w.prev_amount)
              / NULLIF(w.prev_amount,0), 1) AS mom_change_pct
FROM        with_prev w
JOIN        dim_department d ON d.department_id = w.department_id
WHERE       w.prev_amount IS NOT NULL
  AND       ABS(w.actual_amount - w.prev_amount) / NULLIF(w.prev_amount,0) > 0.40
ORDER BY    ABS(w.actual_amount - w.prev_amount) / NULLIF(w.prev_amount,0) DESC;


-- ============================================================
-- C. FINANCIAL SUMMARIES BY DEPARTMENT AND PERIOD
-- ============================================================

-- C1) Department-level spend summary with share of total company spend.
WITH dept_spend AS (
    SELECT department_id, SUM(amount) AS total_spend
    FROM   fact_actuals
    GROUP  BY department_id
)
SELECT  d.department_name,
        d.region,
        ds.total_spend,
        ROUND(100.0 * ds.total_spend
              / SUM(ds.total_spend) OVER (), 1) AS pct_of_company_spend,
        RANK() OVER (ORDER BY ds.total_spend DESC) AS spend_rank
FROM    dept_spend ds
JOIN    dim_department d ON d.department_id = ds.department_id
ORDER BY ds.total_spend DESC;


-- C2) Category spend by period (pivot-friendly long form for Power BI matrix).
SELECT  a.period,
        a.category,
        SUM(a.amount) AS actual_amount
FROM    fact_actuals a
GROUP BY a.period, a.category
ORDER BY a.period, a.category;


-- C3) Overall budget utilisation per department (actual / budget) across all history,
--     a single KPI-style number per department for the dashboard summary cards.
WITH tot_actual AS (
    SELECT department_id, SUM(amount) AS actual_amount
    FROM fact_actuals GROUP BY department_id
),
tot_budget AS (
    SELECT department_id, SUM(budget_amount) AS budget_amount
    FROM fact_budget GROUP BY department_id
)
SELECT  d.department_name,
        tb.budget_amount,
        ta.actual_amount,
        ROUND(100.0 * ta.actual_amount / NULLIF(tb.budget_amount,0), 1)
            AS utilisation_pct
FROM        tot_budget tb
JOIN        tot_actual ta ON ta.department_id = tb.department_id
JOIN        dim_department d ON d.department_id = tb.department_id
ORDER BY    utilisation_pct DESC;
