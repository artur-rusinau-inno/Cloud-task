import json
import logging
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pandas as pd
from airflow.models import Param
from airflow.providers.google.cloud.hooks.gcs import GCSHook
from airflow.providers.google.cloud.transfers.gcs_to_bigquery import GCSToBigQueryOperator
from airflow.providers.google.cloud.transfers.local_to_gcs import LocalFilesystemToGCSOperator
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
    max_active_runs=10,
)
def weather_silver_processing():

    @task(multiple_outputs=True)
    def get_source_path(**kwargs):
        params: dict = kwargs.get("params", {})
        logical_date: datetime = kwargs.get("logical_date")
        previout_hour = logical_date - timedelta(hours=1)
        source_path: str = params.get("source_path")

        if not source_path:
            source_path = f"weather/realtime/{settings.location}/{previout_hour.strftime('%Y/%m/%d/%H')}/"
            run_type = "SCHEDULED"

        else:
            run_type = "MANUAL"

        full_path = f"gs://{settings.bronze_bucket_name}/{source_path}"

        logger.info(f"{run_type} run with path: {full_path}")

        return {"source_path": source_path, "full_path": full_path}

    @task.short_circuit
    def check_for_files(data: dict):
        source_path = data["source_path"]
        full_path = data["full_path"]

        hook = GCSHook()
        list_files: list[str] = hook.list(settings.bronze_bucket_name, prefix=source_path)

        if not list_files:
            logger.error(f"No files found in path: {full_path}")
            return False

        logger.info(f"{len(list_files)} found in path: {full_path}")
        return list_files

    @task(max_active_tis_per_dagrun=10)
    def fetch_json_data(file_name: str):
        hook = GCSHook()

        if not file_name.endswith(".json"):
            logger.warning(f"Got not a JSON file: {file_name}")
            return None

        file_str = hook.download(settings.bronze_bucket_name, file_name).decode("utf-8")
        file_json = json.loads(file_str)
        return {"file_name": file_name, "file_data": file_json}

    @task
    def filter_clean_json(corrupted_data: list):
        clean_list = [item for item in corrupted_data if item is not None]
        logger.info(f"Excluded {len(corrupted_data) - len(clean_list)} non-JSON objects")
        return clean_list

    @task(max_active_tis_per_dagrun=10)
    def flat_json_data(full_path: str, full_data: dict):
        file_name = full_data["file_name"]
        file_data: dict = full_data["file_data"]

        source_object = f"{full_path}{file_name}"

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
            logger.warning("Expected args to validate, but nothing was given")
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

    @task(multiple_outputs=True)
    def make_csv(data: list[dict]):
        clean_data = [row for row in data if row is not None]

        if not clean_data:
            error_message = "No data left for creating CSV report, DAG aborted"
            logger.error(error_message)
            raise ValueError(error_message)

        df = pd.DataFrame(clean_data)
        schema = [field["name"] for field in settings.bigquery_schema]

        df = df.reindex(columns=schema)
        df = df.drop_duplicates(["location_name", "event_time"])

        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
        csv_file = Path(f"/tmp/data_{timestamp}.csv")

        df.to_csv(csv_file, index=False, encoding="utf-8")

        logger.info(f"CSV report successfully created in path {csv_file}, {len(df)} rows")

        return {"file_path": str(csv_file), "timestamp": timestamp}

    source_path = get_source_path()
    files = check_for_files(source_path)

    fetched_data = fetch_json_data.expand(file_name=files)
    clean_fetched_data = filter_clean_json(fetched_data)

    flat_data = flat_json_data.partial(full_path=source_path["full_path"]).expand(full_data=clean_fetched_data)
    validated_data = validate_json_data.expand(json_obj=flat_data)

    csv_output = make_csv(validated_data)
    timestamp = csv_output["timestamp"]
    file_path = csv_output["file_path"]

    upload_csv_to_gcs = LocalFilesystemToGCSOperator(
        task_id="upload_csv_to_gcs",
        src=file_path,
        dst=f"landing/weather/data_{timestamp}.csv",
        bucket=settings.silver_bucket_name,
    )

    gcs_to_bigquery = GCSToBigQueryOperator(
        task_id="gcs_to_bigquery",
        bucket=settings.silver_bucket_name,
        source_objects=[f"landing/weather/data_{timestamp}.csv"],
        destination_project_dataset_table=settings.bigquery_destination_path,
        write_disposition="WRITE_APPEND",
        skip_leading_rows=1,
        autodetect=False,
        schema_fields=settings.bigquery_schema,
    )

    upload_csv_to_gcs >> gcs_to_bigquery


weather_silver_processing()
