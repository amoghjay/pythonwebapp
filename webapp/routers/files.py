from fastapi import APIRouter, File, UploadFile, HTTPException, status, Depends, Request
from starlette import status
from starlette.responses import Response
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError
from database import get_db
from models import FileMetadata
from s3_service import upload_file_to_s3, delete_file_from_s3
import uuid
#import logging
from logger_util import get_logger
from metrics import record_api_metric, record_db_metric, record_s3_metric
import time

router = APIRouter()

# logging.basicConfig(level=logging.ERROR)
# logger = logging.getLogger(__name__)
logger = get_logger(__name__)

@router.post("/v1/file", status_code=status.HTTP_201_CREATED)
async def upload_file(file: UploadFile = File(None), db: Session = Depends(get_db)):
    start_time = time.time()
    """Uploads a file to S3 and returns the file URL"""
    if file is None:
        logger.warning("No file was provided in the request.")
        response_400 = Response(status_code=status.HTTP_400_BAD_REQUEST)
        response_400.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response_400.headers['Pragma'] = "no-cache"
        return response_400

    file_id = str(uuid.uuid4())  # Generate a unique file ID
    file_name = f"{file_id}_{file.filename}"  # Append UUID for uniqueness

    try:
        s3_start = time.time()
        metadata = upload_file_to_s3(file.file, file_name)
        s3_duration = (time.time() - s3_start) * 1000
        record_s3_metric("upload_file", s3_duration)

        # Store metadata in the database using `file_id` as the primary key
        file_metadata = FileMetadata(
            id=file_id,  # Using file_id as primary key
            file_name=file_name,
            url=metadata["file_url"],  # Store only the S3 key
            size=metadata["size"],
            upload_date=metadata["upload_date"]
        )
        db_start = time.time()
        db.add(file_metadata)
        db.commit()
        db.refresh(file_metadata)
        db_duration = (time.time() - db_start) * 1000
        record_db_metric("upload_file", db_duration)
        logger.info(f"Successfully uploaded file: {file_name}, stored in S3 and metadata in DB.")
        logger.info(f"Successfully retrieved metadata for file ID: {id}")
        api_duration = (time.time() - start_time) * 1000
        record_api_metric("upload_file", api_duration)
        return {
            "file_name": file_name,
            "file_id": file_id,
            "file_url": metadata["file_url"],
            "size": metadata["size"],
            #"content_type": metadata["content_type"],
            "upload_date": metadata["upload_date"],
            "message": "File added"
        }
    except SQLAlchemyError as db_err:
        db.rollback()
        logger.error(f"Database connectivity check failed: {db_err}", exc_info=True)
        # print(f"Database connectivity check failed: {db_err}")
        try:
            delete_file_from_s3(file_name)
            logger.info(f"Deleted file {file_name} from S3 after DB failure.")
        except Exception as s3_err:
            logger.error(f"Failed to delete {file_name} from S3: {str(s3_err)}")
        api_duration = (time.time() - start_time) * 1000
        record_api_metric("upload_file", api_duration)
        response_503 = Response(status_code=status.HTTP_503_SERVICE_UNAVAILABLE)
        response_503.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response_503.headers['Pragma'] = "no-cache"
        return response_503
    except Exception as e:
        logger.warning("No file was provided in the request.")
        # final API duration
        api_duration = (time.time() - start_time) * 1000
        record_api_metric("upload_file", api_duration)
        raise HTTPException(status_code=400, detail=f"Bad request: {str(e)}")

