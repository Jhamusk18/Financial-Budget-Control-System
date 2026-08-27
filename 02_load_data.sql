-- ============================================================
-- 02_load_data.sql  —  load the generated CSVs into the tables
-- Pick the block matching your database. Run 01_schema.sql first.
-- ============================================================

-- ---------- PostgreSQL ----------
-- Adjust the absolute paths to where you unzipped /data.
-- \copy runs client-side and needs no superuser privileges.
--
-- \copy dim_department FROM 'data/dim_department.csv' WITH (FORMAT csv, HEADER true);
-- \copy fact_budget    FROM 'data/fact_budget.csv'    WITH (FORMAT csv, HEADER true);
-- \copy fact_actuals   FROM 'data/fact_actuals.csv'   WITH (FORMAT csv, HEADER true);


-- ---------- SQL Server ----------
-- BULK INSERT dim_department
--   FROM 'C:\path\to\data\dim_department.csv'
--   WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);
-- BULK INSERT fact_budget
--   FROM 'C:\path\to\data\fact_budget.csv'
--   WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);
-- BULK INSERT fact_actuals
--   FROM 'C:\path\to\data\fact_actuals.csv'
--   WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);


-- ---------- Power BI direct import (no database needed) ----------
-- You can skip SQL loading entirely: in Power BI Desktop use
--   Home > Get Data > Text/CSV  and import each of the three CSVs.
-- Then recreate the joins in Model view (see powerbi/data_model.md).
