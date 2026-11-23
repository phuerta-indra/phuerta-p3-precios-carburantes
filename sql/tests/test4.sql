-- 1) corregir intercambiadas
UPDATE CARBURANTES_DB.SILVER.DIM_STATION
SET latitud = longitud, longitud = latitud
WHERE longitud BETWEEN 27 AND 44 AND latitud BETWEEN -19 AND 5;

-- 2) anular lo inválido (ceros, pares a medias, fuera de rango)
UPDATE CARBURANTES_DB.SILVER.DIM_STATION
SET latitud = NULL, longitud = NULL
WHERE (latitud IS NOT NULL OR longitud IS NOT NULL)
  AND NOT COALESCE(latitud BETWEEN 27 AND 44 AND longitud BETWEEN -19 AND 5, FALSE);

SELECT COUNT(*) AS invalidas
FROM CARBURANTES_DB.SILVER.DIM_STATION
WHERE latitud = 0 OR longitud = 0
   OR (latitud IS NOT NULL
       AND NOT (latitud BETWEEN 27 AND 44 AND longitud BETWEEN -19 AND 5));

SELECT COUNT_IF(latitud IS NULL) AS sin_coordenadas, COUNT(*) AS total
FROM CARBURANTES_DB.SILVER.DIM_STATION;