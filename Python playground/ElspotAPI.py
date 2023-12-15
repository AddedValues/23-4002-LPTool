"""
Scripts to fetch Elspot prices from EnergiNet through REST API.
See API Guide: https://www.energidataservice.dk/guides/api-guides 
"""

import requests

response = requests.get(
    url='https://api.energidataservice.dk/dataset/Elspotprices?limit=5')

result = response.json()

for k, v in result.items():
    print(k, v)

records = result.get('records', [])
                                           
print('records:')
for record in records:
    print(' ', record)