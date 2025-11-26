FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir \
    flask \
    redis \
    prometheus-client \
    opentelemetry-api \
    opentelemetry-sdk \
    opentelemetry-exporter-jaeger \
    opentelemetry-exporter-prometheus \
    opentelemetry-instrumentation-flask \
    opentelemetry-instrumentation-redis \
    opentelemetry-instrumentation-requests

COPY app.py .

EXPOSE 5000

CMD ["python", "app.py"]
