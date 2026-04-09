from sqlalchemy import text
from ame.app.db import SessionLocal
from datetime import datetime,timezone

def upsert_attendance(student_id, class_id, attendance_rate):
    db = SessionLocal()
    db.execute(
        text("""
            INSERT INTO student_attendance
            (student_id, class_id, attendance_rate, last_updated)
            VALUES (:s, :c, :a, :t)
            ON CONFLICT (student_id, class_id)
            DO UPDATE SET
                attendance_rate = EXCLUDED.attendance_rate,
                last_updated = EXCLUDED.last_updated
        """),
        {
            "s": student_id,
            "c": class_id,
            "a": attendance_rate,
            "t": datetime.now(timezone.utc)
        }
    )
    db.commit()
    db.close()


def get_attendance(student_id, class_id):
    db = SessionLocal()
    result = db.execute(
        text("""
            SELECT attendance_rate
            FROM student_attendance
            WHERE student_id = :s AND class_id = :c
        """),
        {"s": student_id, "c": class_id}
    ).fetchone()
    db.close()

    return result[0] if result else None
