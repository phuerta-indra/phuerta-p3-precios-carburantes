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

