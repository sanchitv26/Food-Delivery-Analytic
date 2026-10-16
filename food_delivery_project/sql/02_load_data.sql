-- ============================================================
-- 02_load_data.sql — load the cleaned CSV into the orders table
-- ============================================================
USE food_delivery_analytics;

-- Adjust the path to wherever orders_load_ready.csv lives on the
-- MySQL server (LOAD DATA LOCAL INFILE needs local_infile=1 enabled
-- on both client and server).
LOAD DATA LOCAL INFILE 'orders_load_ready.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, delivery_person_id, @age, @rating, @rlat, @rlon, @dlat, @dlon,
 @odate, weather_conditions, road_traffic_density, vehicle_condition,
 type_of_order, type_of_vehicle, @multi, festival, city, time_taken_min,
 @otime, @ptime, @dist, distance_flagged, @ohour, day_of_week, is_weekend,
 order_period, @prep, rider_age_group, rider_rating_tier, sla_threshold_min,
 is_delayed, high_risk_order)
SET
  delivery_person_age    = NULLIF(@age, ''),
  delivery_person_rating = NULLIF(@rating, ''),
  restaurant_lat          = NULLIF(@rlat, ''),
  restaurant_lon          = NULLIF(@rlon, ''),
  delivery_lat            = NULLIF(@dlat, ''),
  delivery_lon            = NULLIF(@dlon, ''),
  order_date              = NULLIF(@odate, ''),
  multiple_deliveries     = NULLIF(@multi, ''),
  order_time_min          = NULLIF(@otime, ''),
  pickup_time_min         = NULLIF(@ptime, ''),
  distance_km             = NULLIF(@dist, ''),
  order_hour              = NULLIF(@ohour, ''),
  prep_time_min           = NULLIF(@prep, '');

-- Quick load sanity checks
SELECT COUNT(*) AS total_rows FROM orders;
SELECT COUNT(*) AS delayed_orders FROM orders WHERE is_delayed = 1;
SELECT MIN(order_date), MAX(order_date) FROM orders;
