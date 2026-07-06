import json
import logging
from datetime import datetime, timezone

import functions_framework
import requests
from google.cloud import storage
from requests import HTTPError

from core_settings import settings

logging.getLogger().setLevel(logging.INFO)

try:
    storage_client = storage.Client()
    logging.info("GCS Client initialized successfully")

except Exception as e:
    logging.error(f"GCS Client failed to initialize: {e}")
    raise e


@functions_framework.http
def fetch_weather_to_bronze(request) -> tuple[dict, int]:
    bucket_name = settings.cloud_funcs.bronze_bucket_name
    location = settings.cloud_funcs.location
    api_key = settings.cloud_funcs.tomorrow_api_key

    url = f"https://api.tomorrow.io/v4/weather/realtime?location={location}&apikey={api_key}"
    headers = {"accept": "application/json"}

    logging.info(f'Trying to fetch weather in "{location.capitalize()}"')

    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()

    except HTTPError as e:
        status_code = e.response.status_code
        reason = e.response.reason
        logging.error("API request error")
        return {"status": "failure", "status_code": status_code, "reason": reason}, status_code

    except Exception as e:
        logging.error(f"Exception has occured: {e}")
        raise e

    data = response.json()
    if not data:
        logging.error("No data from API call")
        return {"status": "failure", "status_code": 502, "reason": "No data from API call"}, 502

    data_str = json.dumps(data, indent=4, ensure_ascii=False)

    now = datetime.now(timezone.utc)
    timestamp = now.isoformat()

    blob_name = f"weather/realtime/{location}/{now.strftime('%Y/%m/%d/%H')}/{timestamp}.json"

    upload_to_gcs_bronze(bucket_name, blob_name, data_str)

    storage_path = f"gs://{bucket_name}/{blob_name}"

    logging.info(f"Created new file in GCS bronze: {storage_path}")

    return {
        "status": "success",
        "location": location,
        "timestamp": timestamp,
        "storage_path": storage_path,
    }, 200


def upload_to_gcs_bronze(bucket_name: str, blob_name: str, data: str) -> None:

    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(blob_name)

    try:
        blob.upload_from_string(data, content_type="application/json")
        logging.info("Data uploaded to GCS successfully")

    except Exception as e:
        logging.error("Failed to upload data to GCS")
        raise e
