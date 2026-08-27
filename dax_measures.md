# Power BI — DAX Measures

Create these in a dedicated measures table (`Enter Data → empty table "Measures"`).
They mirror the SQL logic so the dashboard and the SQL layer agree.

## Core totals
```DAX
Total Actual = SUM ( fact_actuals[amount] )

Total Budget = SUM ( fact_budget[budget_amount] )
```

## Variance
```DAX
Variance = [Total Actual] - [Total Budget]        -- positive = overspend

Variance % =
DIVIDE ( [Variance], [Total Budget] )              -- format as %

Budget Utilisation % =
DIVIDE ( [Total Actual], [Total Budget] )          -- format as %
```

## Status flag (drives conditional formatting / KPI colour)
```DAX
Budget Status =
SWITCH (
    TRUE (),
    [Total Actual] > [Total Budget], "Over Budget",
    [Total Actual] < [Total Budget], "Under Budget",
    "On Budget"
)
```

## Cumulative / YTD (uses DimDate)
```DAX
YTD Actual =
CALCULATE ( [Total Actual], DATESYTD ( DimDate[Date] ) )

YTD Budget =
CALCULATE ( [Total Budget], DATESYTD ( DimDate[Date] ) )
```

## Statistical anomaly detection (Z-score in DAX)
Computes, for the current department + category, how many standard deviations
the selected month's spend is from that group's historical mean.

```DAX
Monthly Spend = [Total Actual]

Group Mean Spend =
CALCULATE (
    AVERAGEX (
        VALUES ( DimDate[MonthStart] ),
        [Total Actual]
    ),
    ALLEXCEPT ( fact_actuals, fact_actuals[department_id], fact_actuals[category] )
)

Group SD Spend =
CALCULATE (
    STDEVX.S (
        VALUES ( DimDate[MonthStart] ),
        [Total Actual]
    ),
    ALLEXCEPT ( fact_actuals, fact_actuals[department_id], fact_actuals[category] )
)

Spend Z-Score =
DIVIDE ( [Monthly Spend] - [Group Mean Spend], [Group SD Spend] )

Anomaly Flag =
IF ( ABS ( [Spend Z-Score] ) > 2, "⚠ Anomaly", "Normal" )
```

Use `Anomaly Flag` as a visual-level filter on the alerts table, or drive a
conditional-format colour so anomalous cells turn red automatically.
