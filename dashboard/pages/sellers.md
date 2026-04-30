---
title: Seller Performance
---

# Seller Performance

```sql sellers
select * from warehouse.top_sellers
```

```sql tier_summary
select
    performance_tier,
    count(*)                            as seller_count,
    round(sum(total_revenue), 2)        as tier_revenue,
    round(avg(avg_review_score), 2)     as avg_score,
    round(avg(on_time_pct), 1)          as avg_on_time_pct
from warehouse.top_sellers
group by performance_tier
order by tier_revenue desc
```

```sql sellers_by_state
select
    state,
    count(*)                            as seller_count,
    round(sum(total_revenue), 2)        as total_revenue,
    round(avg(avg_review_score), 2)     as avg_score
from warehouse.top_sellers
group by state
order by total_revenue desc
limit 15
```

```sql filtered_sellers
select * from warehouse.top_sellers
where performance_tier like '${inputs.tier.value}'
order by total_revenue desc
```

---

## Performance Tier Filter

<Dropdown data={sellers} name=tier value=performance_tier title="Performance Tier">
    <DropdownOption value="%" valueLabel="All Tiers"/>
</Dropdown>

---

## Tier Breakdown

<BarChart
    data={tier_summary}
    x=performance_tier
    y=seller_count
    title="Sellers by Performance Tier"
    labels=true
    colorPalette={['#16a34a','#2563eb','#f8c900','#dc2626']}
/>

<BarChart
    data={tier_summary}
    x=performance_tier
    y=tier_revenue
    title="Revenue by Performance Tier (BRL)"
    labels=true
    yFmt=usd
    colorPalette={['#16a34a','#2563eb','#f8c900','#dc2626']}
/>

---

## Revenue by Seller State (Top 15)

<BarChart
    data={sellers_by_state}
    x=state
    y=total_revenue
    title="Seller Revenue by State"
    horizontal=true
    yFmt=usd
    colorPalette={['#2563eb']}
/>

---

## Top Sellers Table

<DataTable data={filtered_sellers} rows=20 search=true>
    <Column id=seller_id title="Seller ID"/>
    <Column id=city title="City"/>
    <Column id=state title="State"/>
    <Column id=total_revenue title="Revenue (BRL)" fmt=usd contentType=bar/>
    <Column id=total_orders title="Orders" fmt=num0/>
    <Column id=avg_item_price title="Avg Price" fmt=usd/>
    <Column id=avg_review_score title="Review Score" fmt=num2 contentType=colorscale colorScale={['#dc2626','#f8c900','#16a34a']} colorMin=1 colorMax=5/>
    <Column id=avg_days_to_deliver title="Avg Delivery (days)" fmt=num1/>
    <Column id=on_time_pct title="On-Time %" fmt=pct1/>
    <Column id=unique_categories title="Categories"/>
    <Column id=performance_tier title="Tier"/>
</DataTable>
