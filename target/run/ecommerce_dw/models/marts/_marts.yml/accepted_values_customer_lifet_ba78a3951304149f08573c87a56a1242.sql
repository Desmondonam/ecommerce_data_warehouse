
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        customer_segment as value_field,
        count(*) as n_records

    from "warehouse"."marts_marts"."customer_lifetime_value"
    group by customer_segment

)

select *
from all_values
where value_field not in (
    'one_time','occasional','loyal'
)



  
  
      
    ) dbt_internal_test