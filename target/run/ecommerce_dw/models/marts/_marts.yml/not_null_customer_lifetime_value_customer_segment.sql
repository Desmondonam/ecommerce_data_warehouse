
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select customer_segment
from "warehouse"."marts_marts"."customer_lifetime_value"
where customer_segment is null



  
  
      
    ) dbt_internal_test