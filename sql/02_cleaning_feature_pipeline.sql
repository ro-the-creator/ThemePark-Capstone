-- Streamlined cleaning and feature-engineering pipeline for the Supernova theme park database.
-- This script keeps the raw tables untouched and exposes reusable views for analysis.

-- =========================
-- Cleaning layer
-- =========================

DROP VIEW IF EXISTS vw_dim_attraction_clean;
CREATE VIEW vw_dim_attraction_clean AS
WITH normalized AS (
    SELECT
        attraction_id,
        attraction_name,
        category,
        min_height_cm,
        opened_date,
        TRIM(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(UPPER(attraction_name), '!', ''),
                            '?', ''
                        ),
                        '.', ''
                    ),
                    ',', ''
                ),
                '-', ' '
            )
        ) AS attraction_name_clean
    FROM dim_attraction
)
SELECT
    attraction_id,
    attraction_name,
    attraction_name_clean,
    category,
    min_height_cm,
    opened_date,
    MIN(attraction_id) OVER (PARTITION BY attraction_name_clean) AS canonical_attraction_id,
    CASE
        WHEN COUNT(*) OVER (PARTITION BY attraction_name_clean) > 1 THEN 1
        ELSE 0
    END AS has_duplicate_name
FROM normalized;


DROP VIEW IF EXISTS vw_dim_attraction_canonical;
CREATE VIEW vw_dim_attraction_canonical AS
SELECT
    canonical_attraction_id AS attraction_id,
    attraction_name_clean,
    category,
    min_height_cm,
    opened_date
FROM vw_dim_attraction_clean
WHERE attraction_id = canonical_attraction_id;


DROP VIEW IF EXISTS vw_dim_guest_clean;
CREATE VIEW vw_dim_guest_clean AS
SELECT
    guest_id,
    first_name,
    last_name,
    email,
    birthdate,
    home_state,
    CASE TRIM(UPPER(home_state))
        WHEN 'CALIFORNIA' THEN 'CA'
        WHEN 'NEW YORK' THEN 'NY'
        WHEN 'FLORIDA' THEN 'FL'
        WHEN 'TEXAS' THEN 'TX'
        ELSE TRIM(UPPER(home_state))
    END AS home_state_clean,
    marketing_opt_in,
    CASE
        WHEN TRIM(UPPER(COALESCE(marketing_opt_in, ''))) IN ('YES', 'Y') THEN 'Y'
        ELSE 'N'
    END AS marketing_opt_in_clean
FROM dim_guest;


DROP VIEW IF EXISTS vw_dim_ticket_clean;
CREATE VIEW vw_dim_ticket_clean AS
SELECT
    ticket_type_id,
    ticket_type_name,
    base_price_cents,
    ROUND(base_price_cents / 100.0, 2) AS base_price_dollar,
    restrictions
FROM dim_ticket;


DROP VIEW IF EXISTS vw_fact_visits_clean;
CREATE VIEW vw_fact_visits_clean AS
WITH standardized AS (
    SELECT
        visit_id,
        guest_id,
        ticket_type_id,
        visit_date,
        date_id,
        party_size,
        entry_time,
        exit_time,
        total_spend_cents,
        promotion_code,
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(UPPER(COALESCE(total_spend_cents, '')), 'USD', ''),
                    '$', ''
                ),
                ',', ''
            ),
            ' ', ''
        ) AS spend_text_clean,
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(UPPER(COALESCE(promotion_code, '')), '-', ''),
                    '_', ''
                ),
                '.', ''
            ),
            ' ', ''
        ) AS promotion_code_text_clean
    FROM fact_visits
)
SELECT
    visit_id,
    guest_id,
    ticket_type_id,
    visit_date,
    date_id,
    party_size,
    entry_time,
    exit_time,
    total_spend_cents,
    promotion_code,
    CASE
        WHEN spend_text_clean <> '' AND spend_text_clean NOT GLOB '*[^0-9]*' THEN CAST(spend_text_clean AS INTEGER)
        ELSE NULL
    END AS spend_cents_clean,
    CASE
        WHEN spend_text_clean <> '' AND spend_text_clean NOT GLOB '*[^0-9]*' THEN ROUND(CAST(spend_text_clean AS REAL) / 100.0, 2)
        ELSE NULL
    END AS spend_dollar,
    CASE
        WHEN spend_text_clean <> '' AND spend_text_clean NOT GLOB '*[^0-9]*' THEN 'Parsed'
        ELSE 'Unknown'
    END AS spend_dollar_status,
    CASE
        WHEN promotion_code_text_clean = '' THEN 'NONE'
        ELSE promotion_code_text_clean
    END AS promotion_code_clean
