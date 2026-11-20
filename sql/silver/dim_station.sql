-- CAPA SILVER: Creación de la dimensión de las estaciones de servicio
-- Cada fila representa una estación de servicio identificada por IDEESS.
-- La dimensión recoge las estaciones presentes en la fuente del Ministerio, unas 11.000 gasolineras


CREATE OR REPLACE TABLE SILVER.DIM_STATION AS
SELECT
    f.value:"IDEESS"::STRING                          AS ideess,
    NULLIF(TRIM(f.value:"Rótulo"::STRING), '')        AS rotulo,
    NULLIF(TRIM(f.value:"Dirección"::STRING), '')     AS direccion,
    NULLIF(TRIM(f.value:"Municipio"::STRING), '')     AS municipio,
    NULLIF(TRIM(f.value:"Provincia"::STRING), '')     AS provincia,
    f.value:"IDCCAA"::STRING                          AS id_ccaa,
    TRY_TO_DECIMAL(REPLACE(NULLIF(f.value:"Latitud"::STRING, ''), ',', '.'), 10, 6)          AS latitud,
    TRY_TO_DECIMAL(REPLACE(NULLIF(f.value:"Longitud (WGS84)"::STRING, ''), ',', '.'), 10, 6) AS longitud
FROM raw.fuel_prices_json r,
     LATERAL FLATTEN(input => r.payload:ListaEESSPrecio) f
WHERE f.value:"IDEESS" IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
            PARTITION BY f.value:"IDEESS"::STRING
            ORDER BY r.ingestion_ts DESC
        ) = 1;


-- Se convierte el ID de cada estación como un pk de la dimensión

ALTER TABLE SILVER.DIM_STATION
ADD PRIMARY KEY (ideess);


-- Como los nombres de las estaciones no está unificado (ej. BP TORRENTE, BP MECO ambas son BP) las normalizamos en     una nueva columna llamada marca.

ALTER TABLE silver.dim_station ADD COLUMN marca STRING;

UPDATE silver.dim_station
SET marca = CASE
    WHEN rotulo ILIKE '%REPSOL%'   THEN 'REPSOL'
    WHEN rotulo ILIKE '%CAMPSA%'   THEN 'CAMPSA'
    WHEN rotulo ILIKE '%PETRONOR%' THEN 'PETRONOR'
    WHEN rotulo ILIKE '%CEPSA%' OR rotulo ILIKE '%MOEVE%'
      OR rotulo ILIKE '%MOOVE%' OR rotulo ILIKE '%MOEWE%' THEN 'MOEVE (CEPSA)'
    WHEN REGEXP_LIKE(rotulo, $$.*(^|[^A-Za-z])B\.?P\.?([^A-Za-z]|$).*$$, 'i') THEN 'BP'
    WHEN rotulo ILIKE '%SHELL%'       THEN 'SHELL'
    WHEN rotulo ILIKE '%GALP%'        THEN 'GALP'
    WHEN rotulo ILIKE '%DISA%'        THEN 'DISA'
    WHEN rotulo ILIKE '%PETROPRIX%' OR rotulo ILIKE '%PERTROPRIX%' THEN 'PETROPRIX'
    WHEN rotulo ILIKE '%BALLENOIL%'   THEN 'BALLENOIL'
    WHEN rotulo ILIKE '%PLENERGY%'    THEN 'PLENERGY'
    WHEN rotulo ILIKE '%AVIA%'        THEN 'AVIA'
    WHEN rotulo ILIKE '%Q8%'          THEN 'Q8'
    WHEN rotulo ILIKE '%ALCAMPO%'     THEN 'ALCAMPO'
    WHEN rotulo ILIKE '%CARREFOUR%' OR rotulo ILIKE '%CARRREFOUR%' THEN 'CARREFOUR'
    WHEN rotulo ILIKE '%LECLERC%'     THEN 'E.LECLERC'
    WHEN rotulo ILIKE '%NATURGY%'     THEN 'NATURGY'
    WHEN rotulo ILIKE '%AN ENERGETICOS%' OR rotulo ILIKE '%AN ENERGÉTICOS%' THEN 'AN ENERGÉTICOS'
    WHEN rotulo IS NULL
      OR rotulo ILIKE ANY ('%SIN ROTULO%', '%SIN RÓTULO%', 'NINGUNO', 'NO TIENE', 'NO ROTULO',
                           'SIN DETERMINAR', 'SIN ASIGNAR', 'NO HAY', 'LIBRE', '-')
                                             THEN 'SIN RÓTULO'
    ELSE 'OTRAS'
END;


