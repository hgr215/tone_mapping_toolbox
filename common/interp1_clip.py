
import numpy as np

def interp1_clip(x, y, xi):
    # 线性插值，超出范围时用边界值
    xi = np.asarray(xi)
    y_interp = np.interp(xi, x, y, left=y[0], right=y[-1])
    return y_interp
