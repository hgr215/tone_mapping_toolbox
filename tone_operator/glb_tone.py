import numpy as np
import os
import matplotlib.pyplot as plt
from common.do_srgb_degam import do_srgb_degam
from common.do_srgb_gam import do_srgb_gam
from common.clip import clip
from common.glb_shadow_curve import glb_shadow_curve

def glb_tone(gray_in, gain=2.5, dbg_path=''):
    # 需要你实现的函数
    def clip(x, a, b): return np.clip(x, a, b)
    def interp1_clip(x, y, xi):
        # 线性插值并裁剪到边界
        return np.interp(xi, x, y, left=y[0], right=y[-1])

    in_lin = do_srgb_degam(gray_in)
    in_lin = clip(in_lin, 0, 1)
    x = np.linspace(0, 1, 257)

    knee_srgb = do_srgb_degam(0.5)
    print(f'knee point {knee_srgb}')
    curve = glb_shadow_curve(gain, 257, knee_srgb)

    out_lin = interp1_clip(x, curve, in_lin)
    gray_out = do_srgb_gam(out_lin)

    if dbg_path:
        os.makedirs(dbg_path, exist_ok=True)
        I_axis = np.linspace(0, 1, len(curve))
        plt.figure()
        plt.plot(I_axis, curve)
        plt.axis([0, 1, 0, 1])
        plt.title('GLB Curve')
        plt.xlabel('I')
        plt.ylabel('GLB Curve')
        plt.savefig(os.path.join(dbg_path, 'glb_curve.png'))
        plt.close()
    return gray_out