from pydantic import BaseModel, field_validator


class WeatherValues(BaseModel):
    temperature: float | None = None
    humidity: float | None = None
    windSpeed: float | None = None
    cloudCover: float | None = None
    precipitationProbability: float | None = None

    @field_validator("humidity", "cloudCover", "precipitationProbability")
    def validate_percentage(cls, value):
        if not 0 <= value <= 100:
            raise ValueError(f"percentage must be from 0 to 100, got {value}")

    @field_validator("temperature")
    def validate_temperature(cls, value):
        if not -90 <= value <= 70:
            raise ValueError(f"temperature must be from -90 to 70, got {value}")

    @field_validator("windSpeed")
    def validate_windSpeed(cls, value):
        if not 0 <= value <= 150:
            raise ValueError(f"windSpeed must be from 0 to 150, got {value}")


class LocationData(BaseModel):
    name: str
    type: str | None = None
    lat: float | None = None
    lon: float | None = None


class WeatherData(BaseModel):
    values: WeatherValues
    time: str


class WeatherPayload(BaseModel):
    data: WeatherData
    location: LocationData
