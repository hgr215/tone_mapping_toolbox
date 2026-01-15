
import numpy as np

def cubic_besizer(controlPoints, numPoints):
    """
    生成三阶贝塞尔曲线
    controlPoints: 4x2 numpy数组，每行是一个控制点 [x, y]
    numPoints: 曲线上的点数
    返回: curvex, curvey (均为1D numpy数组)
    """
    controlPoints = np.asarray(controlPoints)
    if controlPoints.shape != (4, 2):
        raise ValueError('controlPoints 必须是一个 4x2 的矩阵')
    if numPoints < 2:
        raise ValueError('numPoints 必须大于或等于 2')

    P0, P1, P2, P3 = controlPoints
    t = np.linspace(0, 1, numPoints)
    bezierCurve = (
        (1 - t)[:, None] ** 3 * P0 +
        3 * (1 - t)[:, None] ** 2 * t[:, None] * P1 +
        3 * (1 - t)[:, None] * t[:, None] ** 2 * P2 +
        t[:, None] ** 3 * P3
    )
    curvex = bezierCurve[:, 0]
    curvey = bezierCurve[:, 1]
    return curvex, curvey
