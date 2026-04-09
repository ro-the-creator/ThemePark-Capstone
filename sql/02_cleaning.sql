--Cleaning


-- cleaning for fact_visits cents
WITH c AS (
SELECT
rowid AS rid,
REPLACE(REPLACE(REPLACE(REPLACE(UPPER(COALESCE(total_spend_cents,'')),
'USD',''), '$',''), ',', ''), ' ', '') AS cleaned
FROM fact_visits
)
UPDATE fact_visits
SET spend_cents_clean = CAST((SELECT cleaned FROM c WHERE c.rid = fact_visits.rowid)
AS INTEGER)
WHERE LENGTH((SELECT cleaned FROM c WHERE c.rid = fact_visits.rowid)) > 0;

--cleaning for fact_purchases cents
WITH c AS (
SELECT
rowid AS rid,
REPLACE(REPLACE(REPLACE(REPLACE(UPPER(COALESCE(amount_cents,'')),
'USD',''), '$',''), ',', ''), ' ', '') AS cleaned
FROM fact_purchases
)
UPDATE fact_purchases
SET amount_cents_clean = CAST((SELECT cleaned FROM c WHERE c.rid = fact_purchases.rowid)
AS INTEGER)
WHERE LENGTH((SELECT cleaned FROM c WHERE c.rid = fact_purchases.rowid)) > 0;











--creating dollar columns

--for fact_visits
ALTER TABLE fact_visits ADD COLUMN spend_dollar REAL;

WITH c AS (
SELECT
rowid AS rid,
REPLACE(REPLACE(REPLACE(REPLACE(UPPER(COALESCE(total_spend_cents,'')),
'USD',''), '$',''), ',', ''), ' ', '') AS cleaned
FROM fact_visits
)
UPDATE fact_visits
SET spend_dollar = (CAST((SELECT cleaned FROM c WHERE c.rid = fact_visits.rowid)
AS REAL))/100
WHERE LENGTH((SELECT cleaned FROM c WHERE c.rid = fact_visits.rowid)) > 0;

--for fact_purchases
ALTER TABLE fact_purchases ADD COLUMN amount_dollar REAL;

WITH c AS (
SELECT
rowid AS rid,
REPLACE(REPLACE(REPLACE(REPLACE(UPPER(COALESCE(amount_cents,'')),
'USD',''), '$',''), ',', ''), ' ', '') AS cleaned
FROM fact_purchases
)
UPDATE fact_purchases
SET amount_dollar = (CAST((SELECT cleaned FROM c WHERE c.rid = fact_purchases.rowid)
AS REAL))/100
WHERE LENGTH((SELECT cleaned FROM c WHERE c.rid = fact_purchases.rowid)) > 0;











--cleaning dim_attraction columns

--standardize attraction_names
ALTER TABLE dim_attraction ADD COLUMN attraction_name_clean TEXT;

WITH c AS (
SELECT ROWID AS rid, TRIM(REPLACE(UPPER(attraction_name), '!', ' ') ) AS cleaned
FROM dim_attraction
)

UPDATE dim_attraction
SET attraction_name_clean = (SELECT cleaned
														FROM c
														WHERE c.rid = dim_attraction.ROWID);

														
			








-- cleaning dim_guest columns

--standardize home_state

ALTER TABLE dim_guest ADD COLUMN home_state_clean TEXT;

WITH c AS (
SELECT ROWID AS rid, TRIM(REPLACE(REPLACE(UPPER(home_state), 'CALIFORNIA', 'CA'),'NEW YORK','NY')) AS cleaned
FROM dim_guest
)

UPDATE dim_guest
SET home_state_clean = (SELECT cleaned
												FROM c
												WHERE c.rid = dim_guest.ROWID);

												
												
--standardize marketing_opt_in

ALTER TABLE dim_guest ADD COLUMN marketing_opt_in_clean TEXT;

WITH c AS (
SELECT ROWID AS rid, TRIM(REPLACE(REPLACE(UPPER(marketing_opt_in), 'YES','Y'),'NO','N')) AS cleaned
FROM dim_guest
)

UPDATE dim_guest
SET marketing_opt_in_clean = (SELECT cleaned
															FROM c
															WHERE c.rid = dim_guest.ROWID);
												
												
												
												
												
												
												
												
												

-- cleaning dim_ticket columns

--base_price_cents to dollars

ALTER TABLE dim_ticket ADD COLUMN base_price_dollars REAL;

UPDATE dim_ticket
SET base_price_dollars = (base_price_cents/100);










--cleaning fact_visits columns

--normalize promotion_code
ALTER TABLE fact_visits ADD COLUMN promotion_code_clean TEXT;

WITH c AS (
SELECT ROWID AS rid, TRIM(REPLACE(UPPER(promotion_code),'-','')) AS cleaned
FROM fact_visits
)

UPDATE fact_visits
SET promotion_code_clean = (SELECT cleaned
														FROM c
														WHERE c.rid = fact_visits.ROWID);

														
														
														
														
														
														
														
														
														
--cleaning fact_purchases columns

--normalize payment_method

WITH c AS (
SELECT ROWID AS rid, TRIM(UPPER(payment_method)) AS cleaned
FROM fact_purchases
)

