"""
Food Delivery Delay & Cancellation Analytics
Step 1: Data Cleaning & Feature Engineering
---------------------------------------------
Input : data/food_delivery_raw.csv  (300 real orders sampled from the public
        "Zomato Delivery Operations" dataset — see README for source & license)
Output: data/food_delivery_clean.csv (analysis-ready dataset for SQL + Power BI)

Run:  python 01_data_cleaning_feature_engineering.py
"""

import numpy as np
import pandas as pd
from math import radians

pd.set_option("display.width", 140)

# ------------------------------------------------------------------
# 1. LOAD
# ------------------------------------------------------------------
RAW_PATH = "../data/food_delivery_raw.csv"
CLEAN_PATH = "../data/food_delivery_clean.csv"

df = pd.read_csv(RAW_PATH)
print(f"Raw shape: {df.shape}")

# ------------------------------------------------------------------
# 2. BASIC CLEANING
# ------------------------------------------------------------------

# 2a. Standardise text columns (strip whitespace, fix a known source typo)
for col in ["Weather_conditions", "Road_traffic_density", "Type_of_order",
            "Type_of_vehicle", "Festival", "City"]:
    df[col] = df[col].astype(str).str.strip()
    df[col] = df[col].replace("nan", np.nan)

# The source dataset spells "Metropolitan" as "Metropolitian" — normalise it.
df["City"] = df["City"].replace({"Metropolitian": "Metropolitan"})

# 2b. Numeric coercion
for col in ["Delivery_person_Age", "Delivery_person_Ratings", "multiple_deliveries"]:
    df[col] = pd.to_numeric(df[col], errors="coerce")

# 2c. Fix corrupted GPS coordinates.
#     A handful of source rows store 0.0 (missing-value placeholder) or a
#     stray negative sign on latitude. We repair sign errors and treat 0/0
#     pairs as missing rather than guessing a location.
for col in ["Restaurant_latitude", "Restaurant_longitude",
            "Delivery_location_latitude", "Delivery_location_longitude"]:
    df[col] = df[col].abs()

zero_coords = (df["Restaurant_latitude"] == 0) & (df["Restaurant_longitude"] == 0)
df.loc[zero_coords, ["Restaurant_latitude", "Restaurant_longitude"]] = np.nan

# 2d. Parse Order_Date
df["Order_Date"] = pd.to_datetime(df["Order_Date"], format="%d-%m-%Y", errors="coerce")

# 2e. Parse Time_Orderd / Time_Order_picked
#     The source stores most times as "HH:MM" text but a subset was exported
#     from Excel as a day-fraction (e.g. 0.958333333 == 23:00) or with an
#     out-of-range hour (e.g. "24:10:00"). We normalise all three formats to
#     minutes-after-midnight; anything still unparsable becomes NaN.
def time_to_minutes(val):
    if pd.isna(val):
        return np.nan
    s = str(val).strip()
    try:
        # Excel day-fraction, e.g. 0.958333333
        frac = float(s)
        if 0 <= frac <= 1.5:
            return round((frac % 1) * 24 * 60, 1)
    except ValueError:
        pass
    parts = s.split(":")
    try:
        h = int(parts[0]) % 24
        m = int(parts[1]) if len(parts) > 1 else 0
        return h * 60 + m
    except (ValueError, IndexError):
        return np.nan

df["order_time_min"] = df["Time_Orderd"].apply(time_to_minutes)
df["pickup_time_min"] = df["Time_Order_picked"].apply(time_to_minutes)

# 2f. Missing-value strategy (documented, not silently dropped)
#     - Age / Ratings: median imputation (11 missing of 300, ~3.7%)
#     - multiple_deliveries: 0 is the most common and the safest default
#     - Weather / Traffic / City / Festival: keep as "Unknown" category
#       rather than imputing a guessed condition
df["Delivery_person_Age"] = df["Delivery_person_Age"].fillna(df["Delivery_person_Age"].median())
df["Delivery_person_Ratings"] = df["Delivery_person_Ratings"].fillna(df["Delivery_person_Ratings"].median())
df["multiple_deliveries"] = df["multiple_deliveries"].fillna(0)

for col in ["Weather_conditions", "Road_traffic_density", "City", "Festival"]:
    df[col] = df[col].fillna("Unknown")

# 2g. Drop exact duplicate rows, if any
before = len(df)
df = df.drop_duplicates()
print(f"Dropped {before - len(df)} duplicate rows")

