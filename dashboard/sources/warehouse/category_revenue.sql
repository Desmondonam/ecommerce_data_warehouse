select
    coalesce(category_name_english, 'uncategorised')                as category,
    round(sum(gross_revenue), 2)                                    as total_revenue,
    count(distinct order_id)                                        as total_orders,
    count(distinct product_id)                                      as unique_products,
    round(avg(item_price), 2)                                       as avg_item_price,
    round(avg(review_score), 2)                                     as avg_review_score
from marts_marts.fact_orders
group by coalesce(category_name_english, 'uncategorised')
order by total_revenue desc
