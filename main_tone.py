
import os
import numpy as np
import cv2
from glob import glob
from scipy.io import loadmat
from skimage.color import rgb2gray
from tone_operator.glb_tone import glb_tone
from common.do_srgb_degam import do_srgb_degam
from common.do_srgb_gam import do_srgb_gam
from common.clip import clip
import matplotlib.pyplot as plt

# 需要你实现的函数
# def do_srgb_degam(img): pass
# def do_srgb_gam(img): pass
# def clip(img, a, b): return np.clip(img, a, b)

def demosaic(raw, pattern='rggb'):
    # raw为2D numpy数组，pattern仅支持'rggb'
    if pattern.lower() == 'rggb':
        return cv2.cvtColor(raw, cv2.COLOR_BayerRG2RGB)
    else:
        raise NotImplementedError(f"Unsupported Bayer pattern: {pattern}")
# def guided_filter_upsampling(*args, **kwargs): pass
# def llf_tone(gray_in, gain, dbg): pass
# def glb_tone(gray_in, gain, dbg): pass
# def dgain_tone(gray_in, gain, dbg): pass
# def guided_filter_tone(gray_in, gain, dbg): pass
# def grid3d_tone(gray_in, gain, dbg): pass
# def no_tone(gray_in, gain, dbg): pass


def do_shadow_gain_hue_protect(file_path, f, gain, w, h, dbg_path, gf_us_en):
    sz_ds = (1536, 2048)
    _, ext = os.path.splitext(file_path)
    if ext == '.raw':
        raw_data = np.fromfile(file_path, dtype=np.uint16)
        stride = raw_data.size // h
        raw_data = raw_data.reshape((h, stride))
        # 2. Demosaic
        rgb_in = demosaic(raw_data, 'rggb')
        rgb_in = rgb_in.astype(np.float64) / 65535
    elif ext == '.tif':
        rgb_in = cv2.imread(file_path, cv2.IMREAD_UNCHANGED)
        rgb_in = rgb_in.astype(np.float64) / 65535
    else:
        rgb_in = cv2.imread(file_path)
        rgb_in = rgb_in.astype(np.float64) / 255

    # 只显示rgb_in和rgb_out
    plt.figure(); plt.title('rgb_in'); plt.imshow(np.clip(rgb_in,0,1)); plt.show()

    rgb_ds = cv2.resize(rgb_in, sz_ds[::-1])
    rgb_lin = do_srgb_degam(rgb_ds)
    gray_image = rgb2gray(rgb_ds)

    import time
    t_start = time.time()
    if gf_us_en:
        scale = 4
        eps_gf = 1e-8
        radius = 5
        gray_in_ds = cv2.resize(gray_image, (gray_image.shape[1] // scale, gray_image.shape[0] // scale), interpolation=cv2.INTER_LINEAR)
        gray_out_ds = f(gray_in_ds, gain, dbg_path)
        gray_out = guided_filter_upsampling(gray_in_ds, gray_out_ds, gray_image, radius, eps_gf, dbg_path)
        if dbg_path:
            os.makedirs(dbg_path, exist_ok=True)
            cv2.imwrite(os.path.join(dbg_path, 'gray_in_full.jpg'), (gray_image * 255).astype(np.uint8))
            cv2.imwrite(os.path.join(dbg_path, 'gray_in_ds.jpg'), (gray_in_ds * 255).astype(np.uint8))
            cv2.imwrite(os.path.join(dbg_path, 'gray_out_ds.jpg'), (gray_out_ds * 255).astype(np.uint8))
            cv2.imwrite(os.path.join(dbg_path, 'gray_out_dsus.jpg'), (cv2.resize(gray_out_ds, (gray_out_ds.shape[1]*scale, gray_out_ds.shape[0]*scale), interpolation=cv2.INTER_LINEAR) * 255).astype(np.uint8))
            cv2.imwrite(os.path.join(dbg_path, 'gray_out_gfus.jpg'), (gray_out * 255).astype(np.uint8))
    else:
        gray_out = f(gray_image, gain, dbg_path)
    elapsed_time = time.time() - t_start
    print(f'Processing time: {elapsed_time:.2f} seconds')

    gray_in_lin = do_srgb_degam(gray_image)
    gray_out_lin = do_srgb_degam(gray_out)
    eps = 1e-8
    k = (gray_out_lin + eps) / (gray_in_lin + eps)
    rgb_out_lin = np.zeros_like(rgb_lin)
    for c in range(3):
        rgb_out_lin[..., c] = rgb_lin[..., c] * k
    rgb_out_lin = clip(rgb_out_lin, 0, 1)
    rgb_out = do_srgb_gam(rgb_out_lin)
    plt.figure(); plt.title('rgb_out'); plt.imshow(np.clip(rgb_out,0,1)); plt.show()
    return rgb_out, rgb_ds

if __name__ == '__main__':
    directory_path = 'data'
    sz = (2048, 1536)
    shadow_gain = 4.0
    enable_dbg = 1
    gf_us_en = 0
    method = 'glb'

    raw_files = glob(os.path.join(directory_path, '*.raw'))
    tif_files = glob(os.path.join(directory_path, '*.tif'))
    jpg_files = glob(os.path.join(directory_path, '*.jpg'))
    files = raw_files + tif_files + jpg_files
    h, w = sz[1], sz[0]

    output_dir = os.path.join(directory_path, 'results')
    os.makedirs(output_dir, exist_ok=True)

    for i in range(1, len(files), 2):
        raw_file_path = files[i]
        print(f'Processing file: {os.path.basename(raw_file_path)}')
        file_name = os.path.splitext(os.path.basename(raw_file_path))[0]
        dbg_dir = os.path.join(output_dir, f'{file_name}_dbg')
        if enable_dbg and not os.path.exists(dbg_dir):
            os.makedirs(dbg_dir)
        dbg_path = dbg_dir if enable_dbg else ''

        # 算法选择
        if method == 'llf':
            handle = llf_tone
        elif method == 'glb':
            handle = glb_tone
        elif method == 'dgain':
            handle = dgain_tone
        elif method == 'gf':
            handle = guided_filter_tone
        elif method == '3dgrid':
            handle = grid3d_tone
        elif method == 'notone':
            handle = no_tone
        else:
            raise ValueError(f'Unknown method: {method}')

        rgb_out, rgb_in = do_shadow_gain_hue_protect(raw_file_path, handle, shadow_gain, w, h, dbg_path, gf_us_en)

        output_file_in = os.path.join(output_dir, f'{file_name}_in.jpg')

        cv2.imwrite(output_file_in, (rgb_in * 255).astype(np.uint8), [int(cv2.IMWRITE_JPEG_QUALITY), 100])
        print(f'Saved processed image: {output_file_in}')

        gf_tag = '_gfus' if gf_us_en else ''
        output_file_out = os.path.join(output_dir, f'{file_name}_{method}{gf_tag}.jpg')

        cv2.imwrite(output_file_out, (rgb_out * 255).astype(np.uint8), [int(cv2.IMWRITE_JPEG_QUALITY), 100])
        print(f'Saved processed image: {output_file_out}')