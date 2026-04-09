from pydantic import BaseModel
from datetime import datetime

class AMEEvent(BaseModel):
    student_id: str
    concept_id: str
    class_id:   str
    event_type: str
    score: float
    timestamp: datetime

class AttendanceUpdate(BaseModel):
    student_id: str
    class_id: str
    attendance_rate: float  # 0.0 – 1.0
