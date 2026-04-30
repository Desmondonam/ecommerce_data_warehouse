
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        performance_tier as value_field,
        count(*) as n_records

    from "warehouse"."marts_marts"."seller_performance"
    group by performance_tier

)

select *
from all_values
where value_field not in (
    'excellent','good','average','poor'
)



  
  
      
    ) dbt_internal_test