--Feature Engineering!

--how long guests stayed in minutes
WITH duration AS (
SELECT *, (CAST(exit_time AS REAL) - CAST(entry_time AS REAL))*60 AS stay_duration_minutes
FROM fact_visits
)

--grouped by stay duration to see how long most people are staying, important for customer retention.
SELECT stay_duration_minutes, COUNT(visit_id) AS visit_count
FROM duration
GROUP BY stay_duration_minutes
ORDER BY stay_duration_minutes;









--Wait Time buckets

--creating buckets
WITH waiting AS (
SELECT *, wait_minutes, 
CASE
			WHEN wait_minutes = 0 THEN 'No Wait'
			WHEN wait_minutes BETWEEN 1 AND 15 THEN 'Short Wait'
			WHEN wait_minutes BETWEEN 16 AND 30 THEN 'Medium Wait'
			WHEN wait_minutes BETWEEN 31 AND 45 THEN 'Long Wait'
			WHEN wait_minutes > 45 THEN 'Very Long Wait'
			ELSE 'Error'
			END wait_buckets
FROM fact_ride_events
)

--grouping by wait_buckets to see frequency, see most common wait times as a summary.
SELECT wait_buckets, COUNT(ride_event_id) AS wait_bucket_frequency
FROM waiting
GROUP BY wait_buckets
ORDER BY wait_minutes;

--seeing average wait times, which gets more specific into the summary insight.
SELECT wait_buckets, ROUND(AVG(wait_minutes),2) AS average_wait_time
FROM waiting
GROUP BY wait_buckets
ORDER BY wait_minutes;












--Customers and their average spend in dollars, good to know for high spenders

SELECT CONCAT(g.first_name, ' ', g.last_name) AS guest_name, ROUND(AVG(spend_dollar),2) AS average_spend_dollars,
CASE
			WHEN ROUND(AVG(spend_dollar),2) >= 128.02 THEN 'Premium'			--3rd quartile
			WHEN ROUND(AVG(spend_dollar),2) <= 63.75 THEN 'Low'						--1st Quartile
			ELSE 'Regular'
			END customer_type
FROM fact_visits v
LEFT JOIN dim_guest g ON v.guest_id = g.guest_id
GROUP BY guest_name



--Also useful: Shows All purchases--tickets and in-park-- and categorizes them as high or regular spend
WITH ee AS (
SELECT g.guest_id, CONCAT(g.first_name, ' ', g.last_name) AS guest_name, ROUND(spend_dollar,2) AS spend_dollars, ROUND((p.amount_cents_clean/100),2) AS amount_dollar_clean
FROM fact_purchases p
LEFT JOIN fact_visits v ON p.visit_id = v.visit_id
LEFT JOIN dim_guest g ON v.guest_id = g.guest_id
),
dd AS (
SELECT *,
guest_name, spend_dollars,
ROUND(AVG(spend_dollars) OVER (PARTITION BY guest_name ORDER BY guest_name)) AS rounded
FROM ee
)
SELECT guest_id, spend_dollars,
CASE
			WHEN spend_dollars >= 133.94 THEN 'High Purchase'			--3rd quartile
			ELSE 'Regular Purchase'
			END customer_type
FROM dd
WHERE spend_dollars != 0
UNION ALL 
SELECT guest_id, amount_dollar_clean, 
CASE
			WHEN amount_dollar_clean >= 133.94 THEN 'High Purchase'			--3rd quartile
			ELSE 'Regular Purchase'
			END customer_type
FROM dd
WHERE amount_dollar_clean != 0







-- Frequency of Promo Codes, and total revenue based on those promo codes.
-- Good to check if promo codes are contributing to more profits.

SELECT promotion_code_clean, COUNT(promotion_code_clean) AS promo_count, ROUND(SUM(amount_dollar),2) AS total_revenue
FROM fact_visits v
INNER JOIN fact_purchases p ON v.visit_id = p.visit_id
GROUP BY promotion_code_clean





















--Couldn't figure out :( With more time, would've wanted to calculate this

--Finding who rode the most rides

WITH tim AS (
SELECT DISTINCT e.attraction_id, g.guest_id, e.visit_id, CONCAT(g.first_name, ' ', g.last_name) AS guest_name, COUNT(e.visit_id) AS how_many
FROM fact_ride_events e
INNER JOIN fact_visits v ON e.visit_id = v.visit_id
INNER JOIN  dim_guest g ON v.guest_id = g.guest_id
GROUP BY attraction_id
--HAVING COUNT(e.visit_id) >5
ORDER BY attraction_id, guest_name
)

SELECT guest_name, (CAST(exit_time AS REAL) - CAST(entry_time AS REAL))*60 AS stay_duration_minutes, how_many
FROM fact_visits v
LEFT JOIN tim t ON v.guest_id = v.guest_id
GROUP BY guest_name


