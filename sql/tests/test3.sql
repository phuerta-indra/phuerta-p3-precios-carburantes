SELECT * FROM GOLD.FACT_FUEL_PRICE
LEFT JOIN GOLD.DIM_STATION ON
PK_STATION = FK_STATION
WHERE LATITUD IS NULL OR LONGITUD IS NULL;

SELECT ideess, latitud, longitud FROM silver.dim_station
WHERE latitud = 0 OR longitud = 0;



-- Coordenadas inválidas o incompletas -> NULL en ambas a la vez
UPDATE CARBURANTES_DB.GOLD.DIM_STATION
SET latitud = NULL,
    longitud = NULL
WHERE latitud  IS NULL OR longitud IS NULL
   OR latitud  NOT BETWEEN 27 AND 44
   OR longitud NOT BETWEEN -19 AND 5;

SHOW TASKS IN SCHEMA CARBURANTES_DB.SILVER;

SELECT name, state, scheduled_time, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
  SCHEDULED_TIME_RANGE_START => DATEADD('hour', -6, CURRENT_TIMESTAMP()),
  RESULT_LIMIT => 20))
ORDER BY scheduled_time DESC;

WITH ultima AS (
    SELECT MAX(ingestion_ts) AS ingestion_ts
    FROM GOLD.FACT_FUEL_PRICE
)
SELECT
    MAX(f.price_eur_l) AS precio_maximo,
    COUNT(*) AS filas_en_ultima_ingesta
FROM GOLD.FACT_FUEL_PRICE f
JOIN ultima u
    ON f.ingestion_ts = u.ingestion_ts;

SELECT DISTINCT INGESTION_TS FROM GOLD.FACT_FUEL_PRICE
ORDER BY ingestion_ts DESC;


WITH ingestas AS (
    SELECT DISTINCT ingestion_ts
    FROM fact_fuel_price
    WHERE ingestion_ts <= '2026-11-24 07:01:03'::TIMESTAMP_NTZ
),
ultima_y_anterior AS (
    SELECT ingestion_ts
    FROM ingestas
    QUALIFY ROW_NUMBER() OVER (ORDER BY ingestion_ts DESC) <= 2
),
precios AS (
    SELECT
        fk_product,
        ingestion_ts,
        AVG(price_eur_l) AS precio_medio
    FROM fact_fuel_price
    WHERE ingestion_ts IN (SELECT ingestion_ts FROM ultima_y_anterior)
    GROUP BY fk_product, ingestion_ts
)
SELECT
    actual.fk_product,
    actual.ingestion_ts AS ultima_ingesta,
    anterior.ingestion_ts AS ingesta_anterior,
    actual.precio_medio AS precio_medio_actual,
    anterior.precio_medio AS precio_medio_anterior,
    actual.precio_medio - anterior.precio_medio AS diferencia
FROM precios actual
JOIN precios anterior
    ON actual.fk_product = anterior.fk_product
WHERE actual.ingestion_ts = '2026-11-24 07:01:03'::TIMESTAMP_NTZ
  AND anterior.ingestion_ts < actual.ingestion_ts
  AND anterior.ingestion_ts = (
      SELECT MAX(ingestion_ts)
      FROM ultima_y_anterior
      WHERE ingestion_ts < '2026-11-24 07:01:03'::TIMESTAMP_NTZ
  )
ORDER BY actual.fk_product;