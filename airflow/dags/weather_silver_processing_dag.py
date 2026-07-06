from airflow.sdk import dag, task
from pendulum import datetime


@dag(schedule="@hourly", start_date=datetime(2026, 1, 1), catchup=False)
def weather_silver_processing():

    @task
    def p():
        pass
