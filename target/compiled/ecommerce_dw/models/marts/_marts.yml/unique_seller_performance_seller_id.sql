
    
    

select
    seller_id as unique_field,
    count(*) as n_records

from "warehouse"."marts_marts"."seller_performance"
where seller_id is not null
group by seller_id
having count(*) > 1


