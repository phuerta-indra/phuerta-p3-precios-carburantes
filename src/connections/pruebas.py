from src.connections.api_connect import download_data

if __name__ == '__main__':
    data = download_data()

    for key in data.keys():
        print(key)

    print(data['ResultadoConsulta'])