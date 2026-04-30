select
    order_status,
    count(distinct order_id)                                        as orders,
    round(100.0 * count(distinct order_id)
          / sum(count(distinct order_id)) over (), 1)               as pct_of_total
from marts_marts.fact_orders
group by order_status
order by orders desc