FROM standardized;


DROP VIEW IF EXISTS vw_fact_purchases_clean;
CREATE VIEW vw_fact_purchases_clean AS
WITH standardized AS (
    SELECT
        purchase_id,
        visit_id,
        category,
        item_name,
        amount_cents,
        payment_method,
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(UPPER(COALESCE(amount_cents, '')), 'USD', ''),
                    '$', ''
                ),
                ',', ''
            ),
            ' ', ''
        ) AS amount_text_clean,
        TRIM(UPPER(payment_method)) AS payment_method_clean
    FROM fact_purchases
)
SELECT
    purchase_id,
    visit_id,
    category,
    item_name,
    amount_cents,
    payment_method,
    CASE
        WHEN amount_text_clean <> '' AND amount_text_clean NOT GLOB '*[^0-9]*' THEN CAST(amount_text_clean AS INTEGER)
        ELSE NULL
    END AS amount_cents_clean,
    CASE
        WHEN amount_text_clean <> '' AND amount_text_clean NOT GLOB '*[^0-9]*' THEN ROUND(CAST(amount_text_clean AS REAL) / 100.0, 2)
        ELSE NULL
    END AS amount_dollar,
    CASE
        WHEN amount_text_clean <> '' AND amount_text_clean NOT GLOB '*[^0-9]*' THEN 'Parsed'
        ELSE 'Unknown'
    END AS amount_dollar_status,
    payment_method_clean
FROM standardized;


DROP VIEW IF EXISTS vw_fact_ride_events_clean;
CREATE VIEW vw_fact_ride_events_clean AS
SELECT
    e.ride_event_id,
    e.visit_id,
    e.attraction_id AS raw_attraction_id,
    a.canonical_attraction_id AS attraction_id,
    a.attraction_name_clean,
    a.category,
    e.ride_time,
    COALESCE(e.wait_minutes, 0) AS wait_minutes,
    e.satisfaction_rating,
    e.photo_purchase,
    CASE
        WHEN TRIM(UPPER(COALESCE(e.photo_purchase, ''))) = 'Y' THEN 'Y'
        ELSE 'N'
    END AS photo_purchase_clean
FROM fact_ride_events e
LEFT JOIN vw_dim_attraction_clean a
    ON e.attraction_id = a.attraction_id;


-- =========================
-- Data-quality audit layer
-- =========================

DROP VIEW IF EXISTS vw_duplicate_attraction_names;
CREATE VIEW vw_duplicate_attraction_names AS
SELECT
    attraction_name_clean,
    COUNT(*) AS duplicate_count,
    GROUP_CONCAT(attraction_id, ', ') AS attraction_ids
FROM vw_dim_attraction_clean
GROUP BY attraction_name_clean
HAVING COUNT(*) > 1;


DROP VIEW IF EXISTS vw_orphan_key_audit;
CREATE VIEW vw_orphan_key_audit AS
SELECT
    'fact_visits.guest_id -> dim_guest.guest_id' AS relationship,
    COUNT(*) AS orphan_count
FROM fact_visits v
LEFT JOIN dim_guest g
    ON g.guest_id = v.guest_id
WHERE g.guest_id IS NULL

UNION ALL

SELECT
    'fact_visits.ticket_type_id -> dim_ticket.ticket_type_id' AS relationship,
    COUNT(*) AS orphan_count
FROM fact_visits v
LEFT JOIN dim_ticket t
    ON t.ticket_type_id = v.ticket_type_id
WHERE t.ticket_type_id IS NULL

UNION ALL

SELECT
    'fact_ride_events.visit_id -> fact_visits.visit_id' AS relationship,
    COUNT(*) AS orphan_count
