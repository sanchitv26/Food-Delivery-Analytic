-- ============================================================
-- Food Delivery Delay & Cancellation Analytics
-- 01_schema.sql — database & table definitions (MySQL 8.0+)
-- ============================================================

CREATE DATABASE IF NOT EXISTS food_delivery_analytics;
USE food_delivery_analytics;

-- ------------------------------------------------------------
-- FACT TABLE: one row per delivery order (loaded from
-- data/food_delivery_clean.csv, produced by the Python
-- cleaning/feature-engineering step)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
    order_id                VARCHAR(10)   PRIMARY KEY,   -- source column: ID
    delivery_person_id      VARCHAR(30),
    delivery_person_age     TINYINT UNSIGNED,
    delivery_person_rating  DECIMAL(3,2),
    restaurant_lat          DECIMAL(10,6),
    restaurant_lon          DECIMAL(10,6),
    delivery_lat            DECIMAL(10,6),
    delivery_lon            DECIMAL(10,6),
    order_date              DATE,
    weather_conditions      VARCHAR(20),
    road_traffic_density    VARCHAR(10),
    vehicle_condition        TINYINT UNSIGNED,           -- 0=Poor .. 2/3=Good/Excellent
    type_of_order           VARCHAR(20),
    type_of_vehicle         VARCHAR(20),
    multiple_deliveries     TINYINT UNSIGNED,
    festival                VARCHAR(10),
    city                    VARCHAR(20),
    time_taken_min          SMALLINT UNSIGNED,
    order_time_min          SMALLINT UNSIGNED,           -- minutes after midnight
    pickup_time_min         SMALLINT UNSIGNED,
    distance_km             DECIMAL(6,2),
    distance_flagged        TINYINT(1),                  -- 1 = corrupted-coordinate outlier, capped
    order_hour              TINYINT UNSIGNED,
    day_of_week             VARCHAR(10),
    is_weekend              TINYINT(1),
    order_period            VARCHAR(20),                 -- Breakfast/Lunch/Dinner Peak or Off-Peak
    prep_time_min           SMALLINT,
    rider_age_group         VARCHAR(10),
    rider_rating_tier       VARCHAR(10),
    sla_threshold_min       DECIMAL(5,1),                -- dataset-relative 75th-percentile SLA
    is_delayed              TINYINT(1),                  -- 1 = time_taken_min > sla_threshold_min
    high_risk_order         TINYINT(1)                   -- proxy flag, see README "Data Limitations"
);

-- ------------------------------------------------------------
-- DIMENSION TABLES (small, hand-authored reference/lookup
-- tables used to demonstrate JOINs — NOT synthetic fact data)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS city_reference;
CREATE TABLE city_reference (
    city         VARCHAR(20) PRIMARY KEY,
    city_tier    VARCHAR(20),
    description  VARCHAR(120)
);

INSERT INTO city_reference (city, city_tier, description) VALUES
('Metropolitan', 'Tier 1', 'Large metro area — dense traffic, high order volume'),
('Urban',        'Tier 2', 'Mid-sized city — moderate traffic and order density'),
('Semi-Urban',   'Tier 3', 'Smaller town/outskirts — lower order density, longer distances'),
('Unknown',      'Unclassified', 'City not captured at source for this order');

DROP TABLE IF EXISTS vehicle_reference;
CREATE TABLE vehicle_reference (
    type_of_vehicle  VARCHAR(20) PRIMARY KEY,
    vehicle_category VARCHAR(20),
    typical_use_case VARCHAR(120)
);

INSERT INTO vehicle_reference (type_of_vehicle, vehicle_category, typical_use_case) VALUES
('motorcycle',       'Motorized', 'Long-distance, high-speed deliveries'),
('scooter',          'Motorized', 'Short-to-medium urban deliveries'),
('electric_scooter', 'Electric',  'Short-distance, low-emission deliveries');
