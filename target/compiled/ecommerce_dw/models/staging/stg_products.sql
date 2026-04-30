with source as (
    select * from "warehouse"."raw"."olist_products_dataset"
),

translations as (
    select * from "warehouse"."raw"."product_category_name_translation"
),

renamed as (
    select
        p.product_id,
        p.product_category_name                     as category_name,
        t.product_category_name_english             as category_name_english,
        -- source CSV has a typo: "lenght" instead of "length"
        p.product_name_lenght                       as product_name_length,
        p.product_description_lenght                as product_description_length,
        p.product_photos_qty                        as photos_qty,
        p.product_weight_g                          as weight_g,
        p.product_length_cm                         as length_cm,
        p.product_height_cm                         as height_cm,
        p.product_width_cm                          as width_cm
    from source p
    left join translations t
        on p.product_category_name = t.product_category_name
)

select * from renamed