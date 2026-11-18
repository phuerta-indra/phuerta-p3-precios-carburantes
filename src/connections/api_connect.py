import ssl
import requests
from requests.adapters import HTTPAdapter


#-------------------------------------------------------------
# URL API REST Ministerio
#-------------------------------------------------------------


URL = (
    "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/"
    "PreciosCarburantes/EstacionesTerrestres/"
)


#-------------------------------------------------------------
# Para solucionar el error SSL de conexión
#-------------------------------------------------------------


class AdapterTLS(HTTPAdapter):
    def init_poolmanager(self, *args, **kwargs):
        contexto = ssl.create_default_context()
        contexto.set_ciphers("DEFAULT@SECLEVEL=1")
        contexto.options |= ssl.OP_LEGACY_SERVER_CONNECT
        kwargs["ssl_context"] = contexto
        return super().init_poolmanager(*args, **kwargs)


#-------------------------------------------------------------
# Petición a la API
#-------------------------------------------------------------


def download_data():

    session = requests.Session()
    session.mount("https://", AdapterTLS())

    response = session.get(URL, timeout=60)

    response.raise_for_status()

    return response.json()


if __name__ == '__main__':
    data = download_data()
    petrol_stations = data['ListaEESSPrecio']
    print('Número de estaciones:', len(petrol_stations))
    print('Claves de una estación:')
    for key in petrol_stations[0].keys():
        print('  -', key)
    print('-------------------------------------')
    print(data)