# ThemePark Analysis Notebook Documentation

## Source
- Notebook: `notebooks/analysis.ipynb`
- Database: `data/themepark_analysis.db`

## Analysis Scope
This documentation summarizes the three SQL-backed visual analyses in the notebook and provides interpretation for each chart.

## 1) Ticket Revenue by Day of Week

### Objective
Measure ticket revenue patterns across days of the week.

### SQL Logic Summary
The query builds a `daily_revenue` CTE from `vw_fact_visits_clean`, joins `dim_date` for `day_name`, and aggregates `SUM(spend_dollar)` by `visit_date` and day.

### Chart
- Type: Seaborn bar chart
- X-axis: `day_name`
- Y-axis: `day_revenue`
- Title: `Ticket Revenue per Day of Week`

### Observed Values
- Tuesday: 223.26 (one additional Tuesday record is null and excluded from bar height)
- Wednesday: 507.12
- Thursday: 422.10
- Friday: 555.41
- Saturday: 900.91
- Sunday: 1128.43 (highest)
- Monday: 910.93

### Interpretation
- Weekend demand is strongest, with Sunday producing the highest ticket revenue.
- Monday remains elevated relative to mid-week, suggesting spillover from weekend attendance.
- Tuesday is the lowest observed day, indicating a clear off-peak window.
- Operationally, this supports weekend staffing peaks and possible Tuesday promotions to smooth demand.

## 2) Distribution of Purchases per Guest ID

### Objective
Compare spending behavior by guest and classify transactions as high vs regular purchases.

### SQL Logic Summary
The query unions:
- Ticket spend from `vw_fact_visits_clean`
- In-park purchases from `vw_fact_purchases_clean`
It labels each row with:
- `High Purchase` if `amount_dollar >= 133.94`
- `Regular Purchase` otherwise

### Chart
- Type: Seaborn strip plot
- X-axis: `guest_id`
- Y-axis: `amount_dollar`
- Hue: `customer_type`
- Title: `Distribution of Purchases per Guest ID`

### Observed Distribution Highlights
- Most points fall in the low-to-mid range (roughly under 50), indicating many smaller transactions.
- High-value transactions (>= 133.94) appear across multiple guests, not just one outlier customer.
- Guest-level summary:
  - Guest 9 has the most high purchases (4) and the highest max transaction (245.83).
  - Guests 4, 1, 2, 7, and 8 also show repeated high-value behavior.
  - Guests 3 and 5 have no high purchases and lower average spend profiles.

### Interpretation
- Revenue concentration includes a core of frequent low-value transactions plus a smaller set of high-value purchases.
- Several guests demonstrate premium-spend behavior, which could support targeted upsell bundles or loyalty tiers.
- Distinguishing purchase type in future visuals (ticket vs in-park) would improve interpretation of where high-spend events originate.

## 3) Distribution of Ratings per Attraction Ride

### Objective
Evaluate satisfaction rating distributions by attraction.

### SQL Logic Summary
The query selects `attraction_name_clean` and `satisfaction_rating` from `vw_fact_ride_events_clean`, excluding null ratings.

### Chart
- Type: Seaborn violin plot
- X-axis: `attraction_name_clean`
- Y-axis: `satisfaction_rating`
- Title: `Distribution of Ratings per Attraction Ride`

### Observed Metrics
- DRAGON DROP: n=17, avg=3.24
- TINY TRUCKS: n=27, avg=3.22
- GALAXY COASTER: n=24, avg=3.04
- PIRATE SPLASH: n=37, avg=2.78
- SPACE THEATER: n=20, avg=2.75
- WILD RAPIDS: n=17, avg=2.59
- All attractions span ratings from 1.0 to 5.0, indicating broad variability in guest experience.

### Interpretation
- DRAGON DROP and TINY TRUCKS have the strongest average sentiment in this sample.
- WILD RAPIDS and SPACE THEATER trend lower on average and may need service or experience review.
- Because all attractions have wide ranges, operational consistency appears to be an issue across rides.
- PIRATE SPLASH has the largest sample size (n=37), so its lower-mid average is likely a stable signal rather than noise.

## Cross-Chart Takeaways
- Demand and revenue are time-dependent (strong weekend peak).
- Spend behavior is segmented: frequent small purchases plus recurring high-value transactions.
- Ride satisfaction varies by attraction and appears inconsistent, creating opportunities for quality standardization.

## Recommended Follow-Up Analyses
1. Add confidence intervals or error bars for day-level revenue once more dates are available.
2. Split purchase distributions by `spend_type` (ticket vs in-park) to isolate merchandising effects.
3. Compare ratings against wait times, ride downtime, or staffing to explain low-performing attractions.
4. Track these same visuals over time to detect improvements after interventions.
