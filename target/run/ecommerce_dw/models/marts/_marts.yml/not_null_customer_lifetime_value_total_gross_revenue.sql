
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select total_gross_revenue
from "warehouse"."marts_marts"."customer_lifetime_value"
where total_gross_revenue is null



  
  
      
    ) dbt_internal_test