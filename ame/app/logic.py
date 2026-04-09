from ame.app.config import WEIGHTS
from ame.app.storage import get_mastery, upsert_mastery
from ame.ml.bkt import update_bkt
from ame.ml.irt import irt_logistic_update
from ame.ml.predictors import trend_score
from ame.app.units import CLASS_UNIT_MAP
from ame.app.pbl_storage import is_class_pbl_completed

def update_mastery(old, score, weight):
    return round(old * (1 - weight) + score * weight, 2)

def process_event(event):
    record = get_mastery(event.student_id, event.concept_id,event.class_id)

    if record is None:
        record = {
        "mastery_score": 50.0,
        "attempts": 0,
        "confidence": 0.0,
        "bkt_probability": 0.5,
        "theta": 0.0,
        "trend_value": 50.0
        }
    else:
        record.setdefault("confidence", 0.0)
        record.setdefault("bkt_probability", 0.5)
        record.setdefault("theta", 0.0)
        record.setdefault("trend_value", record["mastery_score"])
    

    old_score = record["mastery_score"]
    weight = WEIGHTS.get(event.event_type, 0.1)
    
    # 🔒 Cap weak signals
    if event.event_type == "engagement":
        weight = min(weight, 0.1)
    
    correct = event.score >= 60
    
    irt_mastery, record["theta"] = irt_logistic_update(
    theta=record["theta"],
    correct=correct,
    difficulty=0.5
)
    
    new_score = update_mastery(old_score,irt_mastery,weight)
    
    record["bkt_probability"] = update_bkt(
        record["bkt_probability"],
        correct
    )
    
    hybrid_mastery = round(
        0.7 * new_score + 0.3 * (record["bkt_probability"] * 100),
        2
    )

    record["mastery_score"] = hybrid_mastery
    record["trend_value"] = trend_score(
        record["trend_value"],
        hybrid_mastery
    )
    record["attempts"] += 1
    record["confidence"] = round(min(1.0, record["attempts"] / 10), 2)

    upsert_mastery(event.student_id, event.concept_id, event.class_id, record)

    return record

def smart_recommendation(mastery, confidence, trend, attendance_rate=None):
    if mastery < 60 and attendance_rate and attendance_rate < 0.6:
        return "attendance_recap_and_support"

    if mastery < 60:
        return "assign_adaptive_practice"

    if mastery >= 60 and confidence < 0.4:
        return "reinforcement_activity"

    if trend < mastery and (mastery - trend) > 5:
        return "early_intervention_alert"

    if mastery > 80:
        return "peer_explanation"

    return "normal_progress"

def compute_severity(mastery, confidence, attendance_rate=None, trend_delta=0):
    """
    Returns: HIGH | MEDIUM | LOW
    """

    # HIGH RISK
    if mastery < 60 and (
        (attendance_rate is not None and attendance_rate < 0.6)
        or confidence < 0.4
        or trend_delta > 5
    ):
        return "HIGH"

    # MEDIUM RISK
    if mastery < 70 and confidence < 0.6:
        return "MEDIUM"

    return "LOW"



def is_class_ready_for_pbl(
    student_id: str,
    class_id: str,
    mastery_records: list
) -> bool:

    if is_class_pbl_completed(student_id, class_id):
        return False

    mastery_map = {
        r["concept_id"]: r["mastery_score"]
        for r in mastery_records
    }

    scores = list(mastery_map.values())

    # 🚫 NEW: require breadth before PBL
    MIN_CONCEPTS_FOR_PBL = 3
    if len(scores) < MIN_CONCEPTS_FOR_PBL:
        return False

    avg_mastery = sum(scores) / len(scores)
    min_mastery = min(scores)

    return avg_mastery >= 70 and min_mastery >= 60
