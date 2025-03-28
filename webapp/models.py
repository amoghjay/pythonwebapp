from sqlalchemy import Column, Integer, DateTime, String
from database import Base
import datetime


class HealthCheck(Base):
    __tablename__ = "health_checks"

    id = Column(Integer, primary_key=True, index=True)
    datetime = Column(DateTime, default=datetime.datetime.utcnow)

class FileMetadata(Base):
    """Database model for storing file metadata"""
    __tablename__ = "files"

    id = Column(String, primary_key=True)
    file_name = Column(String, nullable=False)
    url = Column(String, nullable=False)  # S3 object key, not full URL
    size = Column(Integer, nullable=False)  # File size in bytes
    upload_date = Column(DateTime, nullable=False)  # Upload timestamp