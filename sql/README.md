# Pipeline Overview For Evaluation

## Executive Overview

This project uses a reproducible SQL workflow designed for clarity, auditability, and fast reviewer execution. The project preserves a raw source database, builds a separate analysis database, and applies a single transformation pipeline for cleaning, quality checks, and feature engineering.

## What Was Implemented

The workflow is organized into clear layers:

- Raw source data
  - `data/themepark-raw.db` is treated as immutable.
- Setup layer
  - `sql/01_wiring.sql` creates and wires date dimension table, needed for downstream analysis.
- Transformation layer
  - `sql/02_cleaning_feature_pipeline.sql` creates the cleaned, audited, and feature-engineered view layer.
- Analysis layer
  - `sql/03_eda.sql`, `sql/04_ctes_windows.sql`, and `notebooks/sql_figures.ipynb` consume the pipeline view layer.

This separation reduces regression risk and makes the project easier to evaluate.

## Cleaning/Transformation Documentation

| Columns | What was changed | Interpretation (engineered features) |
|---|---|---|
| **Table: `dim_date`** |  |  |
| `dim_date.*` | Created date dimension table and inserted canonical date rows | - |
| **Table: `fact_visits` (working copy setup)** |  |  |
| `fact_visits.visit_date -> fact_visits.date_id` | Converted ISO date to integer key (`YYYYMMDD`) and indexed for joins in `sql/01_wiring.sql` | - |
| **Table/View: `dim_attraction` -> `vw_dim_attraction_clean`** |  |  |
| `dim_attraction.attraction_name -> vw_dim_attraction_clean.attraction_name_clean` | Standardized text (uppercase, trimmed, punctuation removed, hyphen normalized to space) | - |
| `vw_dim_attraction_clean.canonical_attraction_id` | Chose canonical attraction id (`MIN(attraction_id)`) per cleaned attraction name | - |
| `vw_dim_attraction_clean.has_duplicate_name` | Added duplicate-name flag for attraction records | - |
| **View: `vw_dim_guest_clean`** |  |  |
| `dim_guest.home_state -> vw_dim_guest_clean.home_state_clean` | Standardized state values (`CALIFORNIA/NEW YORK/FLORIDA/TEXAS` to `CA/NY/FL/TX`; all others `TRIM(UPPER())`) | - |
| `dim_guest.marketing_opt_in -> vw_dim_guest_clean.marketing_opt_in_clean` | Normalized opt-in values to `Y`/`N` | - |
| **View: `vw_dim_ticket_clean`** |  |  |
| `dim_ticket.base_price_cents -> vw_dim_ticket_clean.base_price_dollar` | Converted cents to dollars (`ROUND(cents/100, 2)`) | - |
| **View: `vw_fact_visits_clean`** |  |  |
| `fact_visits.total_spend_cents -> spend_cents_clean, spend_dollar` | Removed `USD`, `$`, commas, spaces; validated numeric values; cast to integer cents and dollar amount | - |
| `vw_fact_visits_clean.spend_dollar_status` | Added parsing status (`Parsed` vs `Unknown`) | - |
| `fact_visits.promotion_code -> vw_fact_visits_clean.promotion_code_clean` | Standardized promo code text (uppercase; removed separators/punctuation; blank/null -> `NONE`) | - |
| **View: `vw_fact_purchases_clean`** |  |  |
| `fact_purchases.amount_cents -> amount_cents_clean, amount_dollar` | Removed `USD`, `$`, commas, spaces; validated numeric values; cast to integer cents and dollar amount | - |
| `vw_fact_purchases_clean.amount_dollar_status` | Added parsing status (`Parsed` vs `Unknown`) | - |
| `fact_purchases.payment_method -> vw_fact_purchases_clean.payment_method_clean` | Trimmed and uppercased payment method values | - |
| **View: `vw_fact_ride_events_clean`** |  |  |
| `fact_ride_events.attraction_id -> canonical attraction_id` | Remapped raw attraction ids to canonical attraction ids while retaining `raw_attraction_id` | - |
| `fact_ride_events.wait_minutes -> vw_fact_ride_events_clean.wait_minutes` | Null waits defaulted to `0` in cleaned view | - |
| `fact_ride_events.photo_purchase -> vw_fact_ride_events_clean.photo_purchase_clean` | Normalized to `Y`/`N` (`NULL`/blank/non-`Y` -> `N`) | - |
| **View: `vw_feature_visit_duration`** |  |  |
| `entry_time, exit_time -> stay_duration_minutes` | Engineered visit duration as minute difference between exit and entry times | Estimates time spent in park per visit for retention/engagement analysis |
| **View: `vw_feature_wait_buckets`** |  |  |
| `wait_minutes -> wait_bucket` | Engineered categorical wait buckets: `No`, `Short`, `Medium`, `Long`, `Very Long` | Turns raw wait values into service-level bands for operational performance tracking |
| **View: `vw_feature_guest_spend_segments`** |  |  |
| `spend_dollar -> spender_segment` | Engineered guest spending segments (`Low`, `Regular`, `Premium`) using percentile rank over average spend | Identifies customer value tiers for pricing, targeting, and personalization |
| **View: `vw_feature_promo_code_performance`** |  |  |
| `promotion_code_clean + amount_dollar` | Engineered promo-level KPIs: distinct visits, purchase count, in-park revenue | Measures promo effectiveness and revenue contribution by code |

Note: all logic in `sql/02_cleaning_feature_pipeline.sql` is non-destructive and implemented as views. The only stateful setup is in `sql/01_wiring.sql`, and it is intended to run on the generated working database, not the immutable raw source file.

## Key Goal: Code Reproducibility

- Re-runnable: the same commands can be executed repeatedly.
- Non-destructive: source data is not overwritten.
- Traceable: setup, transformation, and analysis are separated by file responsibility.
- Efficient: two scripts provide build and validation checkpoints.

## Quickstart

From the repository root in terminal, run:

```bash
./scripts/build_analysis_db.sh
./scripts/validate_pipeline.sh
```

This will run the raw database through the pipeline, producing a clean, analysis-ready database. 