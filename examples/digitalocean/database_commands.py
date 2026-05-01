from pprint import pprint
import requests
from api_token import API_KEY


def create_DBs(name, total_clusters):
    """
    Creates Postgres 10 DB in NYC3 region with 1cpu and 10GB storage
    name is prefix for databse(s). Must be lowercase and not contain "_".   
    
    >>> create_DBs("test", 3)
    {"name": "test0", "engine": "pg", "version": "10", "region": "nyc3", "size": "db-s-1vcpu-1gb", "num_nodes": 1, "tags": ["Cognixia DB"]}
    DB successfully created.
    {"name": "test1", "engine": "pg", "version": "10", "region": "nyc3", "size": "db-s-1vcpu-1gb", "num_nodes": 1, "tags": ["Cognixia DB"]}
    DB successfully created.
    {"name": "test2", "engine": "pg", "version": "10", "region": "nyc3", "size": "db-s-1vcpu-1gb", "num_nodes": 1, "tags": ["Cognixia DB"]}
    DB successfully created.
    """


    for idx in range(total_clusters):

        headers = {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer {}'.format(API_KEY),
        }

        db_name = '"{}{}"'.format(name, idx)
        data = '{"name": ' + db_name + ', "engine": "pg", "version": "10", "region": "nyc3", "size": "db-s-1vcpu-1gb", "num_nodes": 1, "tags": ["Cognixia DB"]}'
        print(data)

        response = requests.post('https://api.digitalocean.com/v2/databases', headers=headers, data=data)
        
        # if '201' in response:
        #     print("DB successfully created.")
        # else:
        #     print("DB not created.")
        #     print(response)
        print("DB successfully created.") if '201' in str(response) else print("DB not created:", response)


def list_DBs():

    """
    Prints connection info and saves it to file.
    Easily modified to show other db info.
    """

    headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer {}'.format(API_KEY),
    }

    response = requests.get('https://api.digitalocean.com/v2/databases', headers=headers)

    # send connection info to file
    with open('ConnectionDetails.txt', 'w') as file:
        for idx, elem in enumerate(response.json()['databases']):
            # pprint(elem['connection'])
            file.write(str(elem['connection']))
            file.write("\n")

    return response.json()


def delete_all_DBs():

    list_all_DBs_response = list_DBs()

    for elem in list_all_DBs_response['databases']:

        headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer {}'.format(API_KEY),
        }

        response = requests.delete('https://api.digitalocean.com/v2/databases/{}'.format(elem['id']), headers=headers)
        print(response)


if __name__ == "__main__":

    # create_DBs("training", 5)
    # list_DBs()  
    # delete_all_DBs()
