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


