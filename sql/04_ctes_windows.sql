-- Run after building data/themepark_analysis.db with scripts/build_analysis_db.sh.
-- This file consumes the canonical cleaned view layer.

-- 1. Daily Performance
WITH table_join AS (
    SELECT visit_date, day_name, SUM(spend_dollar) AS daily_revenue
    FROM vw_fact_visits_clean v
    LEFT JOIN dim_date d ON v.date_id = d.date_id
    GROUP BY visit_date, day_name
)
SELECT
    visit_date,
    day_name,
    COALESCE(daily_revenue, 0.0) AS day_revenue,
    COALESCE(LAG(daily_revenue, 1) OVER (ORDER BY visit_date), 0.0) AS previous_day_revenue,
    SUM(daily_revenue) OVER (ORDER BY visit_date ASC) AS running_total
FROM table_join
ORDER BY visit_date;


-- 2. RFM and CLV by home state
WITH customer_summary AS (
    SELECT
        v.guest_id,
        first_name || ' ' || last_name AS customer,
        ROUND((JULIANDAY('now') - JULIANDAY(MAX(visit_date)))) AS recency,
        COUNT(visit_id) AS frequency,
        SUM(spend_dollar) AS monetary,
        home_state_clean
    FROM vw_fact_visits_clean v
    INNER JOIN vw_dim_guest_clean g ON v.guest_id = g.guest_id
    GROUP BY v.guest_id, customer, home_state_clean
)
SELECT
    home_state_clean AS home_state,
    customer,
    monetary AS customer_lifetime_value,
    RANK() OVER (PARTITION BY home_state_clean ORDER BY monetary DESC) AS clv_rank
FROM customer_summary;


-- 3. Spending change by guest
WITH delta AS (
    SELECT
        party_size,
        entry_time,
        exit_time,
        guest_id,
        spend_dollar AS spend_dollars,
        LAG(spend_dollar, 1, 0.0) OVER (PARTITION BY guest_id ORDER BY visit_date) AS lag_spend_dollars,
        spend_dollar - LAG(spend_dollar, 1, 0.0) OVER (PARTITION BY guest_id ORDER BY visit_date) AS delta_vs_prior_visit,
        stay_duration_minutes
    FROM vw_feature_visit_duration
    WHERE spend_dollar IS NOT NULL
)
SELECT
    guest_id,
    spend_dollars,
    lag_spend_dollars,
    delta_vs_prior_visit,
    party_size,
    stay_duration_minutes
FROM delta
WHERE party_size > 1;


-- 4. Ticket switching
WITH first_tick AS (
    SELECT
        v.*,
        first_name || ' ' || last_name AS customer,
        t.ticket_type_name,
        FIRST_VALUE(t.ticket_type_name) OVER (PARTITION BY v.guest_id ORDER BY visit_date ASC) AS first_ticket
    FROM vw_fact_visits_clean v
    INNER JOIN vw_dim_ticket_clean t ON v.ticket_type_id = t.ticket_type_id
    INNER JOIN vw_dim_guest_clean g ON v.guest_id = g.guest_id
), acheck AS (
    SELECT *,
        CASE
            WHEN ticket_type_name != first_ticket THEN 1
            ELSE 0
        END AS switch_tickets
    FROM first_tick
)
SELECT
    customer,
    first_ticket,
    CASE
        WHEN SUM(switch_tickets) > 0 THEN 'yes'
        ELSE 'no'
    END AS switched_ticket
FROM acheck
GROUP BY customer, first_ticket;