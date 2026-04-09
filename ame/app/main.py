import uvicorn
from fastapi import FastAPI
from ame.app.schemas import AMEEvent,AttendanceUpdate
from ame.app.logic import process_event, smart_recommendation,compute_severity
from ame.app.attendance_storage import upsert_attendance,get_attendance
from sqlalchemy import text
from ame.app.db import SessionLocal
from ame.app.priority import select_focus_concept
from ame.app.logic import is_class_ready_for_pbl
from ame.app.pbl_storage import mark_class_pbl_completed
from collections import defaultdict
import statistics

app = FastAPI(title="Adaptive Mastery Engine (AME)")

@app.get("/")
def health():
    return {"status": "Server is running"}

@app.post("/ame/update-event")
def update_event(event: AMEEvent):
    attendance = get_attendance(event.student_id,event.class_id)
  
    record = process_event(event)

    if event.event_type == "pbl" and event.score >= 60:
        mark_class_pbl_completed(
            event.student_id,
            event.class_id
        )
        
    return {
        "mastery": record["mastery_score"],
        "bkt_probability": record["bkt_probability"],
        "confidence": record["confidence"],
        "trend": record["trend_value"],
        "attendance_rate": attendance,
    }

@app.get("/ame/student/{student_id}")
def student_snapshot(student_id: str):
    db = SessionLocal()
    rows = db.execute(
        text("""
            SELECT concept_id, mastery_score, attempts
            FROM student_concept_mastery
            WHERE student_id = :s
        """),
        {"s": student_id}
    ).fetchall()
    db.close()

    return {
        r[0]: {
            "mastery_score": r[1],
            "attempts": r[2],
        }
        for r in rows
    }

@app.get("/ame/student/{student_id}/focus/{class_id}")
def student_focus(student_id: str, class_id: str):
    db = SessionLocal()

    rows = db.execute(
        text("""
            SELECT concept_id, mastery_score, confidence
            FROM student_concept_mastery
            WHERE student_id = :s AND class_id = :c
        """),
        {"s": student_id, "c": class_id}
    ).fetchall()

    db.close()

    # No mastery → diagnostic
    if not rows:
        return {
            "mode": "diagnostic",
            "message": "Complete diagnostic quiz to begin."
        }

    mastery_records = [
        {
            "concept_id": r[0],
            "mastery_score": r[1],
            "confidence": r[2]
        }
        for r in rows
    ]

    attendance = get_attendance(student_id, class_id)

    # 🔥 CLASS-WISE PBL CHECK (FIRST)
    if is_class_ready_for_pbl(student_id, class_id, mastery_records):
        return {
            "mode": "adaptive",
            "recommended_action": "pbl"
        }

    # 🔁 FALL BACK TO CONCEPT-LEVEL FLOW
    focus_concept = select_focus_concept(
        mastery_records,
        attendance_rate=attendance
    )

    focus_record = next(
        r for r in mastery_records if r["concept_id"] == focus_concept
    )

    action = smart_recommendation(
        mastery=focus_record["mastery_score"],
        confidence=focus_record["confidence"],
        trend=0,
        attendance_rate=attendance
    )

    return {
        "mode": "adaptive",
        "focus_concept": focus_concept,
        "mastery": round(focus_record["mastery_score"], 2),
        "confidence": round(focus_record["confidence"], 2),
        "recommended_action": action
    }

# Teacher's Side API
@app.post("/attendance/update")
def update_attendance(data:AttendanceUpdate):
    upsert_attendance(
        data.student_id,
        data.class_id,
        data.attendance_rate
    )
    return {"status": "attendance updated"}

@app.get("/ame/class/{class_id}/heatmap")
def class_heatmap(class_id:str):
    db = SessionLocal()
    rows = db.execute(
        text("""
             SELECT student_id, concept_id, mastery_score
             FROM student_concept_mastery
             where class_id = :c
             """),
        {"c":class_id}
    ).fetchall()
    db.close()
    
    heatmap = {}
    
    for student_id, concept_id, mastery in rows:
        heatmap.setdefault(concept_id,{})
        heatmap[concept_id][student_id] = round(mastery,2)
        
    return heatmap

# Teacher's side class level risk api

