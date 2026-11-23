CREATE STREAM IF NOT EXISTS CARBURANTES_DB.RAW.FUEL_STREAM
  ON TABLE CARBURANTES_DB.RAW.FUEL_PRICES_JSON
  APPEND_ONLY = TRUE;


CREATE OR REPLACE PROCEDURE CARBURANTES_DB.SILVER.SP_REFRESH_SILVER()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN

  -- Crear las tablas destino si todavía no existen.
  CREATE TABLE IF NOT EXISTS CARBURANTES_DB.SILVER.DIM_PRODUCT (
    pk_product   NUMBER(1,0),
    product_name VARCHAR,
    json_key     VARCHAR,
    fuel_type    VARCHAR
  );

  CREATE TABLE IF NOT EXISTS CARBURANTES_DB.SILVER.DIM_STATION (
    ideess     VARCHAR,
    rotulo     VARCHAR,
    direccion  VARCHAR,
    municipio  VARCHAR,
    provincia  VARCHAR,
    id_ccaa    VARCHAR,
    latitud    NUMBER(10,6),
    longitud   NUMBER(10,6),
    marca      VARCHAR
  );

  CREATE TABLE IF NOT EXISTS CARBURANTES_DB.SILVER.REF_CCAA (
    id_ccaa VARCHAR,
    ccaa    VARCHAR
  );

  CREATE TABLE IF NOT EXISTS CARBURANTES_DB.SILVER.FCT_PRICE_SNAPSHOT (
    ingestion_ts TIMESTAMP_NTZ NOT NULL,
    ideess       VARCHAR       NOT NULL,
    product      VARCHAR       NOT NULL,
    price_eur_l  NUMBER(6,3)   NOT NULL
  );

  -- Tabla temporal disponible solo durante esta ejecución.
  CREATE OR REPLACE PROCEDURE SCOPED TEMP TABLE STREAM_BATCH (
    ingestion_ts TIMESTAMP_NTZ,
    payload      VARIANT
  );

  BEGIN TRANSACTION;

  -- Mantener la dimensión de productos.
  MERGE INTO CARBURANTES_DB.SILVER.DIM_PRODUCT AS target
  USING (
    SELECT column1 AS pk_product,
           column2 AS product_name,
           column3 AS json_key,
           column4 AS fuel_type
    FROM VALUES
      (1, 'Gasóleo A',   'Precio Gasoleo A',      'Combustible'),
      (2, 'Gasolina 95', 'Precio Gasolina 95 E5', 'Combustible'),
      (3, 'AdBlue',      'Precio Adblue',          'Aditivo')
  ) AS source
    ON target.pk_product = source.pk_product
  WHEN MATCHED THEN UPDATE SET
    product_name = source.product_name,
    json_key     = source.json_key,
    fuel_type    = source.fuel_type
  WHEN NOT MATCHED THEN INSERT
    (pk_product, product_name, json_key, fuel_type)
  VALUES
    (source.pk_product, source.product_name, source.json_key, source.fuel_type);

  -- Mantener la tabla de equivalencias de comunidades autónomas.
  MERGE INTO CARBURANTES_DB.SILVER.REF_CCAA AS target
  USING (
    SELECT column1 AS id_ccaa, column2 AS ccaa
    FROM VALUES
      ('01', 'Andalucía'),
      ('02', 'Aragón'),
      ('03', 'Asturias'),
      ('04', 'Illes Balears'),
      ('05', 'Canarias'),
      ('06', 'Cantabria'),
      ('07', 'Castilla-La Mancha'),
      ('08', 'Castilla y León'),
      ('09', 'Cataluña'),
      ('10', 'Comunitat Valenciana'),
      ('11', 'Extremadura'),
      ('12', 'Galicia'),
      ('13', 'Comunidad de Madrid'),
      ('14', 'Región de Murcia'),
      ('15', 'Navarra'),
      ('16', 'País Vasco'),
      ('17', 'La Rioja'),
      ('18', 'Ceuta'),
      ('19', 'Melilla')
  ) AS source
    ON target.id_ccaa = source.id_ccaa
  WHEN MATCHED THEN UPDATE SET
    ccaa = source.ccaa
  WHEN NOT MATCHED THEN INSERT (id_ccaa, ccaa)
  VALUES (source.id_ccaa, source.ccaa);

  -- Copiar a la tabla temporal el lote nuevo de RAW.
  -- La stream se consume al confirmar la transacción.
  INSERT INTO STREAM_BATCH (ingestion_ts, payload)
  SELECT ingestion_ts, payload
  FROM CARBURANTES_DB.RAW.FUEL_STREAM;

  -- Actualizar solo las estaciones presentes en el lote nuevo.
  MERGE INTO CARBURANTES_DB.SILVER.DIM_STATION AS target
  USING (
    WITH station_rows AS (
      SELECT
        b.ingestion_ts,
        f.value:"IDEESS"::VARCHAR AS ideess,
        NULLIF(TRIM(f.value:"Rótulo"::VARCHAR), '') AS rotulo,
        NULLIF(TRIM(f.value:"Dirección"::VARCHAR), '') AS direccion,
        NULLIF(TRIM(f.value:"Municipio"::VARCHAR), '') AS municipio,
        NULLIF(TRIM(f.value:"Provincia"::VARCHAR), '') AS provincia,
        f.value:"IDCCAA"::VARCHAR AS id_ccaa,
        TRY_TO_DECIMAL(
          REPLACE(NULLIF(f.value:"Latitud"::VARCHAR, ''), ',', '.'),
          10, 6
        ) AS lat_raw,
        TRY_TO_DECIMAL(
          REPLACE(NULLIF(f.value:"Longitud (WGS84)"::VARCHAR, ''), ',', '.'),
          10, 6
        ) AS lon_raw
      FROM STREAM_BATCH AS b,
           LATERAL FLATTEN(
             INPUT => b.payload:"ListaEESSPrecio"
           ) AS f
      WHERE f.value:"IDEESS" IS NOT NULL
      QUALIFY ROW_NUMBER() OVER (
        PARTITION BY f.value:"IDEESS"::VARCHAR
        ORDER BY b.ingestion_ts DESC
      ) = 1
    ),
    -- Gestión de coordenadas (rango válido: España incl. Canarias).
    --  · correctas  -> se mantienen
    --  · intercambiadas (lat <-> lon) -> se corrigen
    --  · ceros, nulos o fuera de rango -> NULL en ambas a la vez
    geo_clean AS (
      SELECT
        sr.*,
        CASE
          WHEN lat_raw BETWEEN 27 AND 44 AND lon_raw BETWEEN -19 AND 5 THEN lat_raw
          WHEN lon_raw BETWEEN 27 AND 44 AND lat_raw BETWEEN -19 AND 5 THEN lon_raw
        END AS latitud,
        CASE
          WHEN lat_raw BETWEEN 27 AND 44 AND lon_raw BETWEEN -19 AND 5 THEN lon_raw
          WHEN lon_raw BETWEEN 27 AND 44 AND lat_raw BETWEEN -19 AND 5 THEN lat_raw
        END AS longitud
      FROM station_rows AS sr
    )
    SELECT
      ideess,
      rotulo,
      direccion,
      municipio,
      provincia,
      id_ccaa,
      latitud,
      longitud,
      CASE
        WHEN rotulo ILIKE '%REPSOL%' THEN 'REPSOL'
        WHEN rotulo ILIKE '%CAMPSA%' THEN 'CAMPSA'
        WHEN rotulo ILIKE '%PETRONOR%' THEN 'PETRONOR'
        WHEN rotulo ILIKE '%CEPSA%'
          OR rotulo ILIKE '%MOEVE%'
          OR rotulo ILIKE '%MOOVE%'
          OR rotulo ILIKE '%MOEWE%' THEN 'MOEVE (CEPSA)'
        WHEN REGEXP_LIKE(
          rotulo,
          '.*(^|[^A-Za-z])B[.]?P[.]?([^A-Za-z]|$).*',
          'i'
        ) THEN 'BP'
        WHEN rotulo ILIKE '%SHELL%' THEN 'SHELL'
        WHEN rotulo ILIKE '%GALP%' THEN 'GALP'
        WHEN rotulo ILIKE '%DISA%' THEN 'DISA'
        WHEN rotulo ILIKE '%PETROPRIX%'
          OR rotulo ILIKE '%PERTROPRIX%' THEN 'PETROPRIX'
        WHEN rotulo ILIKE '%BALLENOIL%' THEN 'BALLENOIL'
        WHEN rotulo ILIKE '%PLENERGY%' THEN 'PLENERGY'
        WHEN rotulo ILIKE '%AVIA%' THEN 'AVIA'
        WHEN rotulo ILIKE '%Q8%' THEN 'Q8'
        WHEN rotulo ILIKE '%ALCAMPO%' THEN 'ALCAMPO'
        WHEN rotulo ILIKE '%CARREFOUR%'
          OR rotulo ILIKE '%CARRREFOUR%' THEN 'CARREFOUR'
        WHEN rotulo ILIKE '%LECLERC%' THEN 'E.LECLERC'
        WHEN rotulo ILIKE '%NATURGY%' THEN 'NATURGY'
        WHEN rotulo ILIKE '%AN ENERGETICOS%'
          OR rotulo ILIKE '%AN ENERGÉTICOS%' THEN 'AN ENERGÉTICOS'
        WHEN rotulo IS NULL
          OR rotulo ILIKE ANY (
            '%SIN ROTULO%',
            '%SIN RÓTULO%',
            'NINGUNO',
            'NO TIENE',
            'NO ROTULO',
            'SIN DETERMINAR',
            'SIN ASIGNAR',
            'NO HAY',
            'LIBRE',
            '-'
          ) THEN 'SIN RÓTULO'
        ELSE 'OTRAS'
      END AS marca
    FROM geo_clean
  ) AS source
    ON target.ideess = source.ideess
  WHEN MATCHED THEN UPDATE SET
    rotulo    = source.rotulo,
    direccion = source.direccion,
    municipio = source.municipio,
    provincia = source.provincia,
    id_ccaa   = source.id_ccaa,
    -- Si el lote trae coordenada inválida, se conserva la última válida.
    latitud   = COALESCE(source.latitud,  target.latitud),
    longitud  = COALESCE(source.longitud, target.longitud),
    marca     = source.marca
  WHEN NOT MATCHED THEN INSERT (
    ideess, rotulo, direccion, municipio, provincia,
    id_ccaa, latitud, longitud, marca
  )
  VALUES (
    source.ideess, source.rotulo, source.direccion, source.municipio,
    source.provincia, source.id_ccaa, source.latitud,
    source.longitud, source.marca
  );

  -- Convertir los precios del mismo lote y añadir solo los que no existan.
  INSERT INTO CARBURANTES_DB.SILVER.FCT_PRICE_SNAPSHOT
    (ingestion_ts, ideess, product, price_eur_l)
  WITH exploded AS (
    SELECT
      b.ingestion_ts,
      s.value:"IDEESS"::VARCHAR AS ideess,
      p.product_name AS product,
      TRY_TO_NUMBER(
        REPLACE(
          NULLIF(TRIM(s.value[p.json_key]::VARCHAR), ''),
          ',',
          '.'
        ),
        6,
        3
      ) AS price_eur_l
    FROM STREAM_BATCH AS b
    CROSS JOIN CARBURANTES_DB.SILVER.DIM_PRODUCT AS p
    CROSS JOIN LATERAL FLATTEN(
      INPUT => b.payload:"ListaEESSPrecio"
    ) AS s
  ),
  deduplicated AS (
    SELECT ingestion_ts, ideess, product, price_eur_l
    FROM exploded
    WHERE ideess IS NOT NULL
      AND price_eur_l IS NOT NULL
      AND price_eur_l > 0
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY ideess, product, ingestion_ts
      ORDER BY price_eur_l
    ) = 1
  )
  SELECT
    d.ingestion_ts,
    d.ideess,
    d.product,
    d.price_eur_l
  FROM deduplicated AS d
  WHERE NOT EXISTS (
    SELECT 1
    FROM CARBURANTES_DB.SILVER.FCT_PRICE_SNAPSHOT AS existing
    WHERE existing.ingestion_ts = d.ingestion_ts
      AND existing.ideess = d.ideess
      AND existing.product = d.product
  );

  COMMIT;

  RETURN 'SILVER actualizado correctamente';

EXCEPTION
  WHEN OTHER THEN
    ROLLBACK;
    RAISE;
END;
$$;