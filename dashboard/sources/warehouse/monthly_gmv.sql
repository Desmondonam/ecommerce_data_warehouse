select
    date_trunc('month', purchase_date)                              as month,
    round(sum(gross_revenue), 2)                                    as gmv,
    round(sum(item_price), 2)                                       as product_revenue,
    round(sum(freight_value), 2)                                    as freight_revenue,
    count(distinct order_id)                                        as orders,
    count(distinct customer_unique_id)                              as unique_customers,
    round(avg(item_price), 2)                                       as avg_order_value,
    round(avg(review_score), 2)                                     as avg_review_score,
    round(avg(case when days_to_deliver is not null
                   then days_to_deliver end), 1)                    as avg_days_to_deliver
from marts_marts.fact_orders
where purchase_date is not null
group by date_trunc('month', purchase_date)
order by month
