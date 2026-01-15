
import numpy as np
from .get_srgb_lut import get_srgb_lut
from .interp1_clip import interp1_clip

def do_srgb_gam(inp):
    srgb_lut = get_srgb_lut()
    x = np.linspace(0, 1, 256)
    return interp1_clip(x, srgb_lut, inp)