FROM fact_ride_events e
LEFT JOIN fact_visits v
    ON v.visit_id = e.visit_id
WHERE v.visit_id IS NULL

UNION ALL

SELECT
    'fact_ride_events.attraction_id -> dim_attraction.attraction_id' AS relationship,
    COUNT(*) AS orphan_count
FROM vw_fact_ride_events_clean e
LEFT JOIN vw_dim_attraction_canonical a
    ON a.attraction_id = e.attraction_id
WHERE a.attraction_id IS NULL

UNION ALL

SELECT
    'fact_purchases.visit_id -> fact_visits.visit_id' AS relationship,
    COUNT(*) AS orphan_count
FROM fact_purchases p
LEFT JOIN fact_visits v
    ON v.visit_id = p.visit_id
WHERE v.visit_id IS NULL;


DROP VIEW IF EXISTS vw_null_fill_audit;
CREATE VIEW vw_null_fill_audit AS
SELECT
    'dim_guest.marketing_opt_in_clean defaults to N' AS rule_name,
    SUM(CASE WHEN marketing_opt_in IS NULL OR TRIM(marketing_opt_in) = '' THEN 1 ELSE 0 END) AS affected_rows
FROM dim_guest

UNION ALL

SELECT
    'fact_purchases.amount_dollar remains NULL and is labeled Unknown' AS rule_name,
    SUM(CASE WHEN amount_cents IS NULL OR TRIM(amount_cents) = '' OR amount_dollar IS NULL THEN 1 ELSE 0 END) AS affected_rows
FROM vw_fact_purchases_clean

UNION ALL

SELECT
    'fact_ride_events.wait_minutes defaults to 0' AS rule_name,
    SUM(CASE WHEN wait_minutes IS NULL THEN 1 ELSE 0 END) AS affected_rows
FROM fact_ride_events

UNION ALL

SELECT
    'fact_ride_events.photo_purchase defaults to N' AS rule_name,
    SUM(CASE WHEN photo_purchase IS NULL OR TRIM(photo_purchase) = '' THEN 1 ELSE 0 END) AS affected_rows
FROM fact_ride_events

UNION ALL

SELECT
    'fact_visits.spend_dollar remains NULL and is labeled Unknown' AS rule_name,
    SUM(CASE WHEN total_spend_cents IS NULL OR TRIM(total_spend_cents) = '' OR spend_dollar IS NULL THEN 1 ELSE 0 END) AS affected_rows
FROM vw_fact_visits_clean

UNION ALL

SELECT
    'fact_visits.promotion_code_clean defaults to NONE' AS rule_name,
    SUM(CASE WHEN promotion_code_clean = 'NONE' THEN 1 ELSE 0 END) AS affected_rows
FROM vw_fact_visits_clean;


-- =========================
-- Feature-engineering layer
-- =========================

DROP VIEW IF EXISTS vw_feature_visit_duration;
CREATE VIEW vw_feature_visit_duration AS
SELECT
    visit_id,
    guest_id,
    ticket_type_id,
    visit_date,
    date_id,
    party_size,
    entry_time,
    exit_time,
    spend_dollar,
    spend_dollar_status,
    promotion_code_clean,
    (
        (CAST(SUBSTR(exit_time, 1, 2) AS INTEGER) * 60 + CAST(SUBSTR(exit_time, 4, 2) AS INTEGER)) -
        (CAST(SUBSTR(entry_time, 1, 2) AS INTEGER) * 60 + CAST(SUBSTR(entry_time, 4, 2) AS INTEGER))
    ) AS stay_duration_minutes
FROM vw_fact_visits_clean;


DROP VIEW IF EXISTS vw_feature_visit_duration_summary;
CREATE VIEW vw_feature_visit_duration_summary AS
SELECT
    stay_duration_minutes,
    COUNT(*) AS visit_count
FROM vw_feature_visit_duration
GROUP BY stay_duration_minutes
ORDER BY stay_duration_minutes;


