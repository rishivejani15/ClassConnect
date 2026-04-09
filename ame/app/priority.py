def compute_priority(mastery, confidence, attendance_rate=None):
    priority = 100 - mastery
    priority += (1 - confidence) * 20

    if attendance_rate is not None and attendance_rate < 0.6:
        priority += 15

    return round(priority, 2)


def select_focus_concept(mastery_records, attendance_rate=None):
    if not mastery_records:
        return None

    scored = []

    for r in mastery_records:
        score = compute_priority(
            mastery=r["mastery_score"],
            confidence=r["confidence"],
            attendance_rate=attendance_rate
        )
        scored.append((score, r["concept_id"]))

    scored.sort(reverse=True)
    return scored[0][1]
