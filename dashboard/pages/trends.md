---
title: GMV Trends
---

# Monthly GMV Trends

Monthly performance from September 2016 through October 2018.

```sql monthly
select * from warehouse.monthly_gmv
```

```sql monthly_filtered
select * from warehouse.monthly_gmv
where cast(date_part('year', month) as varchar) like '${inputs.year.value}'
```

<Dropdown name=year title="Filter by Year">
    <DropdownOption value=% valueLabel="All Years"/>
    <DropdownOption value=2016/>
    <DropdownOption value=2017/>
    <DropdownOption value=2018/>
</Dropdown>

---

## Gross Merchandise Value

<LineChart
    data={monthly_filtered}
    x=month
    y=gmv
    title="Monthly GMV (BRL)"
    yAxisTitle="Gross Revenue (BRL)"
    xAxisTitle="Month"
    yFmt=usd
    markers=true
    colorPalette={['#2563eb']}
/>

---

## Revenue Composition

> Product revenue vs freight revenue each month.

<AreaChart
    data={monthly_filtered}
    x=month
    y={['product_revenue','freight_revenue']}
    title="Product Revenue vs Freight Revenue"
    yAxisTitle="Revenue (BRL)"
    yFmt=usd
    fillColor={['#2563eb','#93c5fd']}
/>

---

## Order Volume & New Customers

<LineChart
    data={monthly_filtered}
    x=month
    y={['orders','unique_customers']}
    title="Monthly Orders vs Unique Customers"
    yAxisTitle="Count"
    markers=true
/>

---

## Average Order Value Over Time

<LineChart
    data={monthly_filtered}
    x=month
    y=avg_order_value
    title="Avg Order Value (BRL)"
    yFmt=usd
    markers=true
    colorPalette={['#16a34a']}
/>

---

## Delivery Performance Over Time

<LineChart
    data={monthly_filtered}
    x=month
    y={['avg_days_to_deliver','avg_review_score']}
    title="Avg Days to Deliver & Review Score"
    yAxisTitle="Days / Score"
    markers=true
    colorPalette={['#dc2626','#f8c900']}
/>

---

## Monthly Data Table

<DataTable data={monthly_filtered} rows=24>
    <Column id=month title="Month" fmt="MMM YYYY"/>
    <Column id=gmv title="GMV (BRL)" fmt=usd contentType=bar/>
    <Column id=orders title="Orders" fmt=num0/>
    <Column id=unique_customers title="Customers" fmt=num0/>
    <Column id=avg_order_value title="Avg Order" fmt=usd/>
    <Column id=avg_review_score title="Avg Score" fmt=num2/>
    <Column id=avg_days_to_deliver title="Avg Delivery (days)" fmt=num1/>
</DataTable>
