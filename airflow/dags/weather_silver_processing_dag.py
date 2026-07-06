import json
import logging
from datetime import datetime, timezone

from airflow.models import Param
from airflow.providers.google.cloud.hooks.gcs import GCSHook
from airflow.sdk import dag, task
from plugins.api_validator import WeatherValuesValidator
from pydantic import ValidationError

from core_settings import settings

logger = logging.getLogger("airflow")
logger.setLevel(logging.INFO)


@dag(
    schedule="@hourly",
    start_date=datetime(2026, 1, 1),
    catchup=False,
    params={"source_path": Param(default=None, type=["null", "string"])},
)
def weather_silver_processing():

    @task
    def get_source_path(**kwargs):
        params: dict = kwargs.get("params", {})
        logical_date: datetime = kwargs.get("logical_date")
        source_path: str = params.get("source_path")

        if not source_path:
            source_path = f"weather/realtime/{settings.location}/{logical_date.strftime('%Y/%m/%d/%H')}/"
            run_type = "Scheduled"

        else:
            run_type = "Manual"

        full_path = f"gs://{settings.bronze_bucket_name}/{source_path}"

        logger.info(f"{run_type} run with path: {full_path}")

        return {"source_path": source_path, "full_path": full_path}

    @task
    def fetch_json_data(data: dict):
        source_path = data.get("source_path")
        full_path = data.get("full_path")

        hook = GCSHook()
        files: list[str] = hook.list(settings.bronze_bucket_name, prefix=source_path)

        if not files:
            error_message = f"No files found in path: {full_path}"
            logger.error(error_message)
            raise ValueError(error_message)

        else:
            logger.info(f"{len(files)} found in path: {full_path}")

        json_data: list[dict] = []

        for file_name in files:
            if not file_name.endswith(".json"):
                continue

            file_str = hook.download(settings.bronze_bucket_name, file_name).decode("utf-8")
            file_json = json.loads(file_str)
            json_data.append({"file_name": file_name, "file_data": file_json})

        return {"full_path": full_path, "full_data": json_data}

    @task(max_active_tis_per_dagrun=10)
    def flat_json_data(full_path: str, full_data: dict):
        try:
            file_name = full_data["file_name"]

        except KeyError:
            logger.error(f"Found file with broken name in path: {full_path}")
            return None

        source_object = f"{full_path}/{file_name}"

        try:
            file_data: dict = full_data["file_data"]

        except KeyError:
            logger.error(f'Invalid format for file: {source_object}. Missing "file_data" key')
            return None

        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            return None

        try:
            data: dict = file_data["data"]
            location: dict = file_data["location"]
            values: dict = data["values"]
            event_time: str = data["time"]
            location_name: str = location["name"]

        except KeyError as e:
            logger.error(f"Invalid API response format in file: {source_object}. Missing {e.args[0]} key")
            return None

        return {
            "source_object": source_object,
            "event_time": event_time,
            "location_name": location_name,
            "location_lat": location.get("lat", None),
            "location_lon": location.get("lon", None),
            "location_type": location.get("type", None),
            "ingested_at_utc": datetime.now(timezone.utc).isoformat(),
            "weather_temperature": values.get("temperature", None),
            "weather_humidity": values.get("humidity", None),
            "weather_windSpeed": values.get("windSpeed", None),
            "weather_cloudCover": values.get("cloudCover", None),
            "weather_precipitationProbability": values.get("precipitationProbability", None),
        }

    @task(max_active_tis_per_dagrun=10)
    def validate_json_data(json_obj: dict | None):
        if not json_obj:
            logger.warning("Expected args to validate, nothing was given")
            return None

        if not isinstance(json_obj, dict):
            logger.error(f'Input arg must be type dict, type "{type(json_obj)}" was given')
            return None

        try:
            validated = WeatherValuesValidator(**json_obj)

        except ValidationError as e:
            logger.error(f"Error while validating {json_obj.get('source_object')}\n{e}")
            return None

        return validated.model_dump()

    @task
    def load_to_silver():
        pass

    @task
    def load_to_bigquery():
        pass

    source_path = get_source_path()
    fetched_data = fetch_json_data(source_path)
    flat_data = flat_json_data.partial(full_path=fetched_data["full_path"]).expand(json_obj=fetched_data["full_data"])
    validated_data = validate_json_data.expand(json_obj=flat_data)
    load_to_silver(validated_data)
    load_to_bigquery(validated_data)


weather_silver_processing()
