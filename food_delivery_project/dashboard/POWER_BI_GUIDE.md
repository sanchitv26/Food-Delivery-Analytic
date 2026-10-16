# Power BI Dashboard — Build Guide

This project doesn't ship a binary `.pbix` (Power BI Desktop isn't available in
this build environment), but everything below — data model, every DAX
measure, and the exact visuals to place on each page — is ready to paste in
and reproduces a working, interactive dashboard in under 30 minutes.

## 1. Get Data

1. Power BI Desktop → **Get Data → Text/CSV** → select `data/food_delivery_clean.csv`
   (or connect directly to the `orders` MySQL table if you loaded the SQL
   scripts — **Get Data → MySQL database**, point it at `food_delivery_analytics`).
2. Also import `city_reference` and `vehicle_reference` if using MySQL, or
   skip them if using the CSV (the CSV already has `City` and `Type_of_vehicle`
   as plain columns).
3. In Power Query, set data types explicitly: `Order_Date` → Date,
   `Time_taken_min` → Whole Number, `is_delayed` / `high_risk_order` →
   True/False.

## 2. Data Model

If you loaded the MySQL tables, build these relationships (Model view):

| Table 1 | Column | Table 2 | Column | Cardinality |
|---|---|---|---|---|
| orders | city | city_reference | city | Many-to-1 |
| orders | type_of_vehicle | vehicle_reference | type_of_vehicle | Many-to-1 |

If you used the single CSV, no relationships are needed — everything lives
in one flat `orders` table, which is the simpler path for a first build.

## 3. DAX Measures

Create a new **Measures table** (Model view → Enter Data → name it `_Measures`)
and add these:

```DAX
Total Orders = COUNTROWS(orders)

Avg Delivery Time (min) = AVERAGE(orders[time_taken_min])

Delayed Orders = SUM(orders[is_delayed])

Delay Rate % =
DIVIDE([Delayed Orders], [Total Orders], 0)

High-Risk Orders (Proxy) = SUM(orders[high_risk_order])

High-Risk Rate % (Proxy) =
DIVIDE([High-Risk Orders (Proxy)], [Total Orders], 0)

Avg Distance (km) = AVERAGE(orders[distance_km])

On-Time Orders = [Total Orders] - [Delayed Orders]

On-Time Rate % = 1 - [Delay Rate %]

Avg Prep Time (min) = AVERAGE(orders[prep_time_min])

-- Delivery-time delta vs. the overall average, for conditional formatting
Delivery Time Index =
DIVIDE([Avg Delivery Time (min)], CALCULATE([Avg Delivery Time (min)], ALL(orders)))

-- Worst traffic condition this month/filter context, for a KPI card
Slowest Traffic Condition =
CALCULATE(
    SELECTCOLUMNS(TOPN(1, VALUES(orders[road_traffic_density]),
        CALCULATE([Avg Delivery Time (min)]), DESC), "x", orders[road_traffic_density])
)
```

## 4. Report Pages & Visuals

### Page 1 — Executive Overview
- **KPI cards** (top row): `Total Orders`, `Avg Delivery Time (min)`,
  `Delay Rate %`, `High-Risk Rate % (Proxy)`
- **Bar chart**: `Avg Delivery Time (min)` by `road_traffic_density`
  (sort descending)
- **Bar chart**: `Avg Delivery Time (min)` by `weather_conditions`
- **Donut chart**: `Total Orders` by `order_period` (Breakfast/Lunch/
  Dinner Peak/Off-Peak)
- **Line chart**: `Avg Delivery Time (min)` by `order_hour` — reveals the
  hourly delay curve across the day

### Page 2 — Delay Deep-Dive
- **Matrix**: rows = `weather_conditions`, columns = `road_traffic_density`,
  values = `Avg Delivery Time (min)` and `Delay Rate %` — heat-map
  conditional formatting on both
- **Scatter chart**: `distance_km` (X) vs `time_taken_min` (Y), legend =
  `type_of_vehicle`, to show the distance–time relationship by vehicle
- **Bar chart**: `Delay Rate %` by `rider_rating_tier` — shows whether
  lower-rated riders correlate with more delays

### Page 3 — Fleet & Location
- **Map (Bing/ArcGIS)**: plot `Delivery_location_latitude` /
  `Delivery_location_longitude`, colour by `is_delayed`
- **Bar chart**: `Avg Delivery Time (min)` by `city` and `type_of_vehicle`
  (clustered)
- **Table**: `city`, `Total Orders`, `Avg Delivery Time (min)`,
  `Delay Rate %`, sorted worst-first — this is the "which market needs
  more riders" view

### Page 4 — Festival / Peak Stress-Test
- **KPI cards**: `Avg Delivery Time (min)` filtered to `festival = Yes` vs
  `festival = No` (two cards side by side using a bookmark toggle or a
  small multiple)
- **Column chart**: `Avg Delivery Time (min)` by `multiple_deliveries`
  (0, 1, 2, 3+) — shows the cost of batching orders on one rider

## 5. Slicers (add to every page via a Sync Slicers pane)
- `order_date` (date range)
- `city`
- `weather_conditions`
- `road_traffic_density`
- `festival`

## 6. Suggested Formatting
- Use a single accent colour for "delay" visuals (e.g. `#C44E52`) and a
  neutral one for "volume" visuals (`#4C72B0`) — consistent with the EDA
  charts in `outputs/eda_summary.png` so screenshots and the live dashboard
  match visually.
- Add a data-limitation footer text box on every page:
  *"High-risk flag is a proxy (extreme delay + adverse conditions) — the
  source dataset does not include real order cancellations."*
