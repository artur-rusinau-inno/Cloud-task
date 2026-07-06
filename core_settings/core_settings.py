from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).parents[2]


class AirflowSettings(BaseSettings):
    pass


class CloudFunctionsSettings(BaseSettings):
    tomorrow_api_key: str
    bronze_bucket_name: str
    location: str = "warsaw"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(extra="ignore")

    airflow: AirflowSettings = AirflowSettings()
    cloud_funcs: CloudFunctionsSettings = CloudFunctionsSettings()


settings = Settings()