# ------------------------------------------------------------------
# 3. FEATURE ENGINEERING
# ------------------------------------------------------------------

# 3a. Distance between restaurant and delivery location (Haversine, km)
def haversine_km(lat1, lon1, lat2, lon2):
    if pd.isna(lat1) or pd.isna(lon1) or pd.isna(lat2) or pd.isna(lon2):
        return np.nan
    R = 6371.0
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    dlat, dlon = lat2 - lat1, lon2 - lon1
    a = np.sin(dlat / 2) ** 2 + np.cos(lat1) * np.cos(lat2) * np.sin(dlon / 2) ** 2
    return R * 2 * np.arcsin(np.sqrt(a))

df["distance_km"] = df.apply(
    lambda r: haversine_km(r.Restaurant_latitude, r.Restaurant_longitude,
                            r.Delivery_location_latitude, r.Delivery_location_longitude),
    axis=1,
)
# A handful of source rows have implausible distances (>50 km for a food
# order) caused by corrupted coordinates. Cap rather than drop, and flag them.
df["distance_flagged"] = df["distance_km"] > 50
df["distance_km"] = df["distance_km"].clip(upper=50)

# 3b. Time features
df["order_hour"] = (df["order_time_min"] // 60).astype("Int64")
df["day_of_week"] = df["Order_Date"].dt.day_name()
df["is_weekend"] = df["Order_Date"].dt.dayofweek.isin([5, 6])

def peak_bucket(hour):
    if pd.isna(hour):
        return "Unknown"
    if 8 <= hour <= 10:
        return "Breakfast Peak"
    if 12 <= hour <= 14:
        return "Lunch Peak"
    if 19 <= hour <= 22:
        return "Dinner Peak"
    return "Off-Peak"

df["order_period"] = df["order_hour"].apply(peak_bucket)

# 3c. Kitchen prep time (minutes between order placed and picked up by rider)
df["prep_time_min"] = df["pickup_time_min"] - df["order_time_min"]
# Handle orders that cross midnight (negative wrap-around)
df.loc[df["prep_time_min"] < 0, "prep_time_min"] += 24 * 60
df.loc[df["prep_time_min"] > 120, "prep_time_min"] = np.nan  # implausible, treat as missing

# 3d. Rider experience / quality buckets
df["rider_age_group"] = pd.cut(
    df["Delivery_person_Age"], bins=[0, 24, 30, 35, 100],
    labels=["Under 25", "25-30", "31-35", "36+"]
)
df["rider_rating_tier"] = pd.cut(
    df["Delivery_person_Ratings"], bins=[0, 4.0, 4.5, 4.8, 5.01],
    labels=["Below 4.0", "4.0-4.5", "4.5-4.8", "4.8-5.0"]
)

# 3e. Delay flag — genuine, threshold-based (no fabricated ground truth).
#     Industry-standard food-delivery SLA is ~30 minutes; we treat anything
#     above the dataset's own 75th percentile as "Delayed" so the label is
#     dataset-relative rather than an arbitrary external number.
p75 = df["Time_taken_min"].quantile(0.75)
df["sla_threshold_min"] = round(p75, 1)
df["is_delayed"] = df["Time_taken_min"] > p75

# 3f. Cancellation proxy — IMPORTANT CAVEAT
#     The public dataset only contains completed deliveries; it does not
#     record cancelled orders. We therefore do NOT fabricate a cancellation
#     column. Instead we compute a transparent "high_risk_order" proxy flag
#     (extreme delay + adverse conditions) that stands in for operational
#     risk in the dashboard, and this is labelled as a proxy everywhere it
#     is shown (see README "Data Limitations").
p90 = df["Time_taken_min"].quantile(0.90)
adverse_weather = df["Weather_conditions"].isin(["Stormy", "Fog", "Sandstorms"])
adverse_traffic = df["Road_traffic_density"].isin(["Jam", "High"])
df["high_risk_order"] = (df["Time_taken_min"] > p90) & (adverse_weather | adverse_traffic)

# ------------------------------------------------------------------
# 4. FINAL COLUMN ORDER + SAVE
# ------------------------------------------------------------------
df = df.drop(columns=["Time_Orderd", "Time_Order_picked"])

df.to_csv(CLEAN_PATH, index=False)
print(f"Clean shape: {df.shape}")
print(f"Saved -> {CLEAN_PATH}")
print("\nMissing values after cleaning:")
print(df.isnull().sum()[df.isnull().sum() > 0])
