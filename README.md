# Análisis de Carburantes en España

## Índice

- [Análisis de Carburantes en España](#análisis-de-carburantes-en-españa)
  - [Índice](#índice)
  - [Introducción](#introducción)
  - [Estructura del proyecto](#estructura-del-proyecto)
  - [Ejecución del proyecto](#ejecución-del-proyecto)
  - [Obtención de datos](#obtención-de-datos)
    - [Fuente de datos](#fuente-de-datos)
    - [Solución de problemas iniciales](#solución-de-problemas-iniciales)
    - [Conexión a la API](#conexión-a-la-api)
    - [Conexión a Snowflake](#conexión-a-snowflake)
    - [Ejecución](#ejecución)
    - [Automatización con Github Actions](#automatización-con-github-actions)
  - [Modelado de datos](#modelado-de-datos)

## Introducción

Este proyecto desarrolla un flujo de trabajo para estudiar las variaciones en los precios de los carburantes de las gasolineras españolas. El objetivo es focalizarse en una ingesta, limpieza y análisis casi a tiempo real (cada 3 horas).


## Estructura del proyecto

```bash
carburantes/
├── .github/
│   └── workflows/
│       └── github-actions-carburantes.yml  # Fichero yml para automatizar la ingesta
├── img/                      # Imágenes para el readme
├── powerbi/                  # Dashboard negocio
├── src/
│   ├── connections/          # Scripts para conexiones
│   │   ├── api_connect.py    # Conexión a la API del ministerio
│   │   ├── snowflake_load.py # Conexión y carga raw a Snowflake
│   │   ├── ingest.py         # Función para ejecutar todas las conexiones
│   ├── utils/                # Funciones auxiliares
│   └── main.py               # Fichero para automatizar
├── sql/
│   ├── setup/                # Queries de preparación
│   ├── silver/               # Preparación de datos capa silver
│   ├── gold/                 # Tablas de hechos y dimensiones capa gold
│   └── tasks/                # Actualización de silver y gold con nuevas ingestas
├── .env_example.txt          # Fichero de ejemplo para credenciales
└── requirements.txt          # Fichero de dependencias
```

Para ejecutar las conexiones mediante `main.py` es necesario tener instaladas las dependencias. Para eso, ejecutar este comando en su entorno virtual:

```bash
pip install -r requirements.txt
```

## Ejecución del proyecto

En este proyecto no es necesario realizar una ejecución manual para ver los resultados, gracias a que se ha automatizado toda la pipeline.

## Obtención de datos

### Fuente de datos

Los datos se obtienen a traves de la conexión a la [API REST](https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/) que proporciona el Ministerio de Transportes, sobre los precios que ofrecen todas las gasolineras españolas.

### [Solución de problemas iniciales](src/connections/api_connect.py)

Al tratar de conectarme a la API obtenía un error de conexión SSL. Para solucionarlo, hubo que modificar la configuración de la conexión para que fuese menos restrictiva.

### [Conexión a la API](src/connections/api_connect.py)

En el fichero `api_connect.py` se conecta a la API mediante el módulo de python `request` que lanza una petición para descargar los datos en formato `.json`.

### [Conexión a Snowflake](src/connections/snowflake_load.py)

Para conectarse a Snowflake es necesario crear un fichero `.env` con la estructura de `.env_example.txt` rellenándolo con las credenciales personales de Snowflake.

Con esto listo, generamos una conexión con Snowflake mediante la función `connect()`. Con la función `create_table()` crearemos una tabla donde se almacenarán los datos en bruto (RAW). Finalmente con las funciones: `insert_data()` y `register()` inseramos en la tabla que se creó anteriormente los datos que obtuvimos a través de la API.

### Ejecución

Para simplificar el flujo de trabajo, he creado la función [`ingest()`](src/connections/ingest.py) que ejecuta todos los pasos anteriores.
Esta función es llamada en el `main.py` para iniciar el flujo de la pipeline. Esto ayuda en la posterior automatización para ejecutar el script.

### Automatización con Github Actions

Para conseguir que la ingesta sea periódica cada 3 horas y no tener que estar pendientes de la ejecución del script, he creado un flujo en Github Actions.

Es importante que para que el flujo completo funcione correctamente, crear en Github unos secrets con las variables del fichero `.env`.

El flujo se puede consultar el el fichero .yml siguente: [`github-actions-carburantes.yml`](.github/workflows/github-actions-carburantes.yml). En el se definien los siguientes pasos que la VM de Github tiene que seguir para ejecutar la pipeline:

1) Clonar el repo
2) Instalar Python: 3.14.10
3) Instalar las dependencias a través del `requirements.txt`
4) Ejecutar la ingesta usando: los secrets previamente creados en Github y el `main.py`

## Modelado de datos

