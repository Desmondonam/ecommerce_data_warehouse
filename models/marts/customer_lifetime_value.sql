/*
  One row per unique customer (customer_unique_id).
  Aggregates all orders across different customer_ids that belong to the same real person.
*/

with orders as (
    select * from {{ ref('fact_orders') }}
),

aggregated as (
    select
        customer_unique_id,

        -- Latest known location (most recent order wins)
        customer_city,
        customer_state,

        -- Order behaviour
        count(distinct order_id)                                as total_orders,
        count(*)                                                as total_items_purchased,
        min(purchase_date)                                      as first_order_date,
        max(purchase_date)                                      as last_order_date,
        max(purchase_date) - min(purchase_date)                 as customer_tenure_days,

        -- Revenue
        round(sum(item_price), 2)                               as total_item_spend,
        round(sum(freight_value), 2)                            as total_freight_paid,
        round(sum(gross_revenue), 2)                            as total_gross_revenue,
        round(avg(item_price), 2)                               as avg_item_price,
        round(sum(gross_revenue) / nullif(count(distinct order_id), 0), 2)
                                                                as avg_order_value,

        -- Satisfaction
        round(avg(review_score), 2)                             as avg_review_score,

        -- Order outcomes
        count(distinct case when order_status = 'delivered'
                            then order_id end)                  as delivered_orders,
        count(distinct case when order_status = 'canceled'
                            then order_id end)                  as canceled_orders,

        -- Categories purchased
        count(distinct category_name_english)                   as unique_categories_purchased

    from orders
    -- Use the row with the most recent purchase to anchor location columns
    -- (window function picks the right city/state before aggregation)
    qualify row_number() over (
        partition by customer_unique_id, order_id
        order by purchase_date desc
    ) = 1
    group by customer_unique_id, customer_city, customer_state
),

segmented as (
    select
        *,
        case
            when total_orders = 1               then 'one_time'
            when total_orders between 2 and 3   then 'occasional'
            when total_orders >= 4              then 'loyal'
        end                                                     as customer_segment,

        round(
            100.0 * canceled_orders / nullif(total_orders, 0),
            2
        )                                                       as cancellation_rate_pct
    from aggregated
)

select * from segmented
