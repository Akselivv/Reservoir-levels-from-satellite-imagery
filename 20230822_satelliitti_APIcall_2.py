from oauthlib.oauth2 import BackendApplicationClient
from requests_oauthlib import OAuth2Session

import json
import os

# Read client credentials
os.chdir("//home.org.aalto.fi/valivia1/data/Documents/GitHub/Satelliittiprojekti")
with open("client_id_secret.txt", "r") as id_secret:
    lines = id_secret.readlines()
    print(lines)

secrets = []

for l in lines:
    as_list = l.split(", ")
    secrets.append(as_list[0].replace("\n", ""))

# Your client credentials
client_id = secrets[0]
client_secret = secrets[1]

# Create a session
client = BackendApplicationClient(client_id=client_id)
oauth = OAuth2Session(client=client)

# Get token for the session
token = oauth.fetch_token(token_url='https://services.sentinel-hub.com/oauth/token',
                          client_secret=client_secret)

# All requests using this session will have an access token automatically added
resp = oauth.get("https://services.sentinel-hub.com/oauth/tokeninfo")
print(resp.content)
print(token)

lauvastol_coords = (6.684511, 59.493279, 6.713705, 59.505802)
res = 20
lauvastol_bbox = BBox(bbox = lauvastol_coords, crs=CRS.WGS84)
lauvastol_size = bbox_to_dimensions(lauvastol_bbox, resolution = res)

evalscript_all_bands = r.evalScriptFromR

request_all_bands = SentinelHubRequest(
    evalscript=evalscript_all_bands,
    input_data=[
        SentinelHubRequest.input_data(
            data_collection=DataCollection.SENTINEL2_L1C,
            time_interval=("2018-01-01", "2023-09-21"),
            mosaicking_order=MosaickingOrder.LATEST,
        )
    ],
    responses=[SentinelHubRequest.output_response("default", MimeType.TIFF)],
    bbox=lauvastol_bbox,
    size=lauvastol_size,
    config=config,
)

#headers = {
#  'Content-Type': 'application/json',
#  'Accept': 'application/json'
#}
#url = "https://services.sentinel-hub.com/api/v1/statistics"

#response = oauth.request("POST", url=url , headers=headers, json=stats_request)
#sh_statistics = response.json()
#print(sh_statistics)

#with open('data45.json', 'w', encoding='utf-8') as f:
#    json.dump(sh_statistics, f, ensure_ascii=False, indent=4)
