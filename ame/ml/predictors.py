def trend_score(prev, current, alpha=0.3):
    return alpha * current + (1 - alpha) * prev