@app.get("/ame/class/{class_id}/risk")
def class_risk(class_id: str):
    db = SessionLocal()

    mastery_rows = db.execute(
        text("""
            SELECT student_id, concept_id, mastery_score, confidence
            FROM student_concept_mastery
            WHERE class_id = :c
        """),
        {"c": class_id}
    ).fetchall()

    attendance_rows = db.execute(
        text("""
            SELECT student_id, attendance_rate
            FROM student_attendance
            WHERE class_id = :c
        """),
        {"c": class_id}
    ).fetchall()

    db.close()

    attendance_map = {s: a for s, a in attendance_rows}

    risk_cases = []
    summary = {"HIGH": 0, "MEDIUM": 0, "LOW": 0}

    for student_id, concept_id, mastery, confidence in mastery_rows:
        attendance = attendance_map.get(student_id)

        # trend_delta is optional; we don’t persist trend
        trend_delta = 0  # safe default

        severity = compute_severity(
            mastery=mastery,
            confidence=confidence,
            attendance_rate=attendance,
            trend_delta=trend_delta
        )

        summary[severity] += 1

        if severity != "LOW":
            risk_cases.append({
                "student_id": student_id,
                "concept_id": concept_id,
                "severity": severity,
                "signals": {
                    "mastery": round(mastery, 2),
                    "confidence": round(confidence, 2),
                    "attendance": attendance
                }
            })

    return {
        "class_id": class_id,
        "risk_summary": summary,
        "risk_cases": risk_cases
    }

# Class Summary overall how class is doing
@app.get("/ame/class/{class_id}/summary")
def class_summary(class_id: str):
    db = SessionLocal()

    rows = db.execute(
        text("""
            SELECT mastery_score, confidence
            FROM student_concept_mastery
            WHERE class_id = :c
        """),
        {"c": class_id}
    ).fetchall()

    db.close()

    if not rows:
        return {
            "class_id": class_id,
            "students": 0,
            "avg_mastery": 0,
            "avg_confidence": 0,
            "mastery_distribution": {}
        }

    mastery_scores = [r[0] for r in rows]
    confidences = [r[1] for r in rows]

    distribution = {
        "<60": sum(1 for m in mastery_scores if m < 60),
        "60-80": sum(1 for m in mastery_scores if 60 <= m <= 80),
        ">80": sum(1 for m in mastery_scores if m > 80)
    }

    return {
        "class_id": class_id,
        "students": len(set(mastery_scores)),
        "avg_mastery": round(sum(mastery_scores) / len(mastery_scores), 2),
        "avg_confidence": round(sum(confidences) / len(confidences), 2),
        "mastery_distribution": distribution
    }

# Weak concepts
@app.get("/ame/class/{class_id}/concepts/weak")
def weak_concepts(class_id: str):
    db = SessionLocal()

    rows = db.execute(
        text("""
            SELECT concept_id,
                   AVG(mastery_score) as avg_mastery,
                   SUM(CASE WHEN mastery_score < 60 THEN 1 ELSE 0 END) as weak_count
            FROM student_concept_mastery
            WHERE class_id = :c
            GROUP BY concept_id
            ORDER BY avg_mastery ASC
        """),
        {"c": class_id}
    ).fetchall()

    db.close()

    return [
        {
            "concept_id": r[0],
            "avg_mastery": round(r[1], 2),
            "students_below_60": r[2]
        }
        for r in rows
    ]

# project completion
@app.get("/ame/class/{class_id}/pbl-status")
def pbl_status(class_id: str):
    db = SessionLocal()

    rows = db.execute(
        text("""
            SELECT student_id, completed
            FROM student_class_pbl
            WHERE class_id = :c
        """),
        {"c": class_id}
    ).fetchall()

    db.close()

    completed = [r[0] for r in rows if r[1]]
    pending = [r[0] for r in rows if not r[1]]

    return {
        "class_id": class_id,
        "completed": completed,
        "pending": pending
    }