UPDATE fact_purchases
SET payment_method = (SELECT cleaned
												FROM c
												WHERE c.rid = fact_purchases.ROWID);












--counting duplicates for every table

SELECT attraction_id, COUNT(*) AS duplicates
FROM dim_attraction
GROUP BY attraction_id
HAVING duplicates >1;

SELECT date_id, COUNT(*) AS duplicates
FROM dim_date
GROUP BY date_id
HAVING duplicates >1;

SELECT guest_id, COUNT(*) AS duplicates
FROM dim_guest
GROUP BY guest_id
HAVING duplicates >1;

SELECT ticket_type_id, COUNT(*) AS duplicates
FROM dim_ticket
GROUP BY ticket_type_id
HAVING duplicates >1;

SELECT attraction_id, COUNT(*) AS duplicates
FROM dim_attraction
GROUP BY attraction_id
HAVING duplicates >1;




--checking for duplicate attraction names (with standardized attraction_name_clean)
SELECT attraction_name_clean, COUNT(attraction_name_clean) AS duplicates
FROM dim_attraction
GROUP BY attraction_name_clean
HAVING duplicates >1;

--deleting one of those rows for each duplicate name
SELECT *
FROM dim_attraction
WHERE attraction_name_clean = 'GALAXY COASTER';

SELECT *
FROM dim_attraction
WHERE attraction_name_clean = 'PIRATE SPLASH';

--changing attraction_id in fact_ride_events to match new changes (galaxy coaster: attraction_id 6 --> 1)
UPDATE fact_ride_events
SET attraction_id = 1
WHERE attraction_id=6;

--(pirate splash: attraction_id 2 -->7)
UPDATE fact_ride_events
SET attraction_id = 7
WHERE attraction_id=2;

--then, deleting the row with inconsistent attraction_name
DELETE FROM dim_attraction
WHERE attraction_id = 6 OR attraction_id = 2;









-- Orphan Check

--fact_visits
--guest_id
SELECT v.visit_id, v.guest_id
FROM fact_visits v
LEFT JOIN dim_guest g ON g.guest_id = v.guest_id
WHERE g.guest_id IS NULL;

--ticket_type_id
SELECT v.visit_id, v.ticket_type_id
FROM fact_visits v
LEFT JOIN dim_ticket t ON v.ticket_type_id = t.ticket_type_id
WHERE t.ticket_type_id IS NULL;

--date_id
SELECT v.visit_id, v.date_id
FROM fact_visits v
LEFT JOIN dim_date d ON v.date_id = d.date_id
WHERE d.date_id IS NULL;



--fact_ride_events
--visit_id
SELECT e.ride_event_id, e.visit_id
FROM fact_ride_events e
LEFT JOIN fact_visits v ON e.visit_id = v.visit_id
WHERE v.visit_id IS NULL;

--attraction_id
SELECT e.ride_event_id, e.attraction_id
FROM fact_ride_events e
LEFT JOIN dim_attraction a ON e.attraction_id = a.attraction_id
WHERE a.attraction_id IS NULL;



-- fact_purchases
--visit_id
SELECT p.purchase_id, p.visit_id
FROM fact_purchases p
LEFT JOIN fact_visits v ON p.visit_id = v.visit_id
WHERE v.visit_id IS NULL;

-- No Orphans!!











--(finally) filling in NULL rows

--dim_guest: marketing_opt_in_clean
UPDATE dim_guest
SET marketing_opt_in_clean = 'N'
WHERE marketing_opt_in_clean IS NULL;


--fact_purchases: amount_dollar
UPDATE fact_purchases
SET amount_dollar = 'Unknown'
WHERE amount_dollar IS NULL;



--fact_ride_events: wait_minutes & photo_purchase
UPDATE fact_ride_events
SET wait_minutes = 0
WHERE wait_minutes IS NULL;

UPDATE fact_ride_events
SET photo_purchase = 'N'
WHERE photo_purchase IS NULL;



--fact_visits: spend_dollar & promotion_code_clean
UPDATE fact_visits
SET spend_dollar = 'Unknown'
WHERE spend_dollar IS NULL;

UPDATE fact_visits
SET promotion_code_clean = 'NONE'
WHERE promotion_code_clean IS NULL OR promotion_code_clean = '';










--updating attraction_id in fact_ride_events 
--I was unable to do this given the time. With more time, I would like to reorder the dim_attraction rowid
--and change the corresponding FK numbers in the fact_ride_events table. This would realign the attraction_id
-- to be in order, and prevent further issues. For now, attraction_id 2 & 6 are skipped.

--Dragon Drop: 3 --> 2
UPDATE fact_ride_events
SET attraction_id = 2
WHERE attraction_id = 3;



--updating attraction_id in dim_attraction
--(galaxy = 1, dragon = 2, tiny = 3, space = 4, pirate = 5, wild = 6)

WITH c AS (
SELECT *,
ROW_NUMBER() OVER (
ORDER BY rowid) AS updated_attraction_id
FROM dim_attraction
)

UPDATE dim_attraction
SET attraction_id = (SELECT updated_attraction_id FROM c)

