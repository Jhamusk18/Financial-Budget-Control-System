# Power BI — Dashboard Design (3 pages)

A shared slicer panel (Region, Department, Category, Month) sits on every page.

## Page 1 — Budget vs Actual
Purpose: the reconciliation view finance leadership opens first.
- **KPI cards (top row):** Total Budget, Total Actual, Variance, Budget Utilisation %
  (colour Variance red when > 0).
- **Clustered column chart:** Budget vs Actual by Month (two series).
- **Line chart:** YTD Actual vs YTD Budget by Month (drift over time).
- **Matrix:** Department (rows) × Month (columns), value = Variance %,
  conditional-formatted red→green.

## Page 2 — Department Cost Breakdown
Purpose: where the money goes.
- **Stacked bar:** Total Actual by Department, segmented by Category.
- **Treemap:** Category share of total spend.
- **Donut:** Spend by Region.
- **Table:** Department, Total Budget, Total Actual, Utilisation %, spend rank.

## Page 3 — Anomaly / Alert Monitor
Purpose: surface unusual financial behaviour.
- **Alerts table:** Department, Category, Month, Monthly Spend, Z-Score, Anomaly Flag —
  filtered to `Anomaly Flag = "⚠ Anomaly"`, sorted by |Z-Score|.
- **Scatter:** Budget (x) vs Actual (y) per department-month; points far above the
  y = x line are overspenders.
- **Column chart:** Month-over-month % change by category, with a reference line at ±40%.
- **Card:** count of active anomalies this month.

## Interaction notes
- Cross-filtering on: clicking a department on Page 2 filters the whole page.
- Drill-through from any department visual to a per-department detail page.
- Use the `Budget Status` measure for KPI colour, `Anomaly Flag` for the alert filter.
