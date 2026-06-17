FROM python:3.11-slim

WORKDIR /app

# Install system dependencies if compiling psycopg2 (not needed for psycopg2-binary but good practice)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libc-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

CMD ["python", "-u", "main.py"]
