-- CAPA SILVER: Creación de la dimensión de los productos
-- Cada fila representa los tres productos que se van a analizar.
-- Se le añade la clave del diccionario del json original y una clasificación en función del tipo de fuel

CREATE OR REPLACE TABLE SILVER.DIM_PRODUCT AS
SELECT * FROM VALUES
    (1, 'Gasóleo A',    'Precio Gasoleo A',         'Combustible'),
    (2, 'Gasolina 95',  'Precio Gasolina 95 E5',    'Combustible'),
    (3, 'AdBlue',       'Precio Adblue',            'Aditivo')
AS t(pk_product, product_name, json_key, fuel_type);

-- Se convierte a pk

ALTER TABLE SILVER.DIM_PRODUCT
ADD CONSTRAINT PK_DIM_PRODUCT PRIMARY KEY (pk_product);



