from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).parents[2]


class Settings(BaseSettings):
    bronze_bucket_name: str
    tomorrow_api_key: str
    model_config = SettingsConfigDict(extra="ignore")
    location: str = "warsaw"


settings = Settings()