# attendance impact api
@app.get("/ame/class/{class_id}/attendance-impact")
def attendance_impact(class_id: str):
    db = SessionLocal()

    rows = db.execute(
        text("""
            SELECT m.student_id,
                   m.concept_id,
                   m.mastery_score,
                   a.attendance_rate
            FROM student_concept_mastery m
            JOIN student_attendance a
              ON m.student_id = a.student_id
             AND m.class_id = a.class_id
            WHERE m.class_id = :c
        """),
        {"c": class_id}
    ).fetchall()

    db.close()

    from collections import defaultdict

    students = defaultdict(lambda: {
        "attendance_rate": None,
        "concepts": {},
        "total_mastery": 0,
        "count": 0
    })

    for student_id, concept_id, mastery, attendance in rows:
        s = students[student_id]
        s["attendance_rate"] = attendance
        s["concepts"][concept_id] = round(mastery, 2)
        s["total_mastery"] += mastery
        s["count"] += 1

    impact = {
        "low_attendance_low_mastery": [],
        "low_attendance_high_mastery": [],
        "high_attendance_low_mastery": [],
        "high_attendance_high_mastery": []
    }

    for student_id, data in students.items():
        avg_mastery = data["total_mastery"] / data["count"]
        attendance = data["attendance_rate"]

        payload = {
            "student_id": student_id,
            "attendance_rate": attendance,
            "avg_mastery": round(avg_mastery, 2),
            "concepts": data["concepts"]
        }

        if attendance < 0.6 and avg_mastery < 60:
            impact["low_attendance_low_mastery"].append(payload)
        elif attendance < 0.6:
            impact["low_attendance_high_mastery"].append(payload)
        elif avg_mastery < 60:
            impact["high_attendance_low_mastery"].append(payload)
        else:
            impact["high_attendance_high_mastery"].append(payload)

    return impact

# teacher intervention what should i do in next class
@app.get("/ame/class/{class_id}/intervention")
def class_intervention(class_id: str):
    db = SessionLocal()

    rows = db.execute(
        text("""
            SELECT concept_id, mastery_score, confidence
            FROM student_concept_mastery
            WHERE class_id = :c
        """),
        {"c": class_id}
    ).fetchall()

    db.close()

    if not rows:
        return {"message": "No data available"}

    # Aggregate
    from collections import defaultdict
    concept_stats = defaultdict(lambda: {"total": 0, "count": 0, "below_60": 0})

    for concept_id, mastery, confidence in rows:
        concept_stats[concept_id]["total"] += mastery
        concept_stats[concept_id]["count"] += 1
        if mastery < 60:
            concept_stats[concept_id]["below_60"] += 1

    concept_summary = []
    for cid, data in concept_stats.items():
        avg = data["total"] / data["count"]
        concept_summary.append({
            "concept_id": cid,
            "avg_mastery": round(avg, 2),
            "below_60": data["below_60"]
        })

    concept_summary.sort(key=lambda x: x["avg_mastery"])

    weakest = concept_summary[0]

    if weakest["avg_mastery"] < 60:
        intervention = "reteach"
    elif weakest["avg_mastery"] < 70:
        intervention = "group_activity"
    else:
        intervention = "peer_instruction"

    focus_concepts = [
        c["concept_id"] for c in concept_summary if c["avg_mastery"] < 65
    ]

    return {
        "class_id": class_id,
        "recommended_intervention": intervention,
        "focus_concepts": focus_concepts,
        "reason": {
            "weakest_concept": weakest["concept_id"],
            "avg_mastery": weakest["avg_mastery"],
            "students_below_60": weakest["below_60"]
        }
    }

