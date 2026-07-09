from pydantic import BaseModel, field_validator


class WeatherValuesValidator(BaseModel):
    source_object: str
    event_time: str
    location_name: str
    location_lat: float | None = None
    location_lon: float | None = None
    location_type: str | None = None
    ingested_at_utc: str
    weather_temperature: float | None = None
    weather_humidity: float | None = None
    weather_windSpeed: float | None = None
    weather_cloudCover: float | None = None
    weather_precipitationProbability: float | None = None

    @field_validator("weather_humidity", "weather_cloudCover", "weather_precipitationProbability")
    def validate_percentage(cls, value):
        if value is None:
            return value
        if not 0 <= value <= 100:
            raise ValueError(f"percentage must be from 0 to 100, got {value}")
        return value

    @field_validator("weather_temperature")
    def validate_temperature(cls, value):
        if value is None:
            return value
        if not -90 <= value <= 70:
            raise ValueError(f"weather_temperature must be from -90 to 70, got {value}")
        return value

    @field_validator("weather_windSpeed")
    def validate_windSpeed(cls, value):
        if value is None:
            return value
        if not 0 <= value <= 150:
            raise ValueError(f"weather_windSpeed must be from 0 to 150, got {value}")
        return value
