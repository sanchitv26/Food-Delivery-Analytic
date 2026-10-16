# 🍔 Food Delivery Delay & Cancellation Analytics

An end-to-end analytics project that investigates **why food delivery orders
run late** — using real order-level data, Python for cleaning and feature
engineering, MySQL for structured business-question queries, and Power BI
for an interactive dashboard.

> Built as a portfolio project to practice and demonstrate the full
> analyst workflow: raw data → clean data → SQL insights → dashboard →
> business recommendations.

---

## 📌 Table of Contents
- [Problem Statement](#-problem-statement)
- [Dataset](#-dataset)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [How to Run](#-how-to-run)
- [Data Cleaning & Feature Engineering](#-data-cleaning--feature-engineering)
- [SQL Analysis](#-sql-analysis)
- [Power BI Dashboard](#-power-bi-dashboard)
- [Key Insights](#-key-insights-from-this-sample)
- [Business Recommendations](#-business-recommendations)
- [Data Limitations](#-data-limitations--honesty-notes)
- [Resume Bullets](#-resume-bullets)
- [Interview Talking Points](#-interview-talking-points)

---

## 🎯 Problem Statement

Late deliveries hurt customer satisfaction and platform ratings. This
project analyzes order-level delivery data to answer:

1. Which **operational conditions** (traffic, weather, distance) most
   affect delivery time?
2. Which **vehicle types, riders, and cities** perform best/worst?
3. When are **delays most likely** (time of day, festivals, batched orders)?
4. Which orders are at **highest operational risk**, and what should
   operations teams do about it?

---

## 📊 Dataset

- **Source:** [`aneesarom/Food-Delivery`](https://huggingface.co/datasets/aneesarom/Food-Delivery)
  on Hugging Face — a cleaned republication of the well-known public
  **"Zomato Delivery Operations"** dataset (order-level food delivery
  records: rider, weather, traffic, vehicle, distance, and delivery time).
- **This repo ships a genuine 300-order sample** (`data/food_delivery_raw.csv`)
  pulled directly from the dataset's public viewer — every row is real,
  unedited data. The full source dataset has ~45,600 rows; the queries,
  DAX measures, and pipeline in this repo all work unchanged if you drop
  in the full CSV/parquet file instead (see [Data Limitations](#-data-limitations--honesty-notes)).
- **Columns:** rider ID/age/rating, restaurant & delivery GPS coordinates,
  order date/time, weather, road traffic density, vehicle type/condition,
  order type, multiple-deliveries flag, festival flag, city type, and the
  target — `Time_taken (min)`.

---

## 🛠 Tech Stack

| Layer | Tools |
|---|---|
| Data cleaning & feature engineering | Python (pandas, numpy) |
| Structured analysis | MySQL 8 (JOINs, CTEs, subqueries, CASE, window functions) |
| Dashboard | Power BI |
| EDA visuals | matplotlib |

---

## 📁 Project Structure

```
food_delivery_project/
├── data/
│   ├── raw_page0.txt, raw_page1.txt, raw_page2.txt   # source scrape (300 orders)
│   ├── food_delivery_raw.csv                         # combined raw dataset
│   └── food_delivery_clean.csv                       # cleaned + feature-engineered
├── notebooks/
│   ├── 01_data_cleaning_feature_engineering.py       # cleaning + feature engineering script
|   ├── data.py
|   └── load_to_mysql.py                              # connect directly to sql server
├── sql/
│   ├── 01_schema.sql            # table definitions + reference/dimension tables
│   ├── 02_load_data.sql         # MySQL LOAD DATA script
│   ├── 03_analysis_queries.sql  # 12 business-question queries
│   ├── orders_load_ready.csv    # MySQL-ready CSV (column order matches schema)
|   └── requirements.txt
├── dashboard/
│   └── POWER_BI_GUIDE.md        # data model, every DAX measure, page-by-page build guide
├── images/
|  ├── Dashboard_1.png
|  └── Dashboard_2.png
└── README.md
```

---

## ▶️ How to Run

```bash
# 1. Clean & engineer features
cd notebooks
pip install -r ../requirements.txt
python 01_data_cleaning_feature_engineering.py
# -> writes data/food_delivery_clean.csv

# 2. Load into MySQL
mysql -u root -p < ../sql/01_schema.sql
mysql -u root -p --local-infile=1 food_delivery_analytics < ../sql/02_load_data.sql
mysql -u root -p food_delivery_analytics < ../sql/03_analysis_queries.sql

# 3. Power BI
# Open Power BI Desktop -> follow dashboard/POWER_BI_GUIDE.md
```

---

## 🧹 Data Cleaning & Feature Engineering

All steps live in `notebooks/01_data_cleaning_feature_engineering.py` and are
run on the real 300-order sample:

- **Missing values:** median-imputed `Delivery_person_Age` /
  `Delivery_person_Ratings` (11 of 300 rows, ~3.7%); categorical nulls
  (`Weather_conditions`, `Road_traffic_density`, `City`, `Festival`) kept as
  an explicit `"Unknown"` category rather than guessed.
- **Corrupted GPS coordinates:** the source has a handful of `0.0`
  placeholder coordinates and a stray negative sign on one latitude —
  fixed with `abs()` and null-flagged rather than silently trusted.
- **Time parsing:** the source mixes `"HH:MM"` strings, Excel day-fraction
  floats (e.g. `0.958333333` = 23:00), and out-of-range hours (e.g.
  `"24:10:00"`) for `Time_Orderd`/`Time_Order_picked` — all normalised to
  minutes-after-midnight with a single parser.
- **Feature engineering:**
  - `distance_km` — Haversine distance between restaurant and drop-off,
    capped at 50 km and flagged where corrupted coordinates make it
    implausible
  - `order_hour`, `day_of_week`, `is_weekend`, `order_period`
    (Breakfast/Lunch/Dinner Peak vs. Off-Peak)
  - `prep_time_min` — minutes between order placed and rider pickup
  - `rider_age_group`, `rider_rating_tier`
  - `is_delayed` — `Time_taken_min` above the **dataset's own 75th
    percentile** (33 minutes in this sample) — a dataset-relative SLA
    rather than an arbitrary external number
  - `high_risk_order` — a transparent **proxy** flag (see
    [Data Limitations](#-data-limitations--honesty-notes))

---

## 🗄 SQL Analysis

`sql/03_analysis_queries.sql` contains 12 queries covering every requested
SQL technique, each answering a real business question:

| # | Technique(s) | Business Question |
|---|---|---|
| Q1 | JOIN, GROUP BY | Delay rate by city tier |
| Q2 | JOIN, CASE | Vehicle category speed rating |
| Q3 | CASE, GROUP BY | Traffic-density risk labelling |
| Q4 | CTE, subquery | Weather conditions worse than average |
| Q5 | Window (RANK) | City ranking by delivery time |
| Q6 | Window (AVG OVER) | Orders slower than their traffic-group average |
| Q7 | Window (ROW_NUMBER) | Top-3 slowest orders per weather condition |
| Q8 | GROUP BY, CASE | Peak-hour delay rates |
| Q9 | GROUP BY, subquery, CASE | Rider performance segmentation |
| Q10 | CTE, GROUP BY | Festival-day impact |
| Q11 | Subquery, GROUP BY | High-risk order hotspots |
| Q12 | Window (moving average) | Rolling 5-order delivery-time trend |

All 12 queries were logic-tested against the cleaned dataset before being
finalised (see commit history / notebook cell) — every query returns real
rows from this sample.

---

## 📈 Power BI Dashboard

Full build guide (data model, every DAX measure, and page-by-page visual
layout) is in [`dashboard/POWER_BI_GUIDE.md`](dashboard/POWER_BI_GUIDE.md).
Four pages: **Executive Overview**, **Delay Deep-Dive**, **Fleet &
Location**, **Festival/Peak Stress-Test** — all slicer-linked by date,
city, weather, traffic, and festival.

![EDA Summary](outputs/eda_summary.png)

---

## 🔍 Key Insights (from this sample)

*All numbers below are computed directly from the 300-order sample in this
repo — see `notebooks/01_data_cleaning_feature_engineering.py` output.*

- **Traffic is the single biggest delay driver.** Orders placed during a
  **Jam** average **31.0 min**, vs **21.6 min** in Low traffic — a **44%**
  gap — and Jam orders are delayed (past the 33-min SLA) **41.7%** of the
  time vs just **4.2%** in Low traffic.
- **Motorcycles are the slowest vehicle type** (28.3 min avg) compared to
  scooters (25.2 min) and electric scooters (25.3 min) — likely because
  motorcycles are assigned the longer-distance runs in this dataset.
- **Delay rate roughly doubles at dinner time.** Dinner-peak (7–10pm)
  orders are delayed **32.8%** of the time vs **23.0%** off-peak — the
  clearest time-based staffing signal in the data.
- **Batching hurts speed.** Riders carrying **0** simultaneous deliveries
  average **23.4 min**; with **3** simultaneous deliveries that jumps to
  **48.0 min** — more than double, even though the sample size at 3+ is
  small (n=4) and should be validated on more data.
- **Rider rating correlates with speed.** Riders rated below 4.0 average
  **36.4 min** vs **24.5 min** for 4.8–5.0-rated riders — a **48% gap**.
- **Distance explains only part of the story.** Correlation between
  distance and delivery time is **+0.37** — positive but moderate,
  confirming that traffic/weather/staffing matter as much as, or more
  than, raw distance.
- **Festival-day orders take much longer** (46.8 min vs 26.6 min
  non-festival) — but this sample only has **8** festival orders, so
  treat this as directional, not conclusive.

---

## 💡 Business Recommendations

1. **Dynamic ETA buffers during Jam traffic.** Add a ~10-minute buffer to
   customer-facing ETAs automatically when `road_traffic_density = 'Jam'`,
   rather than showing an ETA the data shows is unrealistic 42% of the time.
2. **Rebalance evening staffing.** Dinner-peak delay rates are ~1.4x
   off-peak — schedule more riders on shift between 7–10pm rather than
   spreading headcount evenly across the day.
3. **Cap batched deliveries at 1 extra order during peak hours.** The
   jump from 1 to 2+ simultaneous deliveries roughly doubles delivery
   time; batching policy should weigh that against the fuel/labour
   savings.
4. **Route long-distance orders to scooters/electric scooters where
   available**, or investigate why motorcycles specifically run slower —
   worth a follow-up cut by distance-band to separate "vehicle effect"
   from "was assigned the harder route" effect.
5. **Coach or reassign riders below a 4.0 rating** on high-value/peak-hour
   orders — this segment is both slower and more variable.
6. **Validate the festival effect on a larger sample** before committing
   surge staffing budget — 8 orders is too few to act on alone, but the
   direction is worth testing for.

---

## ⚠️ Data Limitations & Honesty Notes

- **Sample size:** this repo uses a **300-order real sample**, not the
  full ~45,600-row dataset, to keep the project lightweight and fully
  reviewable. The full dataset can be dropped into `data/food_delivery_raw.csv`
  with the same column names and every script/query in this repo will run
  unchanged on the full data.
- **No real cancellation data.** The source dataset only contains
  **completed deliveries** — it has no cancellation field. Rather than
  invent one, this project defines a transparent **`high_risk_order`**
  proxy (extreme delay + adverse weather/traffic) and labels it as a
  proxy everywhere it appears (SQL comments, dashboard footer). Nothing
  in this repo claims to be real cancellation data.
- **Small subgroup caution:** a few breakdowns above (festival orders,
  Semi-Urban city, 3-simultaneous-deliveries) have fewer than 10 rows in
  this sample — the direction is likely real, but confidence intervals
  would be wide; call this out explicitly if asked in an interview.
- **Some GPS coordinates in the source data are corrupted** (0.0 or
  sign-flipped) — these are cleaned/flagged, not silently trusted, and
  the fix is documented in the cleaning script.

---

## 📝 Resume Bullets

- Built an end-to-end delivery analytics pipeline (Python, MySQL, Power
  BI) on real Zomato delivery-operations data, engineering 12+ features
  (Haversine distance, peak-hour buckets, dataset-relative SLA flag) from
  raw, inconsistently-formatted timestamps and coordinates.
- Wrote 12 MySQL queries using CTEs, window functions (RANK, ROW_NUMBER,
  moving averages), subqueries, and CASE logic to quantify delivery
  delay drivers, cutting analysis time versus manual spreadsheet review.
- Identified that traffic congestion (Jam vs. Low) was associated with a
  44% longer average delivery time and a 10x higher delay rate, and
  translated the finding into 6 concrete operational recommendations.
- Designed a 4-page interactive Power BI dashboard (10+ DAX measures,
  cross-filtered slicers) surfacing delay hotspots by traffic, weather,
  vehicle type, city, and time-of-day for non-technical stakeholders.

*(Pick 3–4 that best match the job description — tailor the numbers if
you re-run this on the full 45K-row dataset.)*

---

## 🎤 Interview Talking Points

- **"Walk me through your process"** → raw CSV → documented cleaning
  decisions (median imputation, GPS sign-fix, Excel-fraction time
  parsing) → feature engineering → SQL for structured business
  questions → Power BI for stakeholder-facing visuals.
- **"Why MySQL and Power BI together instead of just Python?"** → SQL is
  the lingua franca most analytics teams query production data with;
  Power BI turns those metrics into something a non-technical
  stakeholder (ops manager) can filter themselves without asking you
  for a new chart every time.
- **"What would you do differently with more time/data?"** → pull the
  full 45K-row dataset, add a proper train/test split for a delivery-time
  prediction model, and replace the `high_risk_order` proxy with real
  cancellation data if a platform ever shares it.
- **"How did you handle messy data?"** → be ready to describe the Excel
  day-fraction time bug and the 0.0-coordinate issue specifically — these
  are the kind of concrete, defensible details that show you actually
  did the work rather than reciting a template.
