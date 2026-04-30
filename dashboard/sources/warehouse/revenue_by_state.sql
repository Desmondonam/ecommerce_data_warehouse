select
    upper(customer_state)                                           as state,
    round(sum(gross_revenue), 2)                                    as total_revenue,
    count(distinct order_id)                                        as total_orders,
    count(distinct customer_unique_id)                              as unique_customers,
    round(avg(item_price), 2)                                       as avg_order_value,
    round(avg(review_score), 2)                                     as avg_review_score
from marts_marts.fact_orders
group by upper(customer_state)
order by total_revenue desc
