-- ============================================================
-- Food Delivery Delay & Cancellation Analytics
-- 03_analysis_queries.sql — MySQL 8.0+ (uses CTEs & window functions)
-- ============================================================
USE food_delivery_analytics;

-- ------------------------------------------------------------
-- Q1. JOIN — average delivery time and delay rate by city tier
-- ------------------------------------------------------------
SELECT
    cr.city_tier,
    o.city,
    COUNT(*)                                   AS total_orders,
    ROUND(AVG(o.time_taken_min), 1)            AS avg_delivery_min,
    ROUND(100 * AVG(o.is_delayed), 1)          AS delay_rate_pct
FROM orders o
JOIN city_reference cr
    ON o.city = cr.city
GROUP BY cr.city_tier, o.city
ORDER BY delay_rate_pct DESC;


-- ------------------------------------------------------------
-- Q2. JOIN + CASE — vehicle category performance with a
--     human-readable delivery-speed label
-- ------------------------------------------------------------
SELECT
    vr.vehicle_category,
    o.type_of_vehicle,
    ROUND(AVG(o.time_taken_min), 1) AS avg_delivery_min,
    CASE
        WHEN AVG(o.time_taken_min) < 24 THEN 'Fast'
        WHEN AVG(o.time_taken_min) < 30 THEN 'Average'
        ELSE 'Slow'
    END AS speed_rating
FROM orders o
JOIN vehicle_reference vr
    ON o.type_of_vehicle = vr.type_of_vehicle
GROUP BY vr.vehicle_category, o.type_of_vehicle
ORDER BY avg_delivery_min;


-- ------------------------------------------------------------
-- Q3. CASE + GROUP BY — delay-rate breakdown by traffic density,
--     bucketed with a CASE expression into a risk label
-- ------------------------------------------------------------
SELECT
    road_traffic_density,
    COUNT(*)                                AS total_orders,
    SUM(is_delayed)                         AS delayed_orders,
    ROUND(100 * AVG(is_delayed), 1)         AS delay_rate_pct,
    CASE
        WHEN AVG(is_delayed) >= 0.35 THEN 'High Risk'
        WHEN AVG(is_delayed) >= 0.15 THEN 'Moderate Risk'
        ELSE 'Low Risk'
    END AS operational_risk_level
FROM orders
GROUP BY road_traffic_density
ORDER BY delay_rate_pct DESC;


-- ------------------------------------------------------------
-- Q4. CTE + subquery — weather conditions that perform worse
--     than the overall average delivery time
-- ------------------------------------------------------------
WITH weather_stats AS (
    SELECT
        weather_conditions,
        COUNT(*)                        AS total_orders,
        ROUND(AVG(time_taken_min), 1)   AS avg_delivery_min
    FROM orders
    WHERE weather_conditions <> 'Unknown'
    GROUP BY weather_conditions
)
SELECT *
FROM weather_stats
WHERE avg_delivery_min > (
    SELECT AVG(time_taken_min) FROM orders WHERE weather_conditions <> 'Unknown'
)
ORDER BY avg_delivery_min DESC;


-- ------------------------------------------------------------
-- Q5. Window function (RANK) — rank every city by average
--     delivery time, worst first
-- ------------------------------------------------------------
WITH city_perf AS (
    SELECT
        city,
        COUNT(*)                        AS total_orders,
        ROUND(AVG(time_taken_min), 1)   AS avg_delivery_min
    FROM orders
    WHERE city <> 'Unknown'
    GROUP BY city
)
SELECT
    city,
    total_orders,
    avg_delivery_min,
    RANK() OVER (ORDER BY avg_delivery_min DESC) AS delay_rank
FROM city_perf;


-- ------------------------------------------------------------
-- Q6. Window function (AVG OVER PARTITION) — flag every order
--     that runs slower than its own traffic-density average
-- ------------------------------------------------------------
SELECT
    order_id,
    road_traffic_density,
    time_taken_min,
    ROUND(AVG(time_taken_min) OVER (PARTITION BY road_traffic_density), 1) AS traffic_avg_min,
    time_taken_min - AVG(time_taken_min) OVER (PARTITION BY road_traffic_density) AS diff_from_traffic_avg