# Admin level api
# institutional overview
@app.get("/admin/overview")
def admin_overview():
    db = SessionLocal()

    students = db.execute(text(
        "SELECT COUNT(DISTINCT student_id) FROM student_concept_mastery"
    )).scalar() or 0

    classes = db.execute(text(
        "SELECT COUNT(DISTINCT class_id) FROM student_concept_mastery"
    )).scalar() or 0

    mastery_rows = db.execute(text(
        "SELECT mastery_score FROM student_concept_mastery"
    )).fetchall()

    mastery = [r[0] for r in mastery_rows]

    distribution = {
        "<30": sum(1 for m in mastery if m < 30),
        "30-60": sum(1 for m in mastery if 30 <= m < 60),
        "60-80": sum(1 for m in mastery if 60 <= m <= 80),
        ">80": sum(1 for m in mastery if m > 80)
    }

    avg_mastery = round(sum(mastery) / len(mastery), 2) if mastery else 0

    attendance_rows = db.execute(text(
        "SELECT attendance_rate FROM student_attendance"
    )).fetchall()

    attendance = [r[0] for r in attendance_rows if r[0] is not None]
    avg_attendance = round(sum(attendance) / len(attendance), 2) if attendance else 0
    at_risk = sum(1 for a in attendance if a < 0.6)

    pbl_rows = db.execute(text(
        "SELECT class_id, completed FROM student_class_pbl"
    )).fetchall()

    eligible_classes = len(set(r[0] for r in pbl_rows))
    completed_classes = len(set(r[0] for r in pbl_rows if r[1]))

    db.close()

    return {
        "students": students,
        "classes": classes,
        "learning_health": {
            "avg_mastery": avg_mastery,
            "distribution": distribution
        },
        "attendance": {
            "avg_rate": avg_attendance,
            "at_risk_percent": round((at_risk / len(attendance)) * 100, 1) if attendance else 0
        },
        "pbl": {
            "eligible_classes": eligible_classes,
            "completed_classes": completed_classes
        }
    }

# Students Risk View (Admin-Safe)
@app.get("/admin/students")
def admin_students():
    db = SessionLocal()

    rows = db.execute(text("""
        SELECT
            m.student_id,
            m.class_id,
            AVG(m.mastery_score) AS avg_mastery,
            a.attendance_rate
        FROM student_concept_mastery m
        LEFT JOIN student_attendance a
          ON m.student_id = a.student_id
         AND m.class_id = a.class_id
        GROUP BY m.student_id, m.class_id, a.attendance_rate
    """)).fetchall()

    result = []

    for student_id, class_id, avg_mastery, attendance in rows:
        att = attendance if attendance is not None else 1.0

        if att < 0.6 and avg_mastery < 60:
            risk = "HIGH"
        elif avg_mastery < 60:
            risk = "MEDIUM"
        else:
            risk = "LOW"

        result.append({
            "student_id": student_id,
            "class_id": class_id,
            "attendance_status": "CRITICAL" if att < 0.6 else "NORMAL",
            "learning_risk": risk,
            "intervention_flag": risk != "LOW"
        })

    db.close()
    return result


# 3️⃣ Class Load & Health (Core Admin View)
@app.get("/admin/classes")
def admin_classes():
    db = SessionLocal()

    rows = db.execute(text("""
        SELECT class_id, student_id, mastery_score
        FROM student_concept_mastery
    """)).fetchall()

    class_map = defaultdict(lambda: {
        "students": set(),
        "scores": []
    })

    for class_id, student_id, mastery in rows:
        class_map[class_id]["students"].add(student_id)
        class_map[class_id]["scores"].append(mastery)

    result = []
    for class_id, data in class_map.items():
        scores = data["scores"]
        students = data["students"]

        result.append({
            "class_id": class_id,
            "student_ids": list(students),
            "student_count": len(students),
            "avg_mastery": round(sum(scores) / len(scores), 2),
            "mastery_variance": round(
                statistics.pvariance(scores), 2
            ) if len(scores) > 1 else 0,
            "reinforcement_pressure":
                "HIGH" if sum(1 for s in scores if s < 60) > len(scores) * 0.4
                else "NORMAL"
        })

    db.close()
    return result


# 4️⃣ Attendance × Learning Matrix (System Insight)
@app.get("/admin/insights/attendance-learning")
def admin_attendance_learning():
    db = SessionLocal()

    rows = db.execute(text("""
        SELECT
            m.student_id,
            m.class_id,
            AVG(m.mastery_score) AS avg_mastery,
            a.attendance_rate
        FROM student_concept_mastery m
        JOIN student_attendance a
          ON m.student_id = a.student_id
         AND m.class_id = a.class_id
        GROUP BY m.student_id, m.class_id, a.attendance_rate
    """)).fetchall()

    impact = {
        "low_attendance_low_mastery": [],
        "low_attendance_high_mastery": [],
        "high_attendance_low_mastery": [],
        "high_attendance_high_mastery": []
    }

    for student_id, class_id, mastery, attendance in rows:
        payload = {
            "student_id": student_id,
            "class_id": class_id,
            "avg_mastery": round(mastery, 2),
            "attendance_rate": attendance
        }

        if attendance < 0.6 and mastery < 60:
            impact["low_attendance_low_mastery"].append(payload)
        elif attendance < 0.6:
            impact["low_attendance_high_mastery"].append(payload)
        elif mastery < 60:
            impact["high_attendance_low_mastery"].append(payload)
        else:
            impact["high_attendance_high_mastery"].append(payload)

    db.close()
    return impact


