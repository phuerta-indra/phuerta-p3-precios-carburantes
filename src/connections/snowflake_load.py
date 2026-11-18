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

    #-------------------------------------------------------------
    # Parámetros para la conexión con Snowflake
    #-------------------------------------------------------------

    load_dotenv(BASE_DIR / '.env')

    CONNEXION_PARAMS = {
            'user' : os.environ['SNOWFLAKE_USER'],
            'password' : os.environ['SNOWFLAKE_PASSWORD'],
            'account' : os.environ['SNOWFLAKE_ACCOUNT'],
            'role' : os.environ['SNOWFLAKE_ROLE'],
            'warehouse' : os.environ['SNOWFLAKE_WAREHOUSE'],
            'database' : os.environ['SNOWFLAKE_DATABASE'],
            'schema' : os.environ['SNOWFLAKE_SCHEMA']
        }

    try:
        conn = snowflake.connector.connect(**CONNEXION_PARAMS)
        print('Se ha conectado a Snowflake')
        return conn

    except snowflake.connector.errors.Error as e:
        print(f'No se puedo conectar a Snowflake: {e}')
        return None

