
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select last_order_date
from "warehouse"."marts_marts"."customer_lifetime_value"
where last_order_date is null



  
  
      
    ) dbt_internal_test