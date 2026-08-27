"""
Financial Performance & Budget Control System — synthetic data generator.

Produces three CSVs that mimic a mid-size company's finance data:
  - dim_department.csv : department master (cost centre, region)
  - fact_budget.csv    : planned monthly budget per department + category
  - fact_actuals.csv   : individual actual spend transactions

The generator deliberately injects a handful of anomalies (spend spikes /
duplicate-style overruns) so the outlier-detection SQL has something to catch.
Reproducible via a fixed seed.
"""

import csv
import random
from datetime import date, timedelta

random.seed(42)

# ----------------------------------------------------------------------
# Reference data
# ----------------------------------------------------------------------
DEPARTMENTS = [
    ("Engineering",   "CC-1001", "North"),
    ("Sales",         "CC-1002", "West"),
    ("Marketing",     "CC-1003", "West"),
    ("Operations",    "CC-1004", "South"),
    ("Finance",       "CC-1005", "North"),
    ("Human Resources","CC-1006", "East"),
    ("Customer Support","CC-1007","South"),
    ("Research",      "CC-1008", "North"),
]

CATEGORIES = [
    "Salaries", "Travel", "Software", "Marketing",
    "Facilities", "Training", "Equipment", "Consulting",
]

# Rough monthly budget baseline per category (INR, in thousands) — varies by dept size.
CATEGORY_BASE = {
    "Salaries":   1200, "Travel": 180, "Software": 220, "Marketing": 300,
    "Facilities": 150,  "Training": 90, "Equipment": 130, "Consulting": 160,
}

DEPT_SIZE = {  # multiplier on the baseline
    "Engineering": 1.6, "Sales": 1.3, "Marketing": 1.1, "Operations": 1.2,
    "Finance": 0.8, "Human Resources": 0.7, "Customer Support": 1.0, "Research": 1.4,
}

VENDORS = ["Acme Corp", "Globex", "Initech", "Umbrella", "Soylent",
           "Hooli", "Vandelay", "Stark Ind", "Wayne Ent", "Pied Piper"]

# 18 months of history
START = date(2024, 1, 1)
MONTHS = [ (START.year + (START.month - 1 + i)//12,
            (START.month - 1 + i)%12 + 1) for i in range(18) ]
PERIODS = [date(y, m, 1) for (y, m) in MONTHS]

# ----------------------------------------------------------------------
# 1) Department dimension
# ----------------------------------------------------------------------
with open("data/dim_department.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["department_id", "department_name", "cost_center", "region"])
    for i, (name, cc, region) in enumerate(DEPARTMENTS, start=1):
        w.writerow([i, name, cc, region])

dept_ids = {name: i for i, (name, _, _) in enumerate(DEPARTMENTS, start=1)}

# ----------------------------------------------------------------------
# 2) Budget fact (planned)
# ----------------------------------------------------------------------
budget_rows = []
bid = 1
for name, _, _ in DEPARTMENTS:
    size = DEPT_SIZE[name]
    for period in PERIODS:
        for cat in CATEGORIES:
            base = CATEGORY_BASE[cat] * size
            # small planned growth over time + category noise
            drift = 1 + 0.004 * PERIODS.index(period)
            planned = base * drift * random.uniform(0.95, 1.05)
            budget_rows.append([bid, dept_ids[name], period.isoformat(),
                                cat, round(planned * 1000, 2)])  # to actual INR
            bid += 1

with open("data/fact_budget.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["budget_id", "department_id", "period", "category", "budget_amount"])
    w.writerows(budget_rows)

# Index budgets for actual generation
budget_lookup = {(r[1], r[2], r[3]): r[4] for r in budget_rows}

# ----------------------------------------------------------------------
# 3) Actuals fact (transactions) — normally near budget, with injected anomalies
# ----------------------------------------------------------------------
# Choose a few (dept, category, period) cells to be anomalies.
anomaly_cells = set()
for name, _, _ in DEPARTMENTS:
    if random.random() < 0.9:
        cat = random.choice(CATEGORIES)
        period = random.choice(PERIODS[6:])   # anomalies in later months
        anomaly_cells.add((dept_ids[name], period.isoformat(), cat))

actual_rows = []
tid = 1
for (dept_id, period_iso, cat), planned in budget_lookup.items():
    period = date.fromisoformat(period_iso)
    is_anom = (dept_id, period_iso, cat) in anomaly_cells

    # target actual as a fraction of plan
    if is_anom:
        factor = random.uniform(1.6, 2.4)          # big overrun
    else:
        factor = random.uniform(0.82, 1.12)        # normal variance
    target_actual = planned * factor

    # split the month's spend into a handful of transactions
    n_txn = random.randint(2, 6)
    splits = [random.random() for _ in range(n_txn)]
    s = sum(splits)
    for frac in splits:
        amt = round(target_actual * frac / s, 2)
        day = random.randint(1, 28)
        txn_date = period.replace(day=day)
        vendor = "Payroll" if cat == "Salaries" else random.choice(VENDORS)
        actual_rows.append([tid, dept_id, period_iso, cat,
                            txn_date.isoformat(), vendor, amt])
        tid += 1

with open("data/fact_actuals.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["txn_id", "department_id", "period", "category",
                "txn_date", "vendor", "amount"])
    w.writerows(actual_rows)

print(f"departments : {len(DEPARTMENTS)}")
print(f"budget rows : {len(budget_rows)}")
print(f"actual txns : {len(actual_rows)}")
print(f"anomaly cells injected: {len(anomaly_cells)}")
print("periods:", PERIODS[0].isoformat(), "->", PERIODS[-1].isoformat())
