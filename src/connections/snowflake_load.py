import snowflake.connector
import os
from dotenv import load_dotenv
from src.connections.api_connect import download_data
from src.utils.config import get_base_dir


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
    







if __name__ == '__main__':
    conn = connect()
    create_table(conn)

