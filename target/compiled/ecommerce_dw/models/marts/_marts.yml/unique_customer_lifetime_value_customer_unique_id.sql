
    
    

select
    customer_unique_id as unique_field,
    count(*) as n_records

from "warehouse"."marts_marts"."customer_lifetime_value"
where customer_unique_id is not null
group by customer_unique_id
having count(*) > 1


