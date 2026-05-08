# Building a Production-Grade E-Commerce Data Warehouse from Scratch — A Complete Engineering Journey

**Author:** Desmond Onam  
**Date:** April 2026  
**Stack:** Python · DuckDB · dbt · Evidence.dev · GitHub Actions

---

## Table of Contents

1. [The Problem](#1-the-problem)
2. [The Dataset](#2-the-dataset)
3. [Choosing the Tools](#3-choosing-the-tools)
4. [Step 1 — Designing the Star Schema](#4-step-1--designing-the-star-schema)
5. [Step 2 — Ingesting Raw Data with Python and DuckDB](#5-step-2--ingesting-raw-data-with-python-and-duckdb)
6. [Step 3 — Building the Staging Layer with dbt](#6-step-3--building-the-staging-layer-with-dbt)
7. [Step 4 — Building the Mart Layer with dbt](#7-step-4--building-the-mart-layer-with-dbt)
8. [Step 5 — Testing Data Quality with dbt](#8-step-5--testing-data-quality-with-dbt)
9. [Step 6 — Building the BI Dashboard with Evidence.dev](#9-step-6--building-the-bi-dashboard-with-evidencedev)
10. [Step 7 — Deploying to GitHub Pages with GitHub Actions](#10-step-7--deploying-to-github-pages-with-github-actions)
11. [Challenges and How We Solved Them](#11-challenges-and-how-we-solved-them)
12. [Lessons Learnt](#12-lessons-learnt)
13. [What to Build Next](#13-what-to-build-next)

---

## 1. The Problem

Every data engineering team eventually faces the same scenario: you have raw data scattered across files, it gets dumped into a database with no agreed-upon structure, and analysts write fragile one-off queries directly against the source tables. Everyone ends up with a slightly different number. Trust in the data erodes. Decisions slow down.

For this project, the scenario was concrete: a Brazilian e-commerce marketplace called Olist had eight CSV files covering 100,000 orders — customers, products, sellers, payments, reviews, and logistics. The data existed. The insights did not.

The questions a business would want answered were clear:

- Which states generate the most revenue?
- Is Gross Merchandise Value growing month over month?
- Which sellers are underperforming on delivery and customer satisfaction?
- What is each customer's lifetime value?

None of these questions could be answered directly from the raw files. They required joins across five or six tables, careful handling of edge cases (orders with multiple items, orders paid in multiple instalments, customers who appear multiple times in the dataset), and trustworthy data quality.

The goal of this project was to build the infrastructure that makes those questions answerable — reliably, repeatably, and for free.

---

## 2. The Dataset

The **Olist Brazilian E-Commerce Public Dataset** is a real, anonymised dataset released on Kaggle. It covers 100,000 orders placed on the Olist marketplace between September 2016 and October 2018 across 27 Brazilian states.

What makes it interesting for a data warehouse project is its normalisation. The data is spread across eight separate files that must be joined to produce any meaningful analysis:

| File | Rows | What it contains |
|---|---|---|
| `olist_orders_dataset.csv` | 99,441 | The order header — status, five timestamps (purchase, approval, carrier delivery, customer delivery, estimated delivery) |
| `olist_customers_dataset.csv` | 99,441 | Customer zip code, city, state, and two identity fields: `customer_id` (order-scoped) and `customer_unique_id` (persistent across orders) |
| `olist_order_items_dataset.csv` | 112,650 | One row per item — product, seller, unit price, freight |
| `olist_order_payments_dataset.csv` | 103,886 | One row per payment instrument — a single order can be split across credit card, boleto, and voucher |
| `olist_order_reviews_dataset.csv` | 99,224 | Star ratings and freetext comments, one or more per order |
| `olist_products_dataset.csv` | 32,951 | Physical dimensions, category, photo count |
| `olist_sellers_dataset.csv` | 3,095 | Seller zip code, city, state |
| `product_category_name_translation.csv` | 71 | Portuguese category names mapped to English |

There are 99,441 orders but 112,650 order items — because many orders contain multiple products from different sellers. This distinction turns out to be the most important design decision in the whole project, as we will see.

---

## 3. Choosing the Tools

The core constraint was cost: zero. This had to be an entirely free stack. Here is what that ruled out and why:

- **Snowflake / BigQuery / Redshift** — all have free tiers but hit limits quickly at analytical scale or lock you into cloud vendor dependencies
- **Looker / Tableau / Power BI (cloud)** — paid for anything beyond toy usage
- **Airflow / Prefect** — heavyweight orchestration for a project that needs one pipeline run

The stack that emerged:

**DuckDB** for the warehouse engine. DuckDB is an embedded analytical database — it runs in-process, stores data in a single file, and is fast enough to run analytical queries over 100,000+ rows in milliseconds. Crucially, it can read CSV files directly with `read_csv_auto()`, meaning raw ingestion is a single Python call.

**dbt-duckdb** for transformation. dbt (data build tool) brings software engineering practices to SQL — version control, modular models, dependency management, and built-in testing. The DuckDB adapter makes it work against a local file instead of a cloud warehouse.

**Evidence.dev** for the BI layer. Evidence is a code-first BI tool: you write Markdown files with embedded SQL, and it compiles them into a static website. No servers, no subscriptions. It reads directly from DuckDB, deploys to GitHub Pages for free, and the output looks genuinely professional.

**GitHub Actions** for CI/CD. When you push to `main`, Actions rebuilds the dbt models, re-runs the Evidence build, and pushes the static site to the `gh-pages` branch. Fully automated, entirely free.

---

## 4. Step 1 — Designing the Star Schema

Before writing a single line of SQL, the schema had to be designed. The most important decision was choosing the **grain** of the fact table — the level of detail that one row represents.

### Why order-item grain, not order grain

The naive choice is one row per order. But orders in this dataset contain multiple items from multiple sellers. If the fact table is at order grain, a row for an order containing a book from seller A and a phone case from seller B would need to aggregate two prices, two freight values, two sellers, and two products into a single row. That's not analysis-friendly.

The correct grain is **one row per order item**. This is the lowest natural grain the data supports, and it allows:

- Revenue to be attributed to a specific product and seller
- Freight to be separated from item price at the item level
- Seller performance analysis without any aggregation in the query

The star schema that emerged has `fact_orders` at the centre, surrounded by four dimension tables:

```
dim_customers ──────────────────────────────────────┐
dim_sellers ─────────────────────────────────────────┤──► fact_orders (order-item grain)
dim_products ────────────────────────────────────────┤
dim_time ────────────────────────────────────────────┘
```

### The four date role-playing foreign keys

An order has five timestamps: when it was placed, when it was approved, when the carrier picked it up, when it was delivered, and when delivery was estimated. Four of these are analytically useful as date dimensions.

Rather than creating four separate dimension tables, the standard approach is to have one `dim_time` table and four foreign keys in the fact table that all reference it — each one "playing a different role." This means you can slice by delivery month and purchase month independently in the same query without any join gymnastics.

### Payment proration

Payments in the source data are at order level, not item level. An order that costs R$200 with two R$100 items has a single R$200 payment row. But the fact table is at item grain.

The solution is proration: each item's share of the payment equals `total_payment × (item_price / order_total)`. This means the payment figures in the fact table sum correctly whether you aggregate by item, order, customer, or any other dimension.

### The customer identity problem

Here is a subtlety in the Olist data that most analyses miss: `customer_id` is not a persistent customer identifier. Olist assigns a fresh `customer_id` to every order. The field `customer_unique_id` is the actual person identifier — it stays constant across multiple orders from the same buyer.

This matters enormously for customer lifetime value analysis. If you count distinct `customer_id` values, you get 99,441 — one per order. If you count distinct `customer_unique_id` values, you get 95,420 — the true number of unique people. Both keys are kept in the warehouse so analysts can use whichever is appropriate.

---

## 5. Step 2 — Ingesting Raw Data with Python and DuckDB

With the schema designed, the first implementation task was loading the eight CSV files into DuckDB's `raw` schema.

DuckDB's `read_csv_auto()` function handles this almost entirely automatically — it infers column names, data types, and encoding from the file headers:

```python
con.execute(
    f"CREATE TABLE raw.{table} AS "
    f"SELECT * FROM read_csv_auto('{csv_path}', header=true)"
)
```

The loader script (`scripts/load_raw_data.py`) iterates over all eight files, drops and recreates each table, and prints the row count as confirmation:

```
loaded raw.olist_customers_dataset                        99,441 rows
loaded raw.olist_sellers_dataset                           3,095 rows
loaded raw.olist_products_dataset                         32,951 rows
loaded raw.product_category_name_translation                  71 rows
loaded raw.olist_orders_dataset                           99,441 rows
loaded raw.olist_order_items_dataset                     112,650 rows
loaded raw.olist_order_payments_dataset                  103,886 rows
loaded raw.olist_order_reviews_dataset                    99,224 rows
```

The raw schema is intentionally dumb — no type casting, no cleaning, no renaming. It is a faithful mirror of the source files. All transformation happens in the next layer.

---

## 6. Step 3 — Building the Staging Layer with dbt

The staging layer's job is narrow and strictly defined: take the raw tables and produce clean, correctly-typed views. No business logic lives here. No aggregations. No joins between unrelated sources (the one exception is `stg_products`, which joins the category translation table — because a category name is an attribute of a product, not a business calculation).

### What staging models actually do

Each model performs a predictable set of operations:

**Renaming** — source column names are inconsistent. `customer_zip_code_prefix` becomes `zip_code_prefix`. Verbosity removed, meaning preserved.

**Type casting** — every timestamp column arrives as a string from the CSV. `cast(order_purchase_timestamp as timestamp)` makes it usable in date arithmetic downstream.

**Normalisation** — city names in the raw data are lowercase and inconsistent. `lower(trim(customer_city))` makes them consistent. State codes get `upper()`.

**Null handling** — the reviews table has two comment columns that contain empty strings rather than NULLs. `nullif(trim(review_comment_title), '')` converts them to proper NULLs so `IS NULL` filters work correctly.

**Typo fixing** — the products dataset has two columns named `product_name_lenght` and `product_description_lenght` (note the missing 't'). The staging model renames them to `product_name_length` and `product_description_length`. This kind of fix, documented in the model, is exactly what staging layers are for.

### Staging is views, not tables

Staging models are materialised as views in dbt. This means they hold no data themselves — they are just saved queries that execute against the raw tables each time they are queried. This keeps storage minimal and ensures that if raw data is reloaded, staging is automatically up to date.

Mart models, which analysts actually query, are materialised as tables for performance.

### The dbt project configuration

```yaml
# dbt_project.yml
models:
  ecommerce_dw:
    staging:
      +materialized: view
      +schema: staging
    marts:
      +materialized: table
      +schema: marts
```

This gives us clean schema separation: `marts_staging.*` for views, `marts_marts.*` for tables.

---

## 7. Step 4 — Building the Mart Layer with dbt

The mart layer is where the business logic lives. Three models, each answering a specific analytical question.

### `fact_orders` — the core fact table

This model joins all seven staging models into a single wide table at order-item grain. The joining logic follows a consistent pattern: start with `stg_order_items` as the base (because it defines the grain), then join `stg_orders` for order-level attributes, then `stg_customers`, `stg_sellers`, `stg_products` for dimension attributes, then `stg_order_payments` and `stg_order_reviews` for measures.

The payments CTE aggregates multiple payment rows per order into one:

```sql
payments as (
    select
        order_id,
        sum(payment_value)                                          as total_payment_value,
        max(payment_installments)                                   as payment_installments,
        max(case when payment_sequential = 1 then payment_type end) as payment_type
    from stg_order_payments
    group by order_id
)
```

The reviews CTE keeps only the most recent review per order:

```sql
reviews as (
    select
        order_id,
        review_score,
        review_created_at
    from stg_order_reviews
    qualify row_number() over (
        partition by order_id
        order by review_created_at desc
    ) = 1
)
```

Two computed delivery metrics are added at load time so analysts do not have to recalculate them in every query:

```sql
-- Positive = late, negative = early
cast(o.customer_delivered_at as date)
  - cast(o.estimated_delivery_at as date)   as days_delivery_delta
```

### `customer_lifetime_value` — one row per real customer

This model aggregates `fact_orders` by `customer_unique_id`. The challenge is that `customer_city` and `customer_state` are attributes of an order, not a person — and a person can order from multiple cities over time. The model resolves this by picking the location from the customer's most recent order using `QUALIFY`:

```sql
latest_location as (
    select customer_unique_id, customer_city, customer_state
    from orders
    qualify row_number() over (
        partition by customer_unique_id
        order by purchase_date desc
    ) = 1
)
```

Customers are then segmented:

```sql
case
    when total_orders = 1             then 'one_time'
    when total_orders between 2 and 3 then 'occasional'
    when total_orders >= 4            then 'loyal'
end as customer_segment
```

### `seller_performance` — one row per seller

This model is the most operationally useful. It surfaces, per seller: total revenue, average review score, average days to deliver, on-time delivery percentage, cancellation rate, and a performance tier assignment (excellent / good / average / poor based on average review score).

An analyst can run a single query against this table to identify every seller who is dragging down marketplace quality.

---

## 8. Step 5 — Testing Data Quality with dbt

dbt has a built-in testing framework. You declare tests in YAML alongside your models, and `dbt test` runs them as SQL queries — any row returned by a test query is a failure.

### The four test types used

**`not_null`** — applied to every primary key, foreign key, and measure that should never be empty. 47 tests in total.

**`unique`** — applied to every natural key and surrogate key. 14 tests.

**`accepted_values`** — applied to categorical columns that have a fixed set of valid values: `order_status` must be one of eight statuses, `payment_type` one of five types, `review_score` one of five integers, `performance_tier` one of four tiers.

**`relationships`** — the most important test type for a warehouse. These verify that every foreign key value in a child table exists in the parent table. 11 relationship tests cover every join boundary in the pipeline.

### The relationship tests

```yaml
# In _staging.yml
- name: stg_order_items
  columns:
    - name: order_id
      tests:
        - relationships:
            to: ref('stg_orders')
            field: order_id
    - name: product_id
      tests:
        - relationships:
            to: ref('stg_products')
            field: product_id
    - name: seller_id
      tests:
        - relationships:
            to: ref('stg_sellers')
            field: seller_id
```

Running `dbt test` with 91 tests across three layers and getting `PASS=90 WARN=1 ERROR=0` on real-world data is a strong signal that the pipeline is clean.

### The one warning — a real data quality discovery

The `unique` test on `stg_order_reviews.review_id` returned 789 failures: 789 `review_id` values appear more than once in the source CSV, some appearing up to 3 times.

This is not a pipeline bug. It is a genuine defect in the source data — the Olist dataset has duplicate review records. The right response is not to silently drop the duplicates, but to:

1. Document the finding explicitly
2. Handle it in the model (`QUALIFY ROW_NUMBER()` to keep the latest review per order)
3. Downgrade the test to `severity: warn` rather than `error` so the pipeline continues to run

This is one of the most valuable outcomes of building a test suite: it surfaces real data quality issues that would otherwise be invisible until they caused an analyst to report a wrong number.

---

## 9. Step 6 — Building the BI Dashboard with Evidence.dev

Evidence is unusual among BI tools because it is code-first. Every dashboard page is a Markdown file. SQL queries are embedded directly in code blocks. The tool compiles them into a static site.

This is the ideal setup for a portfolio project because the entire BI layer lives in the repository alongside the dbt models and can be reviewed, diffed, and version-controlled like any other code.

### Project structure

```
dashboard/
  sources/warehouse/
    connection.yaml          ← Points to warehouse.duckdb
    kpi_summary.sql          ← Pre-computed aggregates
    revenue_by_state.sql
    monthly_gmv.sql
    top_sellers.sql
    category_revenue.sql
    order_status_breakdown.sql
  pages/
    index.md                 ← Revenue Overview
    trends.md                ← GMV Trends
    sellers.md               ← Seller Performance
```

### How a page works

Each page is a Markdown file. SQL queries are declared in fenced code blocks labelled with `sql query_name`. The query result becomes a named dataset that chart components reference:

```markdown
```sql monthly_gmv
select
    date_trunc('month', purchase_date) as month,
    round(sum(gross_revenue), 2)       as gmv
from warehouse.monthly_gmv
group by 1
order by 1
```

<LineChart
    data={monthly_gmv}
    x=month
    y=gmv
    title="Monthly GMV (BRL)"
    yFmt=usd
    markers=true
/>
```

The entire dashboard compiles to a static site in the `dashboard/build/` directory — no server required to serve it.

### The three pages

**Revenue Overview** answers the question "how is the business performing overall?" — eight KPI cards at the top, a horizontal bar chart of revenue by Brazilian state (sorted descending so SP's dominance is immediately visible), a breakdown of the top 15 product categories, and an order status distribution chart.

**GMV Trends** answers "is the business growing?" — an interactive year filter, monthly GMV as a line chart, product revenue vs freight revenue as a stacked area chart, and delivery performance over time. The year filter is implemented with a Dropdown component that dynamically filters the underlying SQL.

**Seller Performance** answers "which sellers should we act on?" — a performance tier filter, revenue breakdown by tier and state, and a full sortable/searchable DataTable with colour-scaled review scores (red at 1, green at 5) and on-time delivery percentages.

---

## 10. Step 7 — Deploying to GitHub Pages with GitHub Actions

The deployment workflow chains dbt and Evidence together so that pushing code to `main` automatically rebuilds everything and publishes the updated dashboard.

```yaml
# .github/workflows/deploy-dashboard.yml
jobs:
  build-and-deploy:
    steps:
      - uses: actions/checkout@v4

      # Step 1: Rebuild the warehouse
      - name: Install dbt-duckdb
        run: pip install dbt-duckdb
      - name: Run dbt
        run: dbt run --profiles-dir .

      # Step 2: Rebuild the dashboard
      - name: Install Evidence
        run: npm ci
        working-directory: dashboard
      - name: Build sources
        run: npm run sources
        working-directory: dashboard
      - name: Build site
        run: npm run build
        working-directory: dashboard

      # Step 3: Publish
      - uses: peaceiris/actions-gh-pages@v4
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: dashboard/build
```

Once this runs, the dashboard is live at `https://<username>.github.io/ecommerce_data_warehouse/`. Enable GitHub Pages by going to **Settings → Pages** and setting the source to the `gh-pages` branch.

---

## 11. Challenges and How We Solved Them

Real projects always diverge from the plan. Here are the concrete obstacles encountered during this build and how each was resolved.

---

### Challenge 1 — `initcap()` Does Not Exist in DuckDB

**What happened:** The staging models for customers and sellers used `initcap(trim(city))` to title-case city names. This works in PostgreSQL. When dbt ran against DuckDB, the build failed immediately:

```
Catalog Error: Scalar Function with name initcap does not exist!
Did you mean "ilike_escape"?
```

**Why it matters:** This is a common trap when switching between SQL dialects. PostgreSQL and DuckDB share a lot of syntax, but not everything.

**The fix:** Replaced `initcap()` with `lower(trim(city))`. Looking at the raw data, city names were already lowercase (`franca`, `sao paulo`). There was nothing to title-case — the `initcap` call would have just made every city look like `Franca`, `Sao Paulo` with inconsistent capitalisation on multi-word names. Lowercase is consistent and safe.

**Lesson:** Always test your staging models against the actual target database early in the build. Dialect incompatibilities surface immediately.

---

### Challenge 2 — `DISTINCT ON` Is a PostgreSQL Extension

**What happened:** The `reviews` CTE in `fact_orders` was written using PostgreSQL's `DISTINCT ON` syntax to pick the most recent review per order:

```sql
reviews as (
    select distinct on (order_id)
        order_id, review_score
    from stg_order_reviews
    order by order_id, review_created_at desc
)
```

DuckDB does not support `DISTINCT ON`.

**The fix:** Replaced it with DuckDB's `QUALIFY` clause — a window function filter that evaluates after the window functions but before the `SELECT` output:

```sql
reviews as (
    select order_id, review_score
    from stg_order_reviews
    qualify row_number() over (
        partition by order_id
        order by review_created_at desc
    ) = 1
)
```

`QUALIFY` is actually cleaner than `DISTINCT ON` because it works with any window function, not just ordering-based deduplication.

---

### Challenge 3 — `QUALIFY` and `GROUP BY` Cannot Coexist in One Query

**What happened:** The `customer_lifetime_value` model originally tried to use `QUALIFY` inside the same CTE that had a `GROUP BY`. The intent was to pick the most recent city and state for each customer while also aggregating their order history:

```sql
-- This does not work
aggregated as (
    select customer_unique_id, customer_city, customer_state,
           count(distinct order_id) as total_orders, ...
    from orders
    qualify row_number() over (
        partition by customer_unique_id, order_id
        order by purchase_date desc
    ) = 1
    group by customer_unique_id, customer_city, customer_state
)
```

DuckDB threw a parser error at the `group by` clause.

**Why it fails:** `QUALIFY` filters rows after window functions are evaluated. `GROUP BY` happens before `SELECT`. The two cannot operate on the same result set simultaneously.

**The fix:** Split the concern into two separate CTEs — one to resolve the latest location, one to aggregate — and then join them:

```sql
latest_location as (
    select customer_unique_id, customer_city, customer_state
    from orders
    qualify row_number() over (
        partition by customer_unique_id
        order by purchase_date desc
    ) = 1
),
aggregated as (
    select customer_unique_id,
           count(distinct order_id) as total_orders, ...
    from orders
    group by customer_unique_id
),
final as (
    select a.*, l.customer_city, l.customer_state
    from aggregated a
    left join latest_location l
        on a.customer_unique_id = l.customer_unique_id
)
```

This is cleaner than the original approach and easier to reason about.

---

### Challenge 4 — Year Filter Type Mismatch in Evidence

**What happened:** The GMV Trends page had a year filter dropdown using Evidence's `<Dropdown>` component. The "All Years" option was given the wildcard value `%`, following the pattern from Evidence's own template. The filtered query used `=` for comparison:

```sql
where date_part('year', month) = '${inputs.year.value}'
```

When "All Years" was selected, this became `= '%'` — and DuckDB attempted to compare an `INT64` (the year integer) to the string `'%'`. The build failed with:

```
Conversion Error: Could not convert string '%' to INT64
```

**The fix:** Cast the year to a string before the comparison and switch from `=` to `LIKE`:

```sql
where cast(date_part('year', month) as varchar) like '${inputs.year.value}'
```

When a specific year is selected (e.g., `2017`), `LIKE '2017'` is equivalent to `= '2017'`. When "All Years" is selected, `LIKE '%'` matches everything. The wildcard now works as intended.

---

### Challenge 5 — Duplicate `review_id` Values in Source Data

**What happened:** The `unique` test on `stg_order_reviews.review_id` failed with 789 violations. 789 review IDs appeared more than once in the source CSV.

**Investigation:**

```python
con.execute("""
    SELECT review_id, count(*) as occurrences
    FROM raw.olist_order_reviews_dataset
    GROUP BY review_id HAVING count(*) > 1
    ORDER BY occurrences DESC LIMIT 5
""").fetchall()

# ('3415c9f764e478409e8e0660ae816dd2', 3)
# ('1fb4ddc969e6bea80e38deec00393a6f', 3)
# ...
```

Some review IDs appear three times — identical records. This is a defect in the source data, not the pipeline.

**The fix — three steps:**

1. **Handle it in the model** — `fact_orders` already uses `QUALIFY ROW_NUMBER()` to deduplicate before joining, so mart accuracy was never affected.

2. **Document it** — the finding is recorded in `docs/test_results.md` with the exact count, a sample, and an explanation of why it does not impact the marts.

3. **Downgrade the test** — rather than letting it block every dbt run, the `unique` test on `review_id` was given `severity: warn`. The pipeline continues to run; the anomaly stays visible in CI logs.

```yaml
- unique:
    config:
      severity: warn
      # 789 review_ids are duplicated in the Olist source dataset.
      # fact_orders deduplicates via QUALIFY before joining.
```

This is the correct engineering response: acknowledge the issue, mitigate it, and keep watching it.

---

### Challenge 6 — README Saved as UTF-16 LE

**What happened:** After writing the README, every character appeared double-spaced when the file was read back. Inspecting the binary header revealed `23 00` — the `#` character encoded as a two-byte UTF-16 LE sequence, with a null byte after every character.

**The fix:** A one-line Python script decoded the file as UTF-16 LE and re-wrote it as UTF-8:

```python
content = open('README.md', 'rb').read()
text = content.decode('utf-16-le')
with open('README.md', 'w', encoding='utf-8', newline='\n') as f:
    f.write(text)
```

**Lesson:** On Windows, text encoding issues are a real and recurring problem. When a file looks wrong, check the encoding before touching the content.

---

## 12. Lessons Learnt

After building this project end to end, here are the things that would be done differently or emphasised more on a second pass.

### Design the grain before you write any SQL

The most consequential decision in this project was choosing order-item grain over order grain for `fact_orders`. Making that decision at the schema design stage, before any code was written, avoided a refactor that would have touched every model. In a real team setting, this decision should be documented, reviewed, and signed off before implementation begins.

### Test as you build, not at the end

The dbt tests were written in parallel with the models, not after. This meant that the duplicate `review_id` issue was discovered during development, when fixing it was cheap. If tests had been left until the end, the same issue would have been found later, against data that had already propagated into downstream models.

### Staging models should be boring

The instinct when building staging models is to add value — aggregate, join, derive new columns. Resist this. A staging model that does too much becomes a maintenance problem. Keeping staging models to a narrow set of operations (cast, rename, normalise) makes them easy to audit and easy to replace when source schemas change.

### dbt's `relationships` test is the most valuable test type

The 11 relationship tests in this project would have caught any scenario where a foreign key value in `fact_orders` did not exist in the corresponding dimension. That kind of integrity failure is silent in plain SQL — queries return wrong results without any error. `dbt test` makes it noisy.

### DuckDB is genuinely production-capable for this scale

100,000+ order items. Aggregations across all of them. Complex window functions. Joins across eight source tables. DuckDB handles all of it in under two seconds on a laptop. For a portfolio project, or for a small team analytics environment, DuckDB eliminates the need for a cloud warehouse entirely.

### Evidence.dev turns SQL into a shareable portfolio artefact

The barrier to sharing analytical work is usually infrastructure — you need to host a server, manage credentials, or send someone a screenshot. Evidence's output is a static site that can be hosted on GitHub Pages at zero cost. Anyone with the URL can explore the dashboards, filter by year, sort the sellers table, and see the same numbers. That shareability is what makes it a legitimate portfolio piece rather than a local experiment.

### Document data quality issues — do not hide them

Finding 789 duplicate review IDs was a success, not a failure. The failure mode would have been silently dropping duplicates and never knowing they existed. Documenting the issue, the investigation, and the mitigation demonstrates data engineering maturity far more effectively than a test suite that never fails.

---

## 13. What to Build Next

This project has a solid foundation. Here are the natural next steps if you want to extend it:

**Add incremental dbt models** — the current models do a full refresh on every run. For larger datasets, dbt's incremental materialisation would process only new or changed rows, dramatically reducing build time.

**Add a `dim_time` table** — the star schema design includes a time dimension, but the current implementation uses date columns directly in the fact table rather than surrogate keys. Building a proper `dim_time` with pre-computed `is_weekend`, `is_holiday`, and `quarter` fields would make time-based analysis much faster.

**Build a geolocation layer** — the `olist_geolocation_dataset.csv` file maps zip codes to latitude and longitude. Adding this as a dimension would enable geographic distance analysis between customers and sellers, and open the door to actual map visualisations.

**Add a `customer_churn` model** — using the `customer_lifetime_value` model as a base, a churn model could identify customers who were active in 2017 but placed no orders in 2018. That kind of cohort analysis is high-value for any e-commerce business.

**Schedule the pipeline** — the GitHub Actions workflow currently runs on push. Adding a scheduled trigger (`cron: '0 6 * * 1'`) would rebuild the warehouse and dashboard every Monday morning without any manual intervention.

---

## Final Thoughts

Data engineering is often described as the plumbing of the data world — unglamorous infrastructure that nobody notices when it works and everyone complains about when it breaks.

This project tried to show that the plumbing can be built well, documented clearly, and made visible. A star schema designed with intention, a dbt pipeline with 91 tests, a dashboard that anyone can access, and a deployment pipeline that runs automatically — none of these require a cloud budget or an enterprise team.

The tools exist. The patterns are established. The main requirement is the discipline to apply them carefully, document what you find, and be honest about what the data actually says.

---

**Repository:** [github.com/Desmondonam/ecommerce_data_warehouse](https://github.com/Desmondonam/ecommerce_data_warehouse)  
**Dashboard:** [desmondonam.github.io/ecommerce_data_warehouse](https://desmondonam.github.io/ecommerce_data_warehouse)  
**Dataset:** [Olist Brazilian E-Commerce Public Dataset on Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

---

*Written by Desmond Onam · desmond.onam@havartechs.com*
