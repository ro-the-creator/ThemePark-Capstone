-- Run after building data/themepark_analysis.db with scripts/build_analysis_db.sh.
-- This file consumes the canonical cleaned view layer.

-- Q1: General visit patterns
WITH unique_days AS (
    SELECT DISTINCT visit_date
    FROM vw_fact_visits_clean
)
SELECT COUNT(*) AS count_of_distinct_days
FROM unique_days;

SELECT MIN(visit_date) || ' - ' || MAX(visit_date) AS date_range
FROM vw_fact_visits_clean;

SELECT visit_date, COUNT(*) AS visit_count
FROM vw_fact_visits_clean
GROUP BY visit_date
ORDER BY visit_count DESC;


-- Q2: Visit count by ticket type
SELECT dt.ticket_type_name AS ticket_type, COUNT(fv.ticket_type_id) AS visit_count
FROM vw_fact_visits_clean fv
INNER JOIN vw_dim_ticket_clean dt ON fv.ticket_type_id = dt.ticket_type_id
GROUP BY ticket_type
ORDER BY visit_count DESC;


-- Q3: Distribution of wait times
SELECT wait_minutes, COUNT(*) AS frequency_of_wait_time
FROM vw_fact_ride_events_clean
GROUP BY wait_minutes
ORDER BY wait_minutes DESC;


-- Q4: Average satisfaction by attraction and category
SELECT attraction_name_clean, category, ROUND(AVG(satisfaction_rating), 2) AS average_rating
FROM vw_fact_ride_events_clean
GROUP BY attraction_name_clean, category
ORDER BY average_rating DESC;


-- Q5: Duplicate check in fact_ride_events
SELECT ride_event_id, COUNT(*) AS duplicate_row
FROM fact_ride_events
GROUP BY ride_event_id
HAVING duplicate_row > 1;


-- Q6: Canonical pipeline audits
SELECT *
FROM vw_orphan_key_audit;

SELECT *
FROM vw_null_fill_audit;


-- Q7: Average party size by day of week
SELECT dd.date_id, day_name, ROUND(AVG(party_size), 2) AS average_party_size
FROM vw_fact_visits_clean fv
INNER JOIN dim_date dd ON fv.date_id = dd.date_id
GROUP BY day_name, dd.date_id
ORDER BY dd.date_id;