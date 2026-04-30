/*
  Grain: one row per order item.
  Payment value is prorated per item by its share of the order's total item price.
  Review score is taken from the most recent review when multiple exist.
*/

with orders as (
    select * from {{ ref('stg_orders') }}
),

order_items as (
    select * from {{ ref('stg_order_items') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

sellers as (
    select * from {{ ref('stg_sellers') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

-- Aggregate all payment rows to a single order-level record.
-- Primary payment type = the instrument with payment_sequential = 1.
payments as (
    select
        order_id,
        sum(payment_value)                                          as total_payment_value,
        max(payment_installments)                                   as payment_installments,
        max(case when payment_sequential = 1 then payment_type end) as payment_type
    from {{ ref('stg_order_payments') }}
    group by order_id
),

-- Keep the most recent review per order to avoid fan-out on the join.
reviews as (
    select
        order_id,
        review_score,
        review_created_at
    from {{ ref('stg_order_reviews') }}
    qualify row_number() over (
        partition by order_id
        order by review_created_at desc
    ) = 1
),

-- Total item price per order, used to prorate the payment across items.
order_totals as (
    select
        order_id,
        sum(item_price) as total_item_price
    from order_items
    group by order_id
),

final as (
    select
        -- ── Degenerate dimensions ──────────────────────────────────────────
        oi.order_id,
        oi.order_item_id,
        o.order_status,

        -- ── Natural keys (use to join to dim tables) ───────────────────────
        o.customer_id,
        oi.seller_id,
        oi.product_id,

        -- ── Date keys (grain: purchase date; additional lifecycle dates) ───
        cast(o.purchased_at as date)            as purchase_date,
        cast(o.approved_at as date)             as approved_date,
        cast(o.customer_delivered_at as date)   as delivered_date,
        cast(o.estimated_delivery_at as date)   as estimated_delivery_date,

        -- ── Customer attributes ────────────────────────────────────────────
        c.customer_unique_id,
        c.city                                  as customer_city,
        c.state                                 as customer_state,

        -- ── Seller attributes ──────────────────────────────────────────────
        s.city                                  as seller_city,
        s.state                                 as seller_state,

        -- ── Product attributes ─────────────────────────────────────────────
        p.category_name,
        p.category_name_english,

        -- ── Item-level measures ────────────────────────────────────────────
        oi.item_price,
        oi.freight_value,
        oi.item_price + oi.freight_value        as gross_revenue,

        -- ── Payment measures (prorated per item) ───────────────────────────
        case
            when ot.total_item_price > 0
                then round(
                    pay.total_payment_value * (oi.item_price / ot.total_item_price),
                    2
                )
            else pay.total_payment_value
        end                                     as payment_value,
        pay.payment_installments,
        pay.payment_type,

        -- ── Review measures ────────────────────────────────────────────────
        r.review_score,

        -- ── Delivery performance (in days) ─────────────────────────────────
        case
            when o.customer_delivered_at is not null
                then cast(o.customer_delivered_at as date)
                     - cast(o.purchased_at as date)
        end                                     as days_to_deliver,

        -- Positive = late, negative = early
        case
            when o.customer_delivered_at is not null
             and o.estimated_delivery_at is not null
                then cast(o.customer_delivered_at as date)
                     - cast(o.estimated_delivery_at as date)
        end                                     as days_delivery_delta

    from order_items oi
    inner join orders       o   on oi.order_id  = o.order_id
    inner join customers    c   on o.customer_id = c.customer_id
    left  join sellers      s   on oi.seller_id  = s.seller_id
    left  join products     p   on oi.product_id = p.product_id
    left  join payments     pay on oi.order_id   = pay.order_id
    left  join reviews      r   on oi.order_id   = r.order_id
    left  join order_totals ot  on oi.order_id   = ot.order_id
)

select * from final
