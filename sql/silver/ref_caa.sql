-- TABLA SOLO PARA CAPA SILVER
-- Genera una tabla con la equivalencia de los ids de cada comunidad autónoma
-- En capa gold se hará un JOIN con dim_station para unificar información

CREATE OR REPLACE TABLE ref_ccaa (
    id_ccaa STRING NOT NULL,
    ccaa    STRING NOT NULL
) AS
SELECT * FROM VALUES
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
    ('19', 'Melilla');