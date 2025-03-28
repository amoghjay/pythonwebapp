import boto3
from botocore.exceptions import NoCredentialsError, ClientError
import os

#S3_BUCKET_NAME = "webapptestamogh"
S3_BUCKET_NAME = os.getenv("S3_BUCKET")

# Initialize S3 client
# s3_client = boto3.client("s3")

session = boto3.Session()
s3_client = session.client("s3")
AWS_REGION = session.region_name

def upload_file_to_s3(file_obj, file_name):
    """Uploads file to S3 and returns the file URL"""
    try:
        s3_client.upload_fileobj(file_obj, S3_BUCKET_NAME, file_name)
        # file_url = f"https://{S3_BUCKET_NAME}.s3.amazonaws.com/{file_name}"
        # Fetch the actual URL from S3 metadata
        metadata = s3_client.head_object(Bucket=S3_BUCKET_NAME, Key=file_name)
        # Extract required metadata
        file_size = metadata["ContentLength"]  # File size in bytes
        content_type = metadata["ContentType"]  # MIME type
        upload_date = metadata["LastModified"].isoformat()  # Upload timestamp

        # Construct actual file URL from AWS S3
        file_url = f"https://{S3_BUCKET_NAME}.s3.{AWS_REGION}.amazonaws.com/{file_name}"
        # return file_url
        return {
            "s3_key": file_name,
            "size": file_size,
            "content_type": content_type,
            "upload_date": upload_date,
            "file_url": file_url
        }
    except NoCredentialsError:
        raise Exception("AWS credentials not available")


def delete_file_from_s3(file_name):
    """Deletes a file from S3"""
    try:
        s3_client.delete_object(Bucket=S3_BUCKET_NAME, Key=file_name)
        print(f"Deleted {file_name} from S3.")
    except NoCredentialsError:
        raise Exception("AWS credentials not available")
    except ClientError as e:
        if e.response["Error"]["Code"] == "NoSuchKey":
            print(f"File {file_name} not found in S3.")
        else:
            raise Exception(f"Error deleting {file_name} from S3: {str(e)}")