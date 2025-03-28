from fastapi import FastAPI, Request
from database import engine
import models
from routers import health, files
from starlette import status
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response
from logger_util import get_logger
import time


models.Base.metadata.create_all(bind=engine)

app = FastAPI()
logger = get_logger(__name__)

class MethodNotAllowedMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        allowed_paths = ["/healthz", "/v1/file"]

        # Allow exact matches or paths that start with "/v1/file/"
        if request.url.path in allowed_paths or request.url.path.startswith("/v1/file/"):
            return await call_next(request)

        response = Response(status_code=status.HTTP_405_METHOD_NOT_ALLOWED)
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response.headers['Pragma'] = "no-cache"
        return response


app.add_middleware(
    MethodNotAllowedMiddleware
)

app.include_router(health.router)
app.include_router(files.router)

@app.middleware("http")
async def add_no_cache_header(request: Request, call_next):
    response = await call_next(request)
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers['Pragma'] = "no-cache"
    return response
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    logger.info(f"{request.method} request to {request.url.path}")

    try:
        response = await call_next(request)
    except Exception as e:
        logger.exception("An unhandled exception occurred while processing the request.")
        raise e

    duration = (time.time() - start_time) * 1000
    logger.info(f"{request.method} {request.url.path} completed in {duration:.2f} ms with status {response.status_code}")
    return response