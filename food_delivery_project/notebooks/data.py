import pandas as pd

df = pd.read_csv("D:/food_delivery_project/data/food_delivery_clean.csv")

cols = ["ID","Delivery_person_ID","Delivery_person_Age","Delivery_person_Ratings",
"Restaurant_latitude","Restaurant_longitude","Delivery_location_latitude","Delivery_location_longitude",
"Order_Date","Weather_conditions","Road_traffic_density","Vehicle_condition","Type_of_order",
"Type_of_vehicle","multiple_deliveries","Festival","City","Time_taken_min","order_time_min",
"pickup_time_min","distance_km","distance_flagged","order_hour","day_of_week","is_weekend",
"order_period","prep_time_min","rider_age_group","rider_rating_tier","sla_threshold_min",
"is_delayed","high_risk_order"]

out = df[cols].copy()

# MySQL wants 1/0, not True/False
for b in ["distance_flagged", "is_weekend", "is_delayed", "high_risk_order"]:
    out[b] = out[b].astype(int)

out.to_csv("D:/food_delivery_project/data/orders_load_ready.csv", index=False)
print(out.shape)