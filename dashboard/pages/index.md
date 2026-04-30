---
title: Revenue Overview
---

# Olist E-Commerce Dashboard

Brazilian e-commerce marketplace · 2016 – 2018 · {kpi.total_orders} orders across {kpi.unique_customers} customers

```sql kpi
select * from warehouse.kpi_summary
```

```sql state_revenue
select * from warehouse.revenue_by_state
```

```sql status
select * from warehouse.order_status_breakdown
```

```sql categories
select * from warehouse.category_revenue
limit 15
```

---

## Key Metrics

<BigValue
    data={kpi}
    value=total_gmv
    title="Total GMV"
    fmt=usd
/>

<BigValue
    data={kpi}
    value=total_orders
    title="Total Orders"
    fmt=num0
/>

<BigValue
    data={kpi}
    value=avg_order_value
    title="Avg Order Value"
    fmt=usd
/>

<BigValue
    data={kpi}
    value=avg_review_score
    title="Avg Review Score"
    fmt=num2
/>

<BigValue
    data={kpi}
    value=unique_customers
    title="Unique Customers"
    fmt=num0
/>

<BigValue
    data={kpi}
    value=active_sellers
    title="Active Sellers"
    fmt=num0
/>

<BigValue
    data={kpi}
    value=delivery_rate_pct
    title="Delivery Rate"
    fmt=pct1
/>

<BigValue
    data={kpi}
    value=avg_days_to_deliver
    title="Avg Days to Deliver"
    fmt=num1
/>

---

## Revenue by State

> Brazilian states ranked by gross revenue (product price + freight). SP (São Paulo) dominates as Brazil's commercial hub.

<BarChart
    data={state_revenue}
    x=state
    y=total_revenue
    xAxisTitle="State"
    yAxisTitle="Gross Revenue (BRL)"
    title="Gross Revenue by Customer State"
    horizontal=true
    labels=true
    colorPalette={['#2563eb']}
    fmt=usd
/>

<DataTable data={state_revenue} rows=10 search=true>
    <Column id=state title="State"/>
    <Column id=total_revenue title="GMV (BRL)" fmt=usd contentType=bar/>
    <Column id=total_orders title="Orders" fmt=num0/>
    <Column id=unique_customers title="Customers" fmt=num0/>
    <Column id=avg_order_value title="Avg Order" fmt=usd/>
    <Column id=avg_review_score title="Avg Score" fmt=num2/>
</DataTable>

---

## Top Product Categories

<BarChart
    data={categories}
    x=category
    y=total_revenue
    xAxisTitle="Category"
    yAxisTitle="Revenue (BRL)"
    title="Revenue by Product Category (Top 15)"
    horizontal=true
    fmt=usd
/>

---

## Order Status Distribution

<BarChart
    data={status}
    x=order_status
    y=orders
    title="Orders by Status"
    labels=true
    colorPalette={['#16a34a','#2563eb','#dc2626','#f8c900','#6b7280','#7c3aed','#0284c7','#c2410c']}
/>
