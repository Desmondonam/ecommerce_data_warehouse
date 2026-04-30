select
    round(sum(gross_revenue), 2)                                    as total_gmv,
    count(distinct order_id)                                        as total_orders,
    round(avg(item_price), 2)                                       as avg_order_value,
    round(avg(review_score), 2)                                     as avg_review_score,
    count(distinct customer_unique_id)                              as unique_customers,
    count(distinct seller_id)                                       as active_sellers,
    round(
        100.0 * count(distinct case when order_status = 'delivered'
                                    then order_id end)
        / nullif(count(distinct order_id), 0), 1
    )                                                               as delivery_rate_pct,
    round(avg(case when days_to_deliver is not null
                   then days_to_deliver end), 1)                    as avg_days_to_deliver
from marts_marts.fact_orders
