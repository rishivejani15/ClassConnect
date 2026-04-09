from sqlalchemy import text
from ame.app.db import SessionLocal
from datetime import datetime, timezone


def is_class_pbl_completed(student_id: str, class_id: str) -> bool:
    db = SessionLocal()
    row = db.execute(
        text("""
            SELECT completed
            FROM student_class_pbl
            WHERE student_id = :s AND class_id = :c
        """),
        {"s": student_id, "c": class_id}
    ).fetchone()
    db.close()
    return bool(row and row[0])


def mark_class_pbl_completed(student_id: str, class_id: str):
    db = SessionLocal()
    db.execute(
        text("""
            INSERT INTO student_class_pbl
            (student_id, class_id, completed, completed_at)
            VALUES (:s, :c, TRUE, :t)
            ON CONFLICT (student_id, class_id)
            DO UPDATE SET
                completed = TRUE,
                completed_at = EXCLUDED.completed_at
        """),
        {
            "s": student_id,
            "c": class_id,
            "t": datetime.now(timezone.utc)
        }
    )
    db.commit()
    db.close()
