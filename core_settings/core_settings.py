import json
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).parents[1]
CURRENT_DIR = Path(__file__).parent


class Settings(BaseSettings):
    project_id: str
    bigquery_dataset: str
    bigquery_table: str

    bronze_bucket_name: str
    silver_bucket_name: str
    tomorrow_api_key: str
    location: str = "warsaw"

    model_config = SettingsConfigDict(env_file=(".env", ".env.terraform"), env_file_encoding="utf-8", extra="ignore")

    @property
    def bigquery_destination_path(self):
        return f"{self.project_id}.{self.bigquery_dataset}.{self.bigquery_table}"

    @property
    def bigquery_schema(self):
        file = CURRENT_DIR / "bigquery_schema.json"
        with file.open("r", encoding="utf-8") as f:
            data = json.load(f)
        return data


settings = Settings()
