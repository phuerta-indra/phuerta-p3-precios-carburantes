import snowflake.connector
import os
import json
from dotenv import load_dotenv
from datetime import datetime, timezone
from src.utils.config import get_base_dir, get_records_book_dir


#-------------------------------------------------------------
# Función que conecta con Snowflake
#-------------------------------------------------------------


def connect():

    BASE_DIR = get_base_dir()

    # Parámetros para la conexión con Snowflake

    load_dotenv(BASE_DIR / '.env')

    CONNEXION_PARAMS = {
            'user' : os.environ['SNOWFLAKE_USER'],
            'password' : os.environ['SNOWFLAKE_PASSWORD'],
            'account' : os.environ['SNOWFLAKE_ACCOUNT'],
            'role' : os.environ['SNOWFLAKE_ROLE'],
            'warehouse' : os.environ['SNOWFLAKE_WAREHOUSE'],
            'database' : os.environ['SNOWFLAKE_DATABASE'],
            'schema' : os.environ['SNOWFLAKE_SCHEMA'],
            'enable_server_session_keep_alive_auto_detection': True,
            'paramstyle' : "qmark",
        }

    try:
        conn = snowflake.connector.connect(**CONNEXION_PARAMS)
        print('Se ha conectado a Snowflake')
        return conn

    except snowflake.connector.errors.Error as e:
        print(f'No se puedo conectar a Snowflake: {e}')
        return None


#-------------------------------------------------------------
# Función para crear la tabla inicial
#-------------------------------------------------------------


def create_table(conn):

    'Función para crear la tabla, sirve para la primera ejecución'

    # Obtenemos las variables de ruta de Snowflake
    db = os.environ['SNOWFLAKE_DATABASE']
    schema = os.environ['SNOWFLAKE_SCHEMA']

    # Definimos el nombre de la tabla por defecto
    table = 'FUEL_PRICES_JSON'

    with conn.cursor() as cur:

        # Creamos el Schema si no existe

        cur.execute(f'SHOW SCHEMAS IN DATABASE "{db}"')

        schema_exists = any(
            row[1].upper() == schema.upper() for row in cur.fetchall() # Busca si hay coincidencias con el esquema que queremos crear
            )

        cur.execute(f'CREATE SCHEMA IF NOT EXISTS "{db}"."{schema}"') # Si no existe nos crea el esquema
        print(f"Esquema {schema}: " + ("ya existía" if schema_exists else "creado")) # Aviso de si lo ha creado o ya existía


        # Creamos la tabla si no existe

        cur.execute(f'SHOW TABLES IN SCHEMA "{db}"."{schema}"')

        table_exists = any(
            row[1].upper() == table.upper() for row in cur.fetchall() # Busca si hay coincidencias con la tabla que queremos crear
            )

        # Crea la tabla si no existe

        cur.execute(f"""
            CREATE TABLE IF NOT EXISTS "{db}"."{schema}"."{table}" (
                INGESTION_TS TIMESTAMP_NTZ,
                PAYLOAD VARIANT
                )
            """)
        
        print(f"Tabla {table}: " + ("ya existía" if table_exists else "creada")) # Aviso de lo que ha hecho

    return
    

#-------------------------------------------------------------
# Función para insertar los datos en la tabla
#-------------------------------------------------------------


def insert_data(conn, data):

    schema = os.environ['SNOWFLAKE_SCHEMA']

    ingestion_ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    payload = json.dumps(data, ensure_ascii=False)

    print(f"Tamaño del payload: {len(payload.encode('utf-8')) / 1e6:.1f} MB")

    query = f"""INSERT INTO {schema}.FUEL_PRICES_JSON (ingestion_ts, payload)
                SELECT TO_TIMESTAMP_NTZ(?), PARSE_JSON(?)
                """

    with conn.cursor() as cur:
        try:
            cur.execute(query, (ingestion_ts, payload))
            new_rows = cur.rowcount # Número de nuevos registros

            register(cur, ingestion_ts, new_rows, len(data["ListaEESSPrecio"]), 'OK')

        except Exception:
            register(cur, ingestion_ts, new_rows, len(data["ListaEESSPrecio"]), 'ERROR')
            raise
    
    return ingestion_ts


#-------------------------------------------------------------
# Función para registrar cada nueva entrada en una nueva tabla
#-------------------------------------------------------------


def register(cur, ts, new_rows, stations, status):

    schema = os.environ['SNOWFLAKE_SCHEMA']


    logged_at = datetime.now(timezone.utc).replace(tzinfo=None)
    
    cur.execute(
        f"INSERT INTO {schema}.INGESTION_LOG (ingestion_ts, new_rows, n_stations, status, logged_at) "
        "VALUES (?, ?, ?, ?, ?)",
        (ts, new_rows, stations, status, logged_at),
    )

    return print("Registrado correctamente!")