@router.api_route("/v1/file", methods=["GET", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"], status_code=status.HTTP_405_METHOD_NOT_ALLOWED)
async def method_not_allowed():
    response = Response(status_code=status.HTTP_405_METHOD_NOT_ALLOWED)
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers['Pragma'] = "no-cache"
    return response

@router.get("/v1/file/{id}", status_code=status.HTTP_200_OK)
async def get_file_info(id: str, request: Request, db: Session = Depends(get_db)):
    start_time = time.time()

    if await request.body():
        response_400 = Response(status_code=status.HTTP_400_BAD_REQUEST)
        response_400.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response_400.headers['Pragma'] = "no-cache"
        return response_400

    try:
        # Fetch file metadata from the database
        db_start = time.time()
        file_record = db.query(FileMetadata).filter(FileMetadata.id == id).first()
        record_db_metric("get_file", (time.time() - db_start) * 1000)
        if not file_record:
            logger.warning(f"File with id {id} not found in DB")
            response_404 = Response(status_code=status.HTTP_404_NOT_FOUND)
            response_404.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
            response_404.headers['Pragma'] = "no-cache"
            api_duration = (time.time() - start_time) * 1000
            record_api_metric("get_file", api_duration)
            return response_404
        logger.info(f"Successfully retrieved metadata for file ID: {id}")
        api_duration = (time.time() - start_time) * 1000
        record_api_metric("get_file", api_duration)
        return {
            "id": file_record.id,
            "file_name": file_record.file_name,
            "file_url": file_record.url,  # S3 URL, not actual file content
            "size": file_record.size,
            "upload_date": file_record.upload_date
        }
    
    except SQLAlchemyError as db_err:
        logger.error(f"Database connectivity error: {db_err}")
        response_503 = Response(status_code=status.HTTP_503_SERVICE_UNAVAILABLE)
        response_503.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response_503.headers['Pragma'] = "no-cache"
        api_duration = (time.time() - start_time) * 1000
        record_api_metric("get_file", api_duration)
        return response_503

    
    except Exception as e:
        logger.error(f"Error retrieving file metadata for {id}: {str(e)}")
        response_404 = Response(status_code=status.HTTP_404_NOT_FOUND)
        response_404.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response_404.headers['Pragma'] = "no-cache"
        api_duration = (time.time() - start_time) * 1000
        record_api_metric("get_file", api_duration)
        return response_404


@router.delete("/v1/file/{id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_file(id: str, request: Request, db: Session = Depends(get_db)):
    """Deletes a file from both S3 and the database"""
    start_time = time.time()

    if await request.body():
        response_400 = Response(status_code=status.HTTP_400_BAD_REQUEST)
        response_400.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response_400.headers['Pragma'] = "no-cache"
        return response_400
    db_start = time.time()
    file_record = db.query(FileMetadata).filter(FileMetadata.id == id).first()
    record_db_metric("delete_file", (time.time() - db_start) * 1000)
    if not file_record:
        logger.warning(f"File with ID {id} not found in the database. Skipping deletion.")
        response_404 = Response(status_code=status.HTTP_404_NOT_FOUND)
        response_404.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response_404.headers['Pragma'] = "no-cache"
        api_duration = (time.time() - start_time) * 1000
        record_api_metric("get_file", api_duration)
        return response_404
    try:
        # Delete the file from S3
        try:
            s3_start = time.time()
            delete_file_from_s3(file_record.file_name)  # Passing the stored S3 key
            s3_duration = (time.time() - s3_start) * 1000
            record_s3_metric("delete_file", s3_duration)
            logger.info(f"Deleted file {file_record.file_name} from S3.")
        except Exception as s3_err:
            logger.error(f"Failed to delete {file_record.file_name} from S3: {str(s3_err)}")
            response_404 = Response(status_code=status.HTTP_404_NOT_FOUND)
            response_404.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
            response_404.headers['Pragma'] = "no-cache"
            api_duration = (time.time() - start_time) * 1000
            record_api_metric("delete_file", api_duration)
            return response_404

        # Delete file metadata from the database
        db.delete(file_record)
        db.commit()

    except Exception as e:
        logger.error(f"Error deleting file {id}: {str(e)}")
        response_400 = Response(status_code=status.HTTP_400_BAD_REQUEST)
        response_400.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response_400.headers['Pragma'] = "no-cache"
        return response_400

@router.api_route("/v1/file/{id}", methods=["POST", "PUT", "PATCH", "HEAD", "OPTIONS"], status_code=status.HTTP_405_METHOD_NOT_ALLOWED)
async def method_not_allowed():
    response = Response(status_code=status.HTTP_405_METHOD_NOT_ALLOWED)
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers['Pragma'] = "no-cache"
    return response
