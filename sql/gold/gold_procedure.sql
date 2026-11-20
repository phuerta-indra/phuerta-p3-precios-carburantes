CREATE OR REPLACE PROCEDURE CARBURANTES_DB.GOLD.SP_REFRESH_GOLD()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN

  -- Calendario desde la primera fecha de SILVER hasta hoy
  -- o hasta la última fecha de SILVER, la que sea posterior.
  CREATE OR REPLACE TABLE CARBURANTES_DB.GOLD.DIM_DATE AS
  WITH fact_dates AS (
    SELECT
      CONVERT_TIMEZONE(
        'UTC',
        'Europe/Madrid',
        ingestion_ts
      )::DATE AS calendar_date
    FROM CARBURANTES_DB.SILVER.FCT_PRICE_SNAPSHOT
  ),
  bounds AS (
    SELECT
      COALESCE(MIN(calendar_date), CURRENT_DATE()) AS start_date,
      GREATEST(
        CURRENT_DATE(),
        COALESCE(MAX(calendar_date), CURRENT_DATE())
      ) AS end_date
    FROM fact_dates
  ),
  offsets AS (
    SELECT
      ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS day_offset
    FROM TABLE(GENERATOR(ROWCOUNT => 20000))
  ),
  dates AS (
    SELECT DATEADD(DAY, o.day_offset, b.start_date)::DATE AS d
    FROM offsets AS o
    CROSS JOIN bounds AS b
    WHERE DATEADD(DAY, o.day_offset, b.start_date) <= b.end_date
  )
  SELECT
    d AS PK_DATE,
    YEAR(d) AS YEAR,
    QUARTER(d) AS QUARTER,
    MONTH(d) AS MONTH,
    DECODE(
      MONTH(d),
      1, 'Enero',
      2, 'Febrero',
      3, 'Marzo',
      4, 'Abril',
      5, 'Mayo',
      6, 'Junio',
      7, 'Julio',
      8, 'Agosto',
      9, 'Septiembre',
      10, 'Octubre',
      11, 'Noviembre',
      12, 'Diciembre'
    ) AS MONTH_NAME,
    DAY(d) AS DAY,
    WEEKISO(d) AS ISO_WEEK,
    DAYOFWEEKISO(d) AS DAY_OF_WEEK,
    DECODE(
      DAYOFWEEKISO(d),
      1, 'Lunes',
      2, 'Martes',
      3, 'Miércoles',
      4, 'Jueves',
      5, 'Viernes',
      6, 'Sábado',
      7, 'Domingo'
    ) AS DAY_NAME,
    DAYOFWEEKISO(d) >= 6 AS IS_WEEKEND
  FROM dates;


  -- Dimensión de productos.
  CREATE OR REPLACE TABLE CARBURANTES_DB.GOLD.DIM_PRODUCT AS
  SELECT
    pk_product,
    product_name,
    fuel_type
  FROM CARBURANTES_DB.SILVER.DIM_PRODUCT;


  -- Dimensión de estaciones con el nombre de la comunidad autónoma.
  CREATE OR REPLACE TABLE CARBURANTES_DB.GOLD.DIM_STATION AS
  SELECT
    s.ideess AS pk_station,
    s.rotulo,
    s.marca,
    s.direccion,
    s.municipio,
    s.provincia,
    s.id_ccaa,
    r.ccaa,
    s.latitud,
    s.longitud
  FROM CARBURANTES_DB.SILVER.DIM_STATION AS s
  LEFT JOIN CARBURANTES_DB.SILVER.REF_CCAA AS r
    ON r.id_ccaa = s.id_ccaa;


  -- Hechos con las claves de las dimensiones GOLD.
  CREATE OR REPLACE TABLE CARBURANTES_DB.GOLD.FACT_FUEL_PRICE AS
  SELECT
    f.ingestion_ts,
    CONVERT_TIMEZONE(
      'UTC',
      'Europe/Madrid',
      f.ingestion_ts
    ) AS ingestion_ts_madrid,
    d.pk_date AS fk_date,
    s.pk_station AS fk_station,
    p.pk_product AS fk_product,
    f.price_eur_l
  FROM CARBURANTES_DB.SILVER.FCT_PRICE_SNAPSHOT AS f
  LEFT JOIN CARBURANTES_DB.GOLD.DIM_DATE AS d
    ON d.pk_date = CONVERT_TIMEZONE(
      'UTC',
      'Europe/Madrid',
      f.ingestion_ts
    )::DATE
  LEFT JOIN CARBURANTES_DB.GOLD.DIM_STATION AS s
    ON s.pk_station = f.ideess
  LEFT JOIN CARBURANTES_DB.GOLD.DIM_PRODUCT AS p
    ON p.product_name = f.product;

  RETURN 'GOLD actualizado correctamente';

EXCEPTION
  WHEN OTHER THEN
    RAISE;
END;
$$;



