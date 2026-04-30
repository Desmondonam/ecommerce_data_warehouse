/*
  One row per seller.
  Covers revenue, product breadth, delivery reliability, and customer satisfaction.
*/

with orders as (
    select * from {{ ref('fact_orders') }}
),

aggregated as (
    select
        seller_id,
        seller_city,
        seller_state,

        -- Volume
        count(distinct order_id)                                as total_orders,
        count(*)                                                as total_items_sold,
        count(distinct product_id)                              as unique_products_sold,
        count(distinct category_name_english)                   as unique_categories,

        -- Revenue
        round(sum(item_price), 2)                               as total_revenue,
        round(sum(freight_value), 2)                            as total_freight_collected,
        round(sum(gross_revenue), 2)                            as total_gross_revenue,
        round(avg(item_price), 2)                               as avg_item_price,

        -- Delivery performance (only for delivered orders)
        round(avg(
            case when order_status = 'delivered'
                 then days_to_deliver end
        ), 1)                                                   as avg_days_to_deliver,

        sum(case when days_delivery_delta > 0 then 1 else 0 end)    as late_deliveries,
        sum(case when days_delivery_delta <= 0 then 1 else 0 end)   as on_time_deliveries,

        -- Satisfaction
        round(avg(review_score), 2)                             as avg_review_score,
        sum(case when review_score = 5 then 1 else 0 end)      as five_star_reviews,
        sum(case when review_score <= 2 then 1 else 0 end)     as low_score_reviews,

        -- Order outcomes
        count(distinct case when order_status = 'delivered'
                            then order_id end)                  as delivered_orders,
        count(distinct case when order_status = 'canceled'
                            then order_id end)                  as canceled_orders

    from orders
    group by seller_id, seller_city, seller_state
),

scored as (
    select
        *,

        round(
            100.0 * on_time_deliveries / nullif(late_deliveries + on_time_deliveries, 0),
            2
        )                                                       as on_time_delivery_pct,

        round(
            100.0 * canceled_orders / nullif(total_orders, 0),
            2
        )                                                       as cancellation_rate_pct,

        case
            when avg_review_score >= 4.5 then 'excellent'
            when avg_review_score >= 3.5 then 'good'
            when avg_review_score >= 2.5 then 'average'
            else 'poor'
        end                                                     as performance_tier
    from aggregated
)

select * from scored
