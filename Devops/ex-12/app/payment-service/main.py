import os
import sys
import time
import json
import logging
import traceback
import asyncio
import psycopg2
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("payment-service")

app = FastAPI(title="Payment Service")

# DB configs from environment
DB_HOST = os.getenv("DB_HOST", "postgres")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "payments")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")

# Retry settings
MAX_RETRIES = int(os.getenv("MAX_RETRIES", "10"))
RETRY_DELAY = float(os.getenv("RETRY_DELAY", "0.05")) # 50ms to generate high traffic logs fast

def log_structured(level, event, **kwargs):
    log_data = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "level": level,
        "service": "payment-service",
        "event": event,
        **kwargs
    }
    logger.info(json.dumps(log_data))

@app.middleware("http")
async def log_requests(request: Request, call_next):
    log_structured("INFO", "http_request_received", method=request.method, path=request.url.path)
    response = await call_next(request)
    log_structured("INFO", "http_request_completed", status_code=response.status_code)
    return response

def attempt_db_connection(attempt: int):
    log_structured(
        "INFO", "db_connection_attempt",
        attempt=attempt,
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER
    )
    # This might fail if host/port/credentials are wrong
    conn = psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        connect_timeout=2
    )
    return conn

@app.post("/payments")
def process_payment(body: dict):
    order_id = body.get("order_id", "unknown")
    amount = body.get("amount", 0.0)
    
    log_structured("INFO", "processing_payment", order_id=order_id, amount=amount)
    
    conn = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            conn = attempt_db_connection(attempt)
            cur = conn.cursor()
            cur.execute("SELECT 1;")
            cur.close()
            conn.close()
            log_structured("INFO", "payment_processed_successfully", order_id=order_id)
            return {"status": "success", "order_id": order_id}
        except Exception as e:
            exc_type, exc_value, exc_traceback = sys.exc_info()
            tb_str = "".join(traceback.format_exception(exc_type, exc_value, exc_traceback))
            
            log_structured(
                "ERROR", "db_connection_failed",
                attempt=attempt,
                order_id=order_id,
                amount=amount,
                error_message=str(e),
                exception_class=exc_type.__name__ if exc_type else "Unknown",
                stack_trace=tb_str,
                database_configuration={
                    "host": DB_HOST,
                    "port": DB_PORT,
                    "database": DB_NAME,
                    "user": DB_USER,
                    "password_redacted": "********",
                    "driver": "psycopg2-binary",
                    "system_info": os.uname() if hasattr(os, 'uname') else "windows/other"
                }
            )
            
            if attempt < MAX_RETRIES:
                time.sleep(RETRY_DELAY)
            else:
                log_structured("FATAL", "db_connection_retries_exhausted", order_id=order_id)
                raise HTTPException(status_code=500, detail="Database connection failure after multiple retries")

@app.get("/healthz")
async def healthz():
    # Simple healthcheck. To prevent healthcheck failures from masking the log storm or causing restarts,
    # we just return healthy without checking DB.
    return {"status": "healthy"}
