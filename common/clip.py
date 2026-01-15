
import numpy as np

def clip(x, lo, hi):
    x = np.maximum(x, lo)
    x = np.minimum(x, hi)
    return x
