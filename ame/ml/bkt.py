def update_bkt(p_L, correct, p_T=0.15, p_G=0.2, p_S=0.1):
    if correct:
        p_L_given = (p_L * (1 - p_S)) / (
            p_L * (1 - p_S) + (1 - p_L) * p_G
        )
    else:
        p_L_given = (p_L * p_S) / (
            p_L * p_S + (1 - p_L) * (1 - p_G)
        )

    p_L_new = p_L_given + (1 - p_L_given) * p_T
    return round(p_L_new, 3)
