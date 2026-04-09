--Joins, CTEs, and Window Functions


--1. Daily Performance

--Running total of ticket sales as days go on & Daily revenue increase per day
WITH table_join AS (
SELECT visit_date, day_name, SUM(CAST(spend_cents_clean AS REAL)/100)  AS daily_revenue
FROM fact_visits v
LEFT JOIN dim_date d ON v.date_id = d.date_id
GROUP BY visit_date
)

SELECT visit_date, day_name, COALESCE(daily_revenue, 0.0) AS day_revenue,
COALESCE(LAG(daily_revenue, 1) OVER (ORDER BY visit_date),0.0) AS previous_day_revenue,
SUM(daily_revenue) OVER (
ORDER BY visit_date ASC) AS running_total
FROM table_join
GROUP BY visit_date;
--As more visit_dates get added on, running total will continue.
--Also shows that, in order, Sunday 7/6, Monday 7/7, and Saturday 7/5 are the top performing days.





--2. RFM & CLV
WITH customer_summary AS (
SELECT 
v.guest_id,
CONCAT(first_name, ' ', last_name) AS customer, 
ROUND((JULIANDAY('now') - JULIANDAY(MAX(visit_date)))) AS recency,
COUNT(visit_id) AS frequency,
SUM(CAST(spend_cents_clean AS REAL)/100) AS monetary,
home_state_clean
FROM fact_visits v
INNER JOIN dim_guest g ON v.guest_id = g.guest_id
GROUP BY v.guest_id
)
--Created a little customer_summary sheet, which displays their ID number, full name, days since
--most recent visit, count of visits, their total spend, and their home_state.

SELECT 
home_state_clean AS home_state,
customer,
monetary AS customer_lifetime_value,
RANK() OVER (PARTITION BY home_state_clean ORDER BY monetary DESC) AS CLV_rank
FROM customer_summary;
--This ranks each customer by their total customer lifetime value, all ranked within each state.
--TOP RANKS
--CA = Ivy Zhang: $816.96
--FL = Hiro Tanaka: $429.06
--NY = Ava Reyes: $640.12
--TX = Felix Park: $292.95






--3. Behavior Change

--checking how much each guest spent in dollars, how much they spent in the visit before that, and the
--difference between those two days. Also included party_size and stay_duration for consideration,
WITH delta AS (
SELECT party_size,
entry_time, exit_time,
guest_id, 
spend_cents_clean/100.00 AS spend_dollars,
LAG((spend_cents_clean/100.00),1,'No $ Spent Before') OVER ( PARTITION BY guest_id ORDER BY guest_id) AS lag_spend_dollars,
((spend_cents_clean/100.00) - (LAG((spend_cents_clean/100.00),1,'No $ Spent Before') OVER ( PARTITION BY guest_id ORDER BY guest_id))) AS delta_vs_prior_visit
FROM fact_visits
)

SELECT guest_id,
spend_dollars,
lag_spend_dollars,
delta_vs_prior_visit,
party_size,
(CAST(exit_time AS REAL) - CAST(entry_time AS REAL))*60 AS stay_duration_minutes
FROM delta
WHERE party_size>1
--WHERE stay_duration_minutes >=540
;

--there doesn't appear to be a visible correlation between longer stay duration and increased spending.
--However, party size does seem to encourage more spending, as show for certain guests.
--Guest 1, 5, 7, and 9 does seem to show increased spending.




--4. Ticket Switching

--Using first_value() to find the first ticket that a customer purchased, by the first visit date.
--Then, created a case that gives a value of 1 if the column ticket_type_name has any row that doesn't
--match the first ticket. Finally, uses another case that sums the first case column, flagging if anyone
--has a value >0, which means they switched tickets at some point.

WITH first_tick AS (
SELECT *,
CONCAT(first_name, ' ', last_name) AS customer,
FIRST_VALUE(t.ticket_type_name) OVER (PARTITION BY v.guest_id ORDER BY visit_date ASC) AS first_ticket
FROM fact_visits v
INNER JOIN dim_ticket t ON v.ticket_type_id = t.ticket_type_id
INNER JOIN dim_guest g ON v.guest_id = g.guest_id
)
,acheck AS (
SELECT *,
CASE
		WHEN ticket_type_name != first_ticket THEN 1
		ELSE 0
		END switch_tickets
FROM first_tick
)

SELECT customer,
first_ticket,
CASE
		WHEN SUM(switch_tickets) >0 THEN 'yes'
		ELSE 'no'
		END switched_ticket
FROM acheck
GROUP BY customer

--looks like they all switched tickets :o
