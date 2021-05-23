
import requests
import json

url = "https://api.digitalocean.com/v2/droplets"

payload = {}
headers = {}

response = requests.request("GET", url, headers=headers, data = payload, verify=False)

j = json.loads(response.text.encode('utf8'))
for dl in j['droplets']:
    print (dl['networks']['v4'][0]['ip_address'])

url = "https://api.digitalocean.com/v2/droplets?page=2&per_page=20"
response = requests.request("GET", url, headers=headers, data = payload)
j = json.loads(response.text.encode('utf8'))
for dl in j['droplets']:
    print (dl['networks']['v4'][0]['ip_address'])

url = "https://api.digitalocean.com/v2/droplets?page=3&per_page=20"
response = requests.request("GET", url, headers=headers, data = payload)
j = json.loads(response.text.encode('utf8'))
for dl in j['droplets']:
    print (dl['networks']['v4'][0]['ip_address'])
