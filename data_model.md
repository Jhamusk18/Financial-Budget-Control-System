# Power BI — Data Model

## Import the data
`Home → Get Data → Text/CSV` and load all three files from `/data`:
`dim_department.csv`, `fact_budget.csv`, `fact_actuals.csv`.

Confirm column data types in Power Query:
- `period`, `txn_date` → **Date**
- `budget_amount`, `amount` → **Decimal Number**
- all `*_id` → **Whole Number**

## Add a Date table
Create a dedicated date dimension so time intelligence works cleanly:

```
DimDate =
ADDCOLUMNS(
    CALENDAR(DATE(2024,1,1), DATE(2025,6,30)),
    "Year",        YEAR([Date]),
    "MonthNo",     MONTH([Date]),
    "MonthName",   FORMAT([Date],"MMM"),
    "MonthStart",  DATE(YEAR([Date]), MONTH([Date]), 1),
    "YearMonth",   FORMAT([Date],"YYYY-MM")
)
```
Mark it as a date table (`Table tools → Mark as date table → Date`).

## Relationships (star schema)
Build these in **Model** view:

| From (many)                | To (one)                     | Cardinality | Direction |
|----------------------------|------------------------------|-------------|-----------|
| `fact_actuals[department_id]` | `dim_department[department_id]` | many-to-one | single |
| `fact_budget[department_id]`  | `dim_department[department_id]` | many-to-one | single |
| `fact_actuals[period]`        | `DimDate[MonthStart]`           | many-to-one | single |
| `fact_budget[period]`         | `DimDate[MonthStart]`           | many-to-one | single |

`dim_department` and `DimDate` are the shared dimensions that let a single
slicer filter both the budget and the actuals facts at once — this is what
makes budget-vs-actual visuals line up correctly.

Keep `category` as a column on each fact (it is a low-cardinality attribute);
optionally break it into its own `dim_category` table if you want a shared
category slicer across both facts.
