from sqlalchemy import Column, Integer, String, Float, Timestamp
from sqlalchemy.ext.declarative import declarative_base
from datetime import datetime,timezone

Base = declarative_base()

class StudentConceptMastery(Base):
    __tablename__ = "student_concept_mastery"

    id = Column(Integer, primary_key=True)
    student_id = Column(String, nullable=False)
    concept_id = Column(String, nullable=False)
    mastery_score = Column(Float, nullable=False)
    attempts = Column(Integer, nullable=False)
    trend = Column(String)
    last_updated = Column(Timestamp, default=datetime.now(timezone.utc))
