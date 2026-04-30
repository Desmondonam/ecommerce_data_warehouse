/*
  One row per unique customer (customer_unique_id).
  Aggregates all orders across different customer_ids that belong to the same real person.
*/

with orders as (
    select * from "warehouse"."marts_marts"."fact_orders"
),

-- Most recent city/state per unique customer, resolved before aggregation.
latest_location as (
    select
        customer_unique_id,
        customer_city,
        customer_state
    from orders
    qualify row_number() over (
        partition by customer_unique_id
        order by purchase_date desc
    ) = 1
),

aggregated as (
    select
        o.customer_unique_id,

        -- Order behaviour
        count(distinct o.order_id)                                  as total_orders,
        count(*)                                                     as total_items_purchased,
        min(o.purchase_date)                                         as first_order_date,
        max(o.purchase_date)                                         as last_order_date,
        max(o.purchase_date) - min(o.purchase_date)                  as customer_tenure_days,

        -- Revenue
        round(sum(o.item_price), 2)                                  as total_item_spend,
        round(sum(o.freight_value), 2)                               as total_freight_paid,
        round(sum(o.gross_revenue), 2)                               as total_gross_revenue,
        round(avg(o.item_price), 2)                                  as avg_item_price,
        round(sum(o.gross_revenue) / nullif(count(distinct o.order_id), 0), 2)
                                                                     as avg_order_value,

        -- Satisfaction
        round(avg(o.review_score), 2)                                as avg_review_score,

        -- Order outcomes
        count(distinct case when o.order_status = 'delivered'
                            then o.order_id end)                     as delivered_orders,
        count(distinct case when o.order_status = 'canceled'
                            then o.order_id end)                     as canceled_orders,

        -- Product breadth
        count(distinct o.category_name_english)                      as unique_categories_purchased

    from orders o
    group by o.customer_unique_id
),

segmented as (
    select
        a.*,
        l.customer_city,
        l.customer_state,

        case
            when a.total_orders = 1               then 'one_time'
            when a.total_orders between 2 and 3   then 'occasional'
            when a.total_orders >= 4              then 'loyal'
        end                                                          as customer_segment,

        round(
            100.0 * a.canceled_orders / nullif(a.total_orders, 0),
            2
        )                                                            as cancellation_rate_pct

    from aggregated a
    left join latest_location l on a.customer_unique_id = l.customer_unique_id
)

select * from segmented