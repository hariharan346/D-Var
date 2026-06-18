import os
import logging
import sys
import requests
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='{"time": "%(asctime)s", "level": "%(levelname)s", "service": "order-service", "message": "%(message)s"}',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("order-service")

app = FastAPI(title="Order Service")

PAYMENT_SERVICE_URL = os.getenv("PAYMENT_SERVICE_URL", "http://payment-service:8000")

@app.middleware("http")
async def log_requests(request: Request, call_next):
    logger.info(f"Received request: {request.method} {request.url.path}")
    response = await call_next(request)
    logger.info(f"Responding with status: {response.status_code}")
    return response

@app.post("/orders")
def create_order(body: dict):
    logger.info(f"Processing order: {body.get('order_id', 'unknown')}. Forwarding to Payment Service.")
    try:
        # Increase timeout to 30s to allow downstream retries to finish
        response = requests.post(f"{PAYMENT_SERVICE_URL}/payments", json=body, timeout=30)
        return JSONResponse(status_code=response.status_code, content=response.json())
    except requests.exceptions.RequestException as e:
        logger.error(f"Error communicating with Payment Service: {str(e)}")
        raise HTTPException(status_code=503, detail="Payment Service unavailable")

@app.get("/healthz")
async def healthz():
    return {"status": "healthy"}
