# Financial Performance & Budget Control System

An end-to-end **SQL + Power BI** analytics project that tracks organisational
spending against budgets, detects unusual cost patterns with statistical logic,
and presents the results in an interactive finance dashboard.

## What it does
- **Compares actual spend against planned budgets** at department, category, and
  period grain, with variance and variance-% calculations.
- **Detects cost outliers** using three complementary methods: Z-score,
  interquartile range (IQR), and month-over-month spike detection.
- **Summarises financial data** by department, region, and time — spend share,
  budget utilisation, YTD drift.
- **Visualises everything** in a three-page Power BI report (Budget vs Actual,
  Department Breakdown, Anomaly Monitor).

## Dataset
Synthetic but realistic finance data for a mid-size company:
- **8 departments** across 4 regions
- **18 months** of history (Jan 2024 – Jun 2025)
- **8 spend categories** (Salaries, Travel, Software, Marketing, Facilities,
  Training, Equipment, Consulting)
- **1,152 budget rows** and **~4,700 actual transactions**
- A handful of deliberately injected spend anomalies so the outlier logic has
  something real to catch.

Regenerate it any time with `python generate_data.py` (seeded, reproducible).

## Repository structure
```
.
├── generate_data.py            # reproducible synthetic-data generator
├── data/
│   ├── dim_department.csv       # department master
│   ├── fact_budget.csv          # planned budget (dept × month × category)
│   └── fact_actuals.csv         # actual spend transactions
├── sql/
│   ├── 01_schema.sql            # table definitions + indexes
│   ├── 02_load_data.sql         # load CSVs (Postgres / SQL Server / Power BI)
│   └── 03_analysis_queries.sql  # budget-vs-actual, outliers, summaries
└── powerbi/
    ├── data_model.md            # import, date table, star-schema relationships
    ├── dax_measures.md          # variance, utilisation, Z-score anomaly measures
    └── dashboard_design.md      # 3-page dashboard layout
```

## How to run

**Option A — full stack (SQL database + Power BI)**
1. Run `sql/01_schema.sql` on PostgreSQL or SQL Server.
2. Load the CSVs using `sql/02_load_data.sql`.
3. Explore with `sql/03_analysis_queries.sql`.
4. Connect Power BI to the database and build the report per `powerbi/`.

**Option B — Power BI only (no database)**
Import the three CSVs directly into Power BI Desktop and follow
`powerbi/data_model.md` → `dax_measures.md` → `dashboard_design.md`.

## Techniques demonstrated
SQL window functions (`LAG`, `RANK`, running totals), CTEs, `PERCENTILE_CONT`,
statistical aggregation (`STDDEV`), star-schema data modelling, DAX time
intelligence, and anomaly detection translated into both SQL and DAX.

## Tech stack
PostgreSQL / SQL Server · Power BI Desktop (DAX, Power Query) · Python (data generation)
