from pydantic import BaseModel
from datetime import datetime

class HealthCheck(BaseModel):
    id : int
    datetime: datetime

    class Config:
        orm_mode = True