DROP VIEW IF EXISTS vw_feature_wait_buckets;
CREATE VIEW vw_feature_wait_buckets AS
SELECT
    ride_event_id,
    visit_id,
    attraction_id,
    attraction_name_clean,
    category,
    wait_minutes,
    photo_purchase_clean,
    CASE
        WHEN wait_minutes = 0 THEN 'No Wait'
        WHEN wait_minutes BETWEEN 1 AND 15 THEN 'Short Wait'
        WHEN wait_minutes BETWEEN 16 AND 30 THEN 'Medium Wait'
        WHEN wait_minutes BETWEEN 31 AND 45 THEN 'Long Wait'
        WHEN wait_minutes > 45 THEN 'Very Long Wait'
        ELSE 'Unknown'
    END AS wait_bucket
FROM vw_fact_ride_events_clean;


DROP VIEW IF EXISTS vw_feature_wait_bucket_summary;
CREATE VIEW vw_feature_wait_bucket_summary AS
SELECT
    wait_bucket,
    COUNT(*) AS wait_bucket_frequency,
    ROUND(AVG(wait_minutes), 2) AS average_wait_time
FROM vw_feature_wait_buckets
GROUP BY wait_bucket
ORDER BY
    CASE wait_bucket
        WHEN 'No Wait' THEN 1
        WHEN 'Short Wait' THEN 2
        WHEN 'Medium Wait' THEN 3
        WHEN 'Long Wait' THEN 4
        WHEN 'Very Long Wait' THEN 5
        ELSE 6
    END;


DROP VIEW IF EXISTS vw_feature_guest_spend_segments;
CREATE VIEW vw_feature_guest_spend_segments AS
WITH guest_spend AS (
    SELECT
        g.guest_id,
        g.first_name || ' ' || g.last_name AS guest_name,
        ROUND(AVG(v.spend_dollar), 2) AS average_spend_dollars
    FROM vw_fact_visits_clean v
    INNER JOIN vw_dim_guest_clean g
        ON g.guest_id = v.guest_id
    WHERE v.spend_dollar IS NOT NULL
    GROUP BY g.guest_id, guest_name
), ranked AS (
    SELECT
        guest_id,
        guest_name,
        average_spend_dollars,
        PERCENT_RANK() OVER (ORDER BY average_spend_dollars) AS spend_percent_rank
    FROM guest_spend
)
SELECT
    guest_id,
    guest_name,
    average_spend_dollars,
    CASE
        WHEN spend_percent_rank <= 0.25 THEN 'Low'
        WHEN spend_percent_rank >= 0.75 THEN 'Premium'
        ELSE 'Regular'
    END AS spender_segment
FROM ranked
ORDER BY average_spend_dollars;


DROP VIEW IF EXISTS vw_feature_guest_spend_segment_summary;
CREATE VIEW vw_feature_guest_spend_segment_summary AS
SELECT
    spender_segment,
    COUNT(*) AS guest_count
FROM vw_feature_guest_spend_segments
GROUP BY spender_segment
ORDER BY
    CASE spender_segment
        WHEN 'Low' THEN 1
        WHEN 'Regular' THEN 2
        WHEN 'Premium' THEN 3
        ELSE 4
    END;


DROP VIEW IF EXISTS vw_feature_promo_code_performance;
CREATE VIEW vw_feature_promo_code_performance AS
SELECT
    v.promotion_code_clean,
    COUNT(DISTINCT v.visit_id) AS promo_visit_count,
    COUNT(p.purchase_id) AS in_park_purchase_count,
    ROUND(SUM(p.amount_dollar), 2) AS in_park_revenue
FROM vw_fact_visits_clean v
LEFT JOIN vw_fact_purchases_clean p
    ON p.visit_id = v.visit_id
   AND p.amount_dollar IS NOT NULL
GROUP BY v.promotion_code_clean
ORDER BY in_park_revenue DESC, promo_visit_count DESC;


-- Example checks after loading this script:
-- SELECT * FROM vw_orphan_key_audit;
-- SELECT * FROM vw_duplicate_attraction_names;
-- SELECT * FROM vw_feature_visit_duration_summary;
-- SELECT * FROM vw_feature_wait_bucket_summary;
-- SELECT * FROM vw_feature_guest_spend_segment_summary;
-- SELECT * FROM vw_feature_promo_code_performance;