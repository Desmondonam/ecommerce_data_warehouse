select
    seller_id,
    seller_city                                                     as city,
    upper(seller_state)                                             as state,
    total_orders,
    total_items_sold,
    round(total_revenue, 2)                                         as total_revenue,
    round(avg_item_price, 2)                                        as avg_item_price,
    round(avg_review_score, 2)                                      as avg_review_score,
    round(avg_days_to_deliver, 1)                                   as avg_days_to_deliver,
    round(on_time_delivery_pct, 1)                                  as on_time_pct,
    round(cancellation_rate_pct, 1)                                 as cancellation_pct,
    unique_products_sold,
    unique_categories,
    performance_tier
from marts_marts.seller_performance
order by total_revenue desc