FROM orders
ORDER BY diff_from_traffic_avg DESC
LIMIT 20;


-- ------------------------------------------------------------
-- Q7. Window function (ROW_NUMBER) — top 3 slowest orders
--     within every weather condition (per-group leaderboard)
-- ------------------------------------------------------------
WITH ranked AS (
    SELECT
        order_id,
        weather_conditions,
        time_taken_min,
        ROW_NUMBER() OVER (
            PARTITION BY weather_conditions
            ORDER BY time_taken_min DESC
        ) AS rn
    FROM orders
    WHERE weather_conditions <> 'Unknown'
)
SELECT order_id, weather_conditions, time_taken_min
FROM ranked
WHERE rn <= 3
ORDER BY weather_conditions, time_taken_min DESC;


-- ------------------------------------------------------------
-- Q8. Peak-hour analysis — GROUP BY + CASE
-- ------------------------------------------------------------
SELECT
    order_period,
    COUNT(*)                             AS total_orders,
    ROUND(AVG(time_taken_min), 1)        AS avg_delivery_min,
    ROUND(100 * AVG(is_delayed), 1)      AS delay_rate_pct
FROM orders
WHERE order_period <> 'Unknown'
GROUP BY order_period
ORDER BY avg_delivery_min DESC;


-- ------------------------------------------------------------
-- Q9. Rider performance tiers — GROUP BY + subquery + CASE
--     (riders below the fleet's average rating vs. their delay rate)
-- ------------------------------------------------------------
SELECT
    rider_rating_tier,
    COUNT(*)                        AS total_orders,
    ROUND(AVG(time_taken_min), 1)   AS avg_delivery_min,
    ROUND(100 * AVG(is_delayed), 1) AS delay_rate_pct,
    CASE
        WHEN rider_rating_tier IN ('4.8-5.0', '4.5-4.8') THEN 'Top Performer'
        WHEN rider_rating_tier = '4.0-4.5' THEN 'Needs Coaching'
        ELSE 'Priority Coaching'
    END AS performance_segment
FROM orders
GROUP BY rider_rating_tier
ORDER BY avg_delivery_min DESC;


-- ------------------------------------------------------------
-- Q10. Festival-day impact — GROUP BY + CTE comparison
-- ------------------------------------------------------------
WITH festival_stats AS (
    SELECT
        festival,
        COUNT(*)                        AS total_orders,
        ROUND(AVG(time_taken_min), 1)   AS avg_delivery_min,
        ROUND(100 * AVG(is_delayed), 1) AS delay_rate_pct
    FROM orders
    WHERE festival <> 'Unknown'
    GROUP BY festival
)
SELECT *,
       avg_delivery_min - (SELECT MIN(avg_delivery_min) FROM festival_stats) AS min_gap_min
FROM festival_stats
ORDER BY avg_delivery_min DESC;


-- ------------------------------------------------------------
-- Q11. High-risk (proxy for cancellation-risk) orders — subquery
--      NOTE: the source dataset has no real cancellation field.
--      high_risk_order is a transparent proxy (see README).
-- ------------------------------------------------------------
SELECT
    weather_conditions,
    road_traffic_density,
    COUNT(*) AS high_risk_orders
FROM orders
WHERE high_risk_order = 1
GROUP BY weather_conditions, road_traffic_density
ORDER BY high_risk_orders DESC;


-- ------------------------------------------------------------
-- Q12. Window function (moving average) — 5-order rolling average
--      delivery time in chronological order, to visualise trend
-- ------------------------------------------------------------
SELECT
    order_id,
    order_date,
    time_taken_min,
    ROUND(
      AVG(time_taken_min) OVER (
        ORDER BY order_date, order_time_min
        ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
      ), 1
    ) AS rolling_5_order_avg
FROM orders
ORDER BY order_date, order_time_min;
