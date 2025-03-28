# metrics.py

from statsd import StatsClient

# StatsD runs on EC2 at localhost:8125
statsd = StatsClient(host='localhost', port=8125)

def record_api_metric(api_name: str, duration_ms: float):
    statsd.incr(f"api.{api_name}.count")
    statsd.timing(f"api.{api_name}.latency", duration_ms)

def record_db_metric(query_name: str, duration_ms: float):
    statsd.timing(f"db.query.{query_name}.time", duration_ms)

def record_s3_metric(op_name: str, duration_ms: float):
    statsd.timing(f"s3.{op_name}.time", duration_ms)