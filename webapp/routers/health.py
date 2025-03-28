from fastapi import APIRouter, Depends, HTTPException, Request
from starlette import status
from starlette.responses import Response
from sqlalchemy.orm import Session
import models
import schemas
from database import get_db
import logging
logger = logging.getLogger(__name__)
from metrics import record_api_metric, record_db_metric, record_s3_metric
import time

router = APIRouter()


@router.get("/healthz", status_code=status.HTTP_200_OK, response_model=None)
async def health_check(request: Request, db: Session = Depends(get_db)):
    start_time = time.time()
    if await request.body() or request.query_params:
        logger.warning("Invalid request received for health check.")
        response_400 = Response(status_code=status.HTTP_400_BAD_REQUEST)
        response_400.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response_400.headers['Pragma'] = "no-cache"
        return response_400

    try:
        new_check = models.HealthCheck()
        db_start = time.time()
        db.add(new_check)
        db.commit()
        record_db_metric("get_healthz", (time.time() - db_start) * 1000)
        response_200 = Response(status_code=status.HTTP_200_OK)
        response_200.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response_200.headers['Pragma'] = "no-cache"
        record_api_metric("get_healthz", (time.time() - start_time) * 1000)
        return response_200
    except Exception as e:
        db.rollback()
        logger.error(f"Database connectivity check failed: {e}", exc_info=True)
        response_503 = Response(status_code=status.HTTP_503_SERVICE_UNAVAILABLE)
        response_503.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response_503.headers['Pragma'] = "no-cache"
        record_api_metric("get_healthz", (time.time() - start_time) * 1000)
        return response_503


@router.api_route("/healthz", methods=["POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"], status_code=status.HTTP_405_METHOD_NOT_ALLOWED)
async def method_not_allowed(request: Request, db: Session = Depends(get_db)):
    logger.warning(f"Invalid {request} request received for health check.")
    response = Response(status_code=status.HTTP_405_METHOD_NOT_ALLOWED)
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers['Pragma'] = "no-cache"
    return response

