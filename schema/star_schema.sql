-- =============================================================================
-- E-Commerce Data Warehouse — Star Schema DDL
-- Grain: one row per order item (fact_orders)
-- Source: Brazilian E-Commerce Public Dataset (Olist)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- DIMENSION: dim_customers
-- Source: olist_customers_dataset.csv
-- -----------------------------------------------------------------------------
CREATE TABLE dim_customers (
    customer_key        SERIAL          PRIMARY KEY,          -- surrogate key
    customer_id         VARCHAR(50)     NOT NULL UNIQUE,      -- natural key
    customer_unique_id  VARCHAR(50)     NOT NULL,             -- deduplication key (repeat buyers share this)
    zip_code_prefix     VARCHAR(10),
    city                VARCHAR(100),
    state               CHAR(2)
);

-- -----------------------------------------------------------------------------
-- DIMENSION: dim_sellers
-- Source: olist_sellers_dataset.csv
-- -----------------------------------------------------------------------------
CREATE TABLE dim_sellers (
    seller_key          SERIAL          PRIMARY KEY,          -- surrogate key
    seller_id           VARCHAR(50)     NOT NULL UNIQUE,      -- natural key
    zip_code_prefix     VARCHAR(10),
    city                VARCHAR(100),
    state               CHAR(2)
);

-- -----------------------------------------------------------------------------
-- DIMENSION: dim_products
-- Source: olist_products_dataset.csv + product_category_name_translation.csv
-- -----------------------------------------------------------------------------
CREATE TABLE dim_products (
    product_key                 SERIAL          PRIMARY KEY,  -- surrogate key
    product_id                  VARCHAR(50)     NOT NULL UNIQUE, -- natural key
    category_name               VARCHAR(100),                 -- original Portuguese name
    category_name_english       VARCHAR(100),                 -- translated via join
    product_name_length         INT,
    product_description_length  INT,
    photos_qty                  INT,
    weight_g                    INT,
    length_cm                   INT,
    height_cm                   INT,
    width_cm                    INT
);

-- -----------------------------------------------------------------------------
-- DIMENSION: dim_time
-- Source: derived from order_purchase_timestamp in olist_orders_dataset.csv
-- Covers the full range of dates present in the orders data
-- -----------------------------------------------------------------------------
CREATE TABLE dim_time (
    time_key        SERIAL          PRIMARY KEY,              -- surrogate key
    full_date       DATE            NOT NULL UNIQUE,          -- natural key
    year            SMALLINT        NOT NULL,
    quarter         SMALLINT        NOT NULL,                 -- 1–4
    month           SMALLINT        NOT NULL,                 -- 1–12
    month_name      VARCHAR(10)     NOT NULL,                 -- 'January' …
    week_of_year    SMALLINT        NOT NULL,                 -- ISO week 1–53
    day_of_month    SMALLINT        NOT NULL,                 -- 1–31
    day_of_week     SMALLINT        NOT NULL,                 -- 1=Mon … 7=Sun (ISO)
    day_name        VARCHAR(10)     NOT NULL,                 -- 'Monday' …
    is_weekend      BOOLEAN         NOT NULL                  -- TRUE for Sat/Sun
);

-- -----------------------------------------------------------------------------
-- FACT TABLE: fact_orders
-- Grain: one row per order item
-- Source: olist_orders + olist_order_items + olist_order_payments (aggregated)
--         + olist_order_reviews (aggregated to order level)
-- -----------------------------------------------------------------------------
CREATE TABLE fact_orders (
    order_item_key          BIGSERIAL       PRIMARY KEY,

    -- Degenerate dimensions (business keys kept on the fact for drill-through)
    order_id                VARCHAR(50)     NOT NULL,
    order_item_id           SMALLINT        NOT NULL,         -- line number within an order

    -- Foreign keys to dimensions
    customer_key            INT             NOT NULL REFERENCES dim_customers(customer_key),
    seller_key              INT             NOT NULL REFERENCES dim_sellers(seller_key),
    product_key             INT             NOT NULL REFERENCES dim_products(product_key),
    purchase_time_key       INT             NOT NULL REFERENCES dim_time(time_key),
    approved_time_key       INT                      REFERENCES dim_time(time_key),
    delivered_time_key      INT                      REFERENCES dim_time(time_key),  -- actual delivery date
    estimated_time_key      INT                      REFERENCES dim_time(time_key),  -- estimated delivery date

    -- Order-level degenerate dimension
    order_status            VARCHAR(20)     NOT NULL,         -- 'delivered', 'shipped', etc.

    -- Item-level measures
    item_price              NUMERIC(10,2)   NOT NULL,
    freight_value           NUMERIC(10,2)   NOT NULL,
    gross_revenue           NUMERIC(10,2)   GENERATED ALWAYS AS (item_price + freight_value) STORED,

    -- Order-level measures (prorated to item level where multi-item orders exist)
    payment_value           NUMERIC(10,2),                    -- total order payment prorated per item
    payment_installments    SMALLINT,                         -- payment installments on the order
    payment_type            VARCHAR(30),                      -- 'credit_card', 'boleto', etc.

    -- Review measures (order-level, repeated across items of the same order)
    review_score            SMALLINT,                         -- 1–5 stars, NULL if no review

    -- Delivery performance measures (in days, computed at load time)
    days_to_deliver         INT,                              -- delivered_date - purchase_date
    days_delivery_delta     INT                               -- delivered_date - estimated_date (negative = early)
);

-- -----------------------------------------------------------------------------
-- INDEXES — support common analytical query patterns
-- -----------------------------------------------------------------------------
CREATE INDEX idx_fact_orders_customer    ON fact_orders(customer_key);
CREATE INDEX idx_fact_orders_seller      ON fact_orders(seller_key);
CREATE INDEX idx_fact_orders_product     ON fact_orders(product_key);
CREATE INDEX idx_fact_orders_purchase_dt ON fact_orders(purchase_time_key);
CREATE INDEX idx_fact_orders_status      ON fact_orders(order_status);
CREATE INDEX idx_fact_orders_order_id    ON fact_orders(order_id);
