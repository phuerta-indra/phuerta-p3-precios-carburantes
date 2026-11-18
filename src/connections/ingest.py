from src.connections.api_connect import download_data
from src.connections.snowflake_load import connect, create_table, insert_data


#-------------------------------------------------------------
# Función que ejecuta el flujo de ingesta
#-------------------------------------------------------------


def auto_ingest():
    data = download_data()
    conn = connect()
    create_table(conn)
    insert_data(conn, data)