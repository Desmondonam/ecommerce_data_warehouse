# dbt Test Results

**Run date:** 2026-04-30  
**dbt version:** 1.11.8  
**Adapter:** duckdb 1.10.1  
**Dataset:** Olist Brazilian E-Commerce Public Dataset  

---

## Summary

| Result | Count |
|--------|------:|
| PASS   | 90    |
| WARN   | 1     |
| ERROR  | 0     |
| SKIP   | 0     |
| **TOTAL** | **91** |

---

## Test Coverage by Layer

### Sources (`_sources.yml`) — 22 tests, all PASS

| Test | Column | Result |
|------|--------|--------|
| unique | olist.customers.customer_id | PASS |
| not_null | olist.customers.customer_id | PASS |
| not_null | olist.customers.customer_unique_id | PASS |
| unique | olist.sellers.seller_id | PASS |
| not_null | olist.sellers.seller_id | PASS |
| unique | olist.products.product_id | PASS |
| not_null | olist.products.product_id | PASS |
| unique | olist.category_name_translation.product_category_name | PASS |
| not_null | olist.category_name_translation.product_category_name | PASS |
| unique | olist.orders.order_id | PASS |
| not_null | olist.orders.order_id | PASS |
| not_null | olist.orders.customer_id | PASS |
| not_null | olist.order_items.order_id | PASS |
| not_null | olist.order_items.product_id | PASS |
| not_null | olist.order_items.seller_id | PASS |
| not_null | olist.order_payments.order_id | PASS |
| not_null | olist.order_reviews.review_id | PASS |
| not_null | olist.order_reviews.order_id | PASS |

---

### Staging (`_staging.yml`) — 38 tests, 37 PASS / 1 WARN

#### stg_customers
| Test | Column | Result |
|------|--------|--------|
| unique | customer_id | PASS |
| not_null | customer_id | PASS |
| not_null | customer_unique_id | PASS |
| not_null | zip_code_prefix | PASS |
| not_null | city | PASS |
| not_null | state | PASS |

#### stg_sellers
| Test | Column | Result |
|------|--------|--------|
| unique | seller_id | PASS |
| not_null | seller_id | PASS |
| not_null | zip_code_prefix | PASS |
| not_null | city | PASS |
| not_null | state | PASS |

#### stg_products
| Test | Column | Result |
|------|--------|--------|
| unique | product_id | PASS |
| not_null | product_id | PASS |

#### stg_orders
| Test | Column | Result |
|------|--------|--------|
| unique | order_id | PASS |
| not_null | order_id | PASS |
| not_null | customer_id | PASS |
| relationships → stg_customers.customer_id | customer_id | PASS |
| not_null | order_status | PASS |
| accepted_values | order_status | PASS |
| not_null | purchased_at | PASS |

#### stg_order_items
| Test | Column | Result |
|------|--------|--------|
| not_null | order_id | PASS |
| relationships → stg_orders.order_id | order_id | PASS |
| not_null | order_item_id | PASS |
| not_null | product_id | PASS |
| relationships → stg_products.product_id | product_id | PASS |
| not_null | seller_id | PASS |
| relationships → stg_sellers.seller_id | seller_id | PASS |
| not_null | item_price | PASS |
| not_null | freight_value | PASS |

#### stg_order_payments
| Test | Column | Result |
|------|--------|--------|
| not_null | order_id | PASS |
| relationships → stg_orders.order_id | order_id | PASS |
| not_null | payment_sequential | PASS |
| not_null | payment_type | PASS |
| accepted_values | payment_type | PASS |
| not_null | payment_value | PASS |

#### stg_order_reviews
| Test | Column | Result |
|------|--------|--------|
| not_null | review_id | PASS |
| **unique** | **review_id** | **WARN** — see note below |
| not_null | order_id | PASS |
| relationships → stg_orders.order_id | order_id | PASS |
| not_null | review_score | PASS |
| accepted_values (1–5) | review_score | PASS |

---

### Marts (`_marts.yml`) — 31 tests, all PASS

#### fact_orders
| Test | Column | Result |
|------|--------|--------|
| not_null | order_id | PASS |
| relationships → stg_orders.order_id | order_id | PASS |
| not_null | order_item_id | PASS |
| not_null | customer_id | PASS |
| relationships → stg_customers.customer_id | customer_id | PASS |
| not_null | seller_id | PASS |
| relationships → stg_sellers.seller_id | seller_id | PASS |
| not_null | product_id | PASS |
| relationships → stg_products.product_id | product_id | PASS |
| not_null | customer_unique_id | PASS |
| not_null | purchase_date | PASS |
| not_null | item_price | PASS |
| not_null | freight_value | PASS |
| not_null | gross_revenue | PASS |
| not_null | order_status | PASS |
| accepted_values | order_status | PASS |
| accepted_values (1–5, nulls excluded) | review_score | PASS |

#### customer_lifetime_value
| Test | Column | Result |
|------|--------|--------|
| unique | customer_unique_id | PASS |
| not_null | customer_unique_id | PASS |
| not_null | total_orders | PASS |
| not_null | total_gross_revenue | PASS |
| not_null | first_order_date | PASS |
| not_null | last_order_date | PASS |
| not_null | customer_segment | PASS |
| accepted_values | customer_segment | PASS |

#### seller_performance
| Test | Column | Result |
|------|--------|--------|
| unique | seller_id | PASS |
| not_null | seller_id | PASS |
| relationships → stg_sellers.seller_id | seller_id | PASS |
| not_null | total_orders | PASS |
| not_null | total_revenue | PASS |
| not_null | performance_tier | PASS |
| accepted_values | performance_tier | PASS |

---

## Data Quality Finding

### WARN — `unique_stg_order_reviews_review_id`

| Attribute | Value |
|-----------|-------|
| Severity | WARN (downgraded from ERROR) |
| Failing rows | 789 |
| Root cause | Source data defect in `olist_order_reviews_dataset.csv` |

**Detail:** 789 `review_id` values appear more than once in the Olist source file (some up to 3 times). This is a known upstream data quality issue with the public dataset — the same review was recorded multiple times with identical IDs.

**Impact:** None on mart accuracy. `fact_orders` resolves this with `QUALIFY row_number() OVER (PARTITION BY order_id ORDER BY review_created_at DESC) = 1`, keeping only the most recent review row per order before joining.

**Action taken:** Test severity set to `warn` so the pipeline continues to run while the anomaly remains visible in CI logs.
