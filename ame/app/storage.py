from sqlalchemy import text
from ame.app.db import SessionLocal
from datetime import datetime,timezone

def get_mastery(student_id, concept_id, class_id):
    db = SessionLocal()
    row = db.execute(
        text("""
            SELECT mastery_score, attempts, confidence, bkt_probability, theta
            FROM student_concept_mastery
            WHERE student_id = :s AND concept_id = :c AND class_id = :cl
        """),
        {"s": student_id, "c": concept_id,"cl":class_id}
    ).fetchone()
    db.close()

    if row:
        return {
            "mastery_score": row[0],
            "attempts": row[1],
            "confidence": row[2],
            "bkt_probability": row[3],
            "theta": row[4]
        }
    return None


def upsert_mastery(student_id, concept_id, class_id, record):
    db = SessionLocal()
    db.execute(
        text("""
            INSERT INTO student_concept_mastery
            (student_id, concept_id, class_id, mastery_score, attempts, confidence, bkt_probability, theta, last_updated)
            VALUES (:s, :c, :cl, :ms, :a, :conf, :bkt, :theta, :l)
            ON CONFLICT (student_id, concept_id, class_id)
            DO UPDATE SET
                mastery_score = EXCLUDED.mastery_score,
                attempts = EXCLUDED.attempts,
                confidence = EXCLUDED.confidence,
                bkt_probability = EXCLUDED.bkt_probability,
                theta = EXCLUDED.theta,
                last_updated = EXCLUDED.last_updated
        """),
        {
            "s": student_id,
            "c": concept_id,
            "cl":class_id,
            "ms": record["mastery_score"],
            "a": record["attempts"],
            "conf": record["confidence"],
            "bkt": record["bkt_probability"],
            "theta": record["theta"],
            "l": datetime.now(timezone.utc)
        }
    )
    db.commit()
    db.close()
