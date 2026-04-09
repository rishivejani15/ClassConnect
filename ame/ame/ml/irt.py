import math

def irt_logistic_update(theta, correct, difficulty, discrimination=1.0, lr=0.1):
    """
    True IRT-style logistic update (online gradient ascent)

    theta: student ability
    correct: True / False
    difficulty: item difficulty (b)
    discrimination: item discrimination (a)
    lr: learning rate
    """

    # 1. Predicted probability (logistic model)
    p = 1 / (1 + math.exp(-discrimination * (theta - difficulty)))

    # 2. Observed response
    r = 1.0 if correct else 0.0

    # 3. Gradient ascent update
    theta_new = theta + lr * discrimination * (r - p)

    mastery = 100 / (1 + math.exp(-theta_new))

    return round(mastery, 2),theta_new