# 5️⃣ Adaptive Loop Health (System Integrity)
@app.get("/admin/insights/adaptive-health")
def admin_adaptive_health():
    db = SessionLocal()

    rows = db.execute(text("""
        SELECT mastery_score, confidence
        FROM student_concept_mastery
    """)).fetchall()

    health = {
        "reinforcement_looped": 0,
        "practice_dominant": 0,
        "explanation_heavy": 0,
        "pbl_ready": 0
    }

    for mastery, confidence in rows:
        if mastery < 50:
            health["reinforcement_looped"] += 1
        elif mastery < 70:
            health["practice_dominant"] += 1
        elif confidence < 60:
            health["explanation_heavy"] += 1
        else:
            health["pbl_ready"] += 1

    db.close()
    return health

# 6️⃣ PBL System Health
@app.get("/admin/insights/pbl")
def admin_pbl_health():
    db = SessionLocal()

    rows = db.execute(text("""
        SELECT class_id, completed
        FROM student_class_pbl
    """)).fetchall()

    eligible = len(set(r[0] for r in rows))
    completed = len(set(r[0] for r in rows if r[1]))

    db.close()

    return {
        "eligible_classes": eligible,
        "completed_classes": completed,
        "completion_rate": round(completed / eligible, 2) if eligible else 0
    }

# trend admin
@app.get("/admin/trends")
def admin_trends(days: int = 30):
    db = SessionLocal()

    rows = db.execute(text("""
        SELECT date, avg_mastery, avg_attendance, pbl_completion_rate
        FROM admin_daily_metrics
        ORDER BY date DESC
        LIMIT :d
    """), {"d": days}).fetchall()

    db.close()

    return [
        {
            "date": r[0],
            "avg_mastery": r[1],
            "avg_attendance": r[2],
            "pbl_completion_rate": r[3]
        }
        for r in reversed(rows)
    ]

@app.get("/admin/alerts")
def get_admin_alerts():
    db = SessionLocal()

    rows = db.execute(text("""
        SELECT id, alert_type, message, created_at
        FROM admin_alerts
        WHERE acknowledged = FALSE
        ORDER BY created_at DESC
    """)).fetchall()

    db.close()

    return [
        {
            "id": r[0],
            "type": r[1],
            "message": r[2],
            "created_at": r[3]
        }
        for r in rows
    ]

@app.post("/admin/alerts/{alert_id}/ack")
def acknowledge_admin_alert(alert_id: int):
    db = SessionLocal()

    db.execute(text("""
        UPDATE admin_alerts
        SET acknowledged = TRUE
        WHERE id = :id
    """), {"id": alert_id})

    db.commit()
    db.close()

    return {"status": "acknowledged"}

import csv
from io import StringIO
from fastapi.responses import Response

@app.get("/admin/export/csv")
def export_admin_csv():
    db = SessionLocal()

    rows = db.execute(text("""
        SELECT
            date,
            avg_mastery,
            avg_attendance,
            students,
            classes,
            pbl_completion_rate
        FROM admin_daily_metrics
        ORDER BY date DESC
    """)).fetchall()

    db.close()

    output = StringIO()
    writer = csv.writer(output)

    writer.writerow([
        "Date",
        "Avg Mastery",
        "Avg Attendance",
        "Students",
        "Classes",
        "PBL Completion Rate"
    ])

    for r in rows:
        writer.writerow([
            r[0],
            round(r[1], 2) if r[1] is not None else "",
            round(r[2], 2) if r[2] is not None else "",
            r[3],
            r[4],
            round(r[5], 2) if r[5] is not None else ""
        ])

    csv_data = output.getvalue()

    return Response(
        content=csv_data,
        media_type="text/csv",
        headers={
            "Content-Disposition": "attachment; filename=admin_report.csv",
            "Cache-Control": "no-cache",
            "Pragma": "no-cache"
        }
    )



if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port = 7860
    )