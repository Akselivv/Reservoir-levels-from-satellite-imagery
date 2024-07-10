import os

print(os.getcwd())
os.chdir("myWorkingDirectory")

from oauthlib.oauth2 import BackendApplicationClient
from requests_oauthlib import OAuth2Session
from PIL import Image
import io
import numpy as np
import matplotlib.pyplot as plt
import shapely
import shapely.wkt


with open("client_id_secret.txt", "r") as id_secret:
    lines = id_secret.readlines()
    print(lines)

secrets = []

for l in lines:
    as_list = l.split(", ")
    secrets.append(as_list[0].replace("\n", ""))

#Load sentinel hub client id and secret from separate text file where the client id is on the first line and the secret is on the second
sh_client_id = secrets[0]
sh_client_secret = secrets[1] 

# set up credentials
client = BackendApplicationClient(client_id=sh_client_id)
oauth = OAuth2Session(client=client)

# get an authentication token
token = oauth.fetch_token(token_url='https://services.sentinel-hub.com/oauth/token',
                          client_id=sh_client_id, client_secret=sh_client_secret)


bbox = r.coords
start_date = r.dates[0]
end_date = r.dates[1]
collection_id = "sentinel-2-l2a"

evalscript_ndwi = """
//VERSION=3
function setup() {
  return {
    input: [{
    bands: ["B03", "B08"],
    units: "REFLECTANCE"
    }],
    output: {
      id: "default",
      bands: 1,
      sampleType: SampleType.FLOAT32
    }
  }
}

function evaluatePixel(sample) {
  let ndwi =  (sample.B03 - sample.B08)/(sample.B03 + sample.B08)
  return [ndwi]
  
}
"""

evalscript_true_color = """
//VERSION=3
function setup() {
  return {
     input: ["B02", "B03", "B04"],
    output: {
      bands: 3,
      sampleType: "AUTO" // default value - scales the output values from [0,1] to [0,255].
    }
  }
}

function evaluatePixel(sample) {
  return [2.5 * sample.B04, 2.5 * sample.B03, 2.5 * sample.B02]
  
}
"""

evalscript_img_ndwi = """
//VERSION=3
function setup() {
  return {
    input: [{
      bands:["B03", "B08"],
    }],
    output: {
      id: "default",
      bands: 3,
    }
  }
}

function evaluatePixel(sample) {
    
    let ndwi = (sample.B03 - sample.B08)/(sample.B08 + sample.B03)
    
    if (ndwi<-0.6) return [1,0,0]
    else if (ndwi<-0.5) return [1,0.5,0]
    else if (ndwi<-0.4) return [0.52,0.52,0.52]
    else if (ndwi<-0.4) return [0.64,0.63,0.63]
    else if (ndwi<-0.2) return [0.75,0.75,0.75]
    else if (ndwi<-0.1) return [0.86,0.86,0.86]
    else if (ndwi<0) return [0.92,0.92,0.92]
    else if (ndwi<0.025) return [0,0.975,1]
    else if (ndwi<0.05) return [0,0.95,1]
    else if (ndwi<0.075) return [0,0.925,1]
    else if (ndwi<0.1) return [0,0.9,1]
    else if (ndwi<0.125) return [0,0.875,1]
    else if (ndwi<0.15) return [0,0.85,1]
    else if (ndwi<0.175) return [0,0.825,1]
    else if (ndwi<0.2) return [0,0.8,1]
    else if (ndwi<0.25) return [0,0.75,1]
    else if (ndwi<0.3) return [0,0.7,1]
    else if (ndwi<0.35) return [0,0.65,1]
    else if (ndwi<0.4) return [0,0.6,1]
    else if (ndwi<0.45) return [0,0.55,1]
    else if (ndwi<0.5) return [0,0.5,1]
    else if (ndwi<0.55) return [0,0.45,1]
    else if (ndwi<0.6) return [0,0.4,1]
    else return [0,0,1]
    
}
"""

evalscript_ndwi_simplified = """
//VERSION=3
function setup() {
  return {
    input: [{
      bands:["B03", "B08"],
    }],
    output: {
      id: "default",
      bands: 3,
    }
  }
}

function evaluatePixel(sample) {
    
    let ndwi = (sample.B03 - sample.B08)/(sample.B08 + sample.B03)
    
    if (ndwi<-0.6) return [1,0,0]
    else if (ndwi<-0.5) return [1,0,0]
    else if (ndwi<-0.4) return [0.52,0,0.52]
    else if (ndwi<-0.4) return [0.64,0,0.63]
    else if (ndwi<-0.2) return [0.75,0,0.75]
    else if (ndwi<-0.1) return [0.86,0,0.86]
    else if (ndwi<0) return [0.92,0,0.92]
    else if (ndwi<0.025) return [0.96,0,0.96]
    else if (ndwi<0.05) return [0,ndwi,1]
    else if (ndwi<0.075) return [0,ndwi,1]
    else if (ndwi<0.1) return [0,ndwi,1]
    else if (ndwi<0.125) return [0,ndwi,1]
    else if (ndwi<0.15) return [0,ndwi,1]
    else if (ndwi<0.175) return [0,ndwi,1]
    else if (ndwi<0.2) return [0,ndwi,1]
    else if (ndwi<0.25) return [0,ndwi,1]
    else if (ndwi<0.3) return [0,ndwi,1]
    else if (ndwi<0.35) return [0,ndwi,1]
    else if (ndwi<0.4) return [0,ndwi,1]
    else if (ndwi<0.45) return [0,ndwi,1]
    else if (ndwi<0.5) return [0,ndwi,1]
    else if (ndwi<0.55) return [0,ndwi,1]
    else if (ndwi<0.6) return [0,ndwi,1]
    else return [0,ndwi,1]
    
}
"""


json_request = {
    'input': {
        'bounds': {
            'bbox': bbox,
            'properties': {
                'crs': 'http://www.opengis.net/def/crs/OGC/1.3/CRS84'
            }
        },
        'data': [
            {
                'type': 'sentinel-2-l1c',
                'dataFilter': {
                    'timeRange': {
                        'from': f'{start_date}T00:00:00Z',
                        'to': f'{end_date}T23:59:59Z'
                    },
                    'mosaickingOrder': 'leastCC',
                },
            }
        ]
    },
    'output': {
        'width': 2048,
        'height': 2048,
        'responses': [
            {
                "identifier": "default",
                "format": {
                    "type": "image/jpeg",
                    "quality": 100
                }
            }
        ]
    },
    'evalscript': evalscript_ndwi_simplified
}

# Set the request url and headers
url_request = 'https://services.sentinel-hub.com/api/v1/process'
headers_request = {
    "Authorization" : "Bearer %s" %token['access_token']
}

#Send the request
response = oauth.request(
    "POST", url_request, headers=headers_request, json = json_request
)

# read the image as numpy array
image_arr = np.array(Image.open(io.BytesIO(response.content)))
arr2 = Image.open(io.BytesIO(response.content))
arr3 = io.BytesIO(response.content)

plt.figure(figsize=(16,16))
plt.axis('off')
plt.tight_layout()
plt.imshow(image_arr)
