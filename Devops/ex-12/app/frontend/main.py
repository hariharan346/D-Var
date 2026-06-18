import os
import logging
import sys
import requests
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='{"time": "%(asctime)s", "level": "%(levelname)s", "service": "frontend", "message": "%(message)s"}',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("frontend")

app = FastAPI(title="Frontend Service")

ORDER_SERVICE_URL = os.getenv("ORDER_SERVICE_URL", "http://order-service:8000")

@app.middleware("http")
async def log_requests(request: Request, call_next):
    logger.info(f"Received request: {request.method} {request.url.path}")
    response = await call_next(request)
    logger.info(f"Responding with status: {response.status_code}")
    return response

@app.post("/order")
def create_order(body: dict):
    logger.info(f"Forwarding order creation request to Order Service: {ORDER_SERVICE_URL}/orders")
    try:
        # Increase timeout to 30s to allow downstream retries to finish
        # without client dropping connection
        response = requests.post(f"{ORDER_SERVICE_URL}/orders", json=body, timeout=30)
        return JSONResponse(status_code=response.status_code, content=response.json())
    except requests.exceptions.RequestException as e:
        logger.error(f"Error communicating with Order Service: {str(e)}")
        raise HTTPException(status_code=503, detail="Order Service unavailable")

@app.get("/healthz")
async def healthz():
    return {"status": "healthy"}
