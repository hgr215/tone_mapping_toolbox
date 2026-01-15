
import numpy as np
from .cubic_besizer import cubic_besizer
from .interp1_clip import interp1_clip

def glb_shadow_curve(gain, num, knee_point):
    P1 = np.array([0.3, 0.3 * gain]) * knee_point
    P2 = np.array([knee_point * 0.4, knee_point * 0.4])
    control_points = np.array([
        [0, 0],
        P1,
        P2,
        [knee_point, knee_point]
    ])
    curvex, curvey = cubic_besizer(control_points, 500)
    curvex = np.append(curvex, 1.0)
    curvey = np.append(curvey, 1.0)
    axis_x = np.linspace(0, 1, num)
    curve = interp1_clip(curvex, curvey, axis_x)
    return curve
