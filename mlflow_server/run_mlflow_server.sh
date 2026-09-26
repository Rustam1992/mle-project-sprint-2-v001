#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

set -a
source .env
set +a

# Проверяем необходимые переменные
for var in \
    AWS_ACCESS_KEY_ID \
    AWS_SECRET_ACCESS_KEY \
    DB_DESTINATION_HOST \
    DB_DESTINATION_PORT \
    DB_DESTINATION_NAME \
    DB_DESTINATION_USER \
    DB_DESTINATION_PASSWORD \
    S3_BUCKET_NAME
do
    if [ -z "${!var:-}" ]; then
        echo "Ошибка: переменная $var не задана"
        exit 1
    fi
done

export MLFLOW_S3_ENDPOINT_URL="https://storage.yandexcloud.net"

# Формируем URI PostgreSQL.
# URL-кодирование защищает от специальных символов в пароле.
export MLFLOW_BACKEND_STORE_URI="$(
python - <<'PY'
import os
from sqlalchemy.engine import URL

url = URL.create(
    drivername="postgresql+psycopg2",
    username=os.environ["DB_DESTINATION_USER"],
    password=os.environ["DB_DESTINATION_PASSWORD"],
    host=os.environ["DB_DESTINATION_HOST"],
    port=int(os.environ["DB_DESTINATION_PORT"]),
    database=os.environ["DB_DESTINATION_NAME"],
)

print(url.render_as_string(hide_password=False))
PY
)"

export MLFLOW_DEFAULT_ARTIFACT_ROOT="s3://${S3_BUCKET_NAME}/artifacts/models"

echo "Starting MLflow..."
echo "Tracking URI: http://127.0.0.1:5000"
echo "Artifact root: $MLFLOW_DEFAULT_ARTIFACT_ROOT"

exec mlflow server \
    --backend-store-uri "$MLFLOW_BACKEND_STORE_URI" \
    --default-artifact-root "$MLFLOW_DEFAULT_ARTIFACT_ROOT" \
    --host 127.0.0.1 \
    --port 5000