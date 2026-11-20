-- Tabla de hechos para la capa silver, en capa gold se actualizará para añadir las claves hacia las dimensiones
-- En este punto, la tabla se embebe directamente del json

CREATE TABLE IF NOT EXISTS silver.fct_price_snapshot (
    ingestion_ts TIMESTAMP_NTZ NOT NULL,
    ideess       VARCHAR       NOT NULL,
    product      VARCHAR       NOT NULL,
    price_eur_l  NUMBER(6,3)   NOT NULL
);


-- Carga incremental: solo snapshots RAW que aún no están en SILVER


INSERT INTO silver.fct_price_snapshot
WITH new_raw AS (
    SELECT ingestion_ts, payload
    FROM raw.fuel_prices_json
    WHERE ingestion_ts > (
        SELECT COALESCE(MAX(ingestion_ts), '1900-01-01'::TIMESTAMP_NTZ)
        FROM silver.fct_price_snapshot
    )
),
exploded AS (
    SELECT
        r.ingestion_ts,
        s.value:"IDEESS"::VARCHAR AS ideess,
        p.product_name            AS product,
        TRY_TO_NUMBER(
            REPLACE(NULLIF(TRIM(s.value[p.json_key]::VARCHAR), ''), ',', '.'),
            6, 3
        )                         AS price_eur_l
    FROM new_raw r
    CROSS JOIN silver.dim_product p
    CROSS JOIN LATERAL FLATTEN(input => r.payload:"ListaEESSPrecio") s
)
SELECT ingestion_ts, ideess, product, price_eur_l
FROM exploded
WHERE price_eur_l IS NOT NULL      -- AdBlue (u otro) no informado => no se inserta
  AND price_eur_l > 0
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY ideess, product, ingestion_ts ORDER BY price_eur_l
) = 1;                             -- garantiza unicidad

