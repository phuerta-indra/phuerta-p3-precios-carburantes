CREATE OR REPLACE TABLE GOLD.DIM_DATE AS
WITH DATES AS (
    SELECT DATEADD(DAY, SEQ4(), '2026-11-01'::DATE) AS D
    FROM TABLE(GENERATOR(ROWCOUNT => 790))
)
SELECT
    D                          AS PK_DATE,
    YEAR(D)                    AS YEAR,
    QUARTER(D)                 AS QUARTER,
    MONTH(D)                   AS MONTH,
    DECODE(MONTH(D), 1,'Enero',2,'Febrero',3,'Marzo',4,'Abril',5,'Mayo',6,'Junio',
                     7,'Julio',8,'Agosto',9,'Septiembre',10,'Octubre',11,'Noviembre',12,'Diciembre') AS MONTH_NAME,
    DAY(D)                     AS DAY,
    WEEKISO(D)                 AS ISO_WEEK,
    DAYOFWEEKISO(D)            AS DAY_OF_WEEK,
    DECODE(DAYOFWEEKISO(D), 1,'Lunes',2,'Martes',3,'Miércoles',4,'Jueves',5,'Viernes',6,'Sábado',7,'Domingo') AS DAY_NAME,
    DAYOFWEEKISO(D) >= 6       AS IS_WEEKEND
FROM DATES;