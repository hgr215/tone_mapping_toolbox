import numpy as np
import cv2
import os
import matplotlib.pyplot as plt
from common.do_srgb_degam import do_srgb_degam
from common.do_srgb_gam import do_srgb_gam
from common.clip import clip
from common.glb_shadow_curve import glb_shadow_curve
from common.cubic_besizer import cubic_besizer


# =====================================================================
# Helper: Bezier control-point generators
# =====================================================================

def _bezier_ctrl_left(x_target, y_target, k_th):
    """
    Cubic Bezier control points for the LEFT transition:
        (0, 0)  →  (x_target, y_target)

    C1 continuity at the target: P2 lies on the line with slope k_th
    extending backwards from P3, so the curve blends smoothly into the
    line segment that follows.

    Returns (4, 2) ndarray  [P0, P1, P2, P3].
    """
    P0 = np.array([0.0, 0.0])
    P3 = np.array([x_target, y_target])

    # P2: back along the line's tangent (1, k_th) to guarantee C1 at P3
    d2 = x_target * 0.3
    P2 = np.array([x_target - d2, y_target - k_th * d2])
    P2 = np.maximum(P2, 0)                     # stay inside [0,1]²

    # P1: lift off gently from (0,0); approximate slope ~ y_target/(2*x_target)
    P1 = np.array([x_target * 0.3, y_target * 0.5])
    P1 = np.maximum(P1, 0)

    return np.stack([P0, P1, P2, P3])


def _bezier_ctrl_right(x_start, y_start, k_th):
    """
    Cubic Bezier control points for the RIGHT transition:
        (x_start, y_start)  →  (1, 1)

    C1 continuity at the start: P1 extends forward from P0 along
    slope k_th.  At (1,1) the curve arrives with slope ≈ 1 so that
    highlight contrast stays natural.

    Returns (4, 2) ndarray  [P0, P1, P2, P3].
    """
    P0 = np.array([x_start, y_start])
    P3 = np.array([1.0, 1.0])

    # P1: forward from P0 along slope k_th (C1 at the junction)
    d1 = (1.0 - x_start) * 0.3
    P1 = np.array([x_start + d1, y_start + k_th * d1])
    P1 = np.minimum(P1, 1)

    # P2: back from P3 so that the curve arrives at (1,1) with slope ≈ 1
    d2 = (1.0 - x_start) * 0.3
    P2 = np.array([1.0 - d2, 1.0 - d2])

    return np.stack([P0, P1, P2, P3])


# =====================================================================
# Helper: vectorised application of 16 local curves
# =====================================================================

def apply_local_curves(gray_in, f_local, h_blurred):
    """
    Apply 16 per-bin local curves to the image via CLAHE-like interpolation.

    1. Bilinearly upsample the blurred 32×32 histogram to full resolution.
    2. Normalise so each pixel's 16 histogram weights sum to 1.
    3. Look up every pixel's value in all 16 curves at once (vectorised).
    4. Weighted sum:  out[p] = Σ_b w_b[p] · f_b( in[p] ).

    Args:
        gray_in:   (H, W) float32/64 image in [0, 1]
        f_local:   (n_bins, n_curve_pts) per-bin local curves
        h_blurred: (n_mesh, n_mesh, n_bins) blurred histogram

    Returns:
        gray_out:  (H, W) tone-mapped image in [0, 1]
    """
    H, W = gray_in.shape
    n_bins, n_curve_pts = f_local.shape

    # (a) Bilinear upsample of the 32×32 histogram to full resolution
    h_interp = cv2.resize(h_blurred, (W, H), interpolation=cv2.INTER_LINEAR)

    # (b) Normalise per-pixel histogram weights
    h_sum = np.sum(h_interp, axis=2, keepdims=True)
    h_sum[h_sum == 0] = 1.0
    h_interp = h_interp / h_sum

    # (c) Map each pixel value to a curve index (0 .. n_curve_pts-1)
    gray_idx = np.round(gray_in * (n_curve_pts - 1)).astype(np.int32)
    gray_idx = np.clip(gray_idx, 0, n_curve_pts - 1)

    # (d) f_local[:, gray_idx.ravel()]   →  n_bins × (H·W)
    #     Reshape  →  H × W × n_bins
    f_at_pixels = f_local[:, gray_idx.ravel()]
    f_3d = f_at_pixels.T.reshape(H, W, n_bins)

    # (e) Weighted sum across bins
    gray_out = np.sum(h_interp * f_3d, axis=2)
    return np.clip(gray_out, 0, 1)


# =====================================================================
# Main operator
# =====================================================================

def ald_tone(gray_in, gain=2.5, dbg_path=''):
    """
    ALD (Adaptive Local Dimming) tone mapping operator.

    Standard interface: takes gamma-domain gray image and gain,
    returns gamma-domain tone-mapped gray image.

    Core idea:
      The global shadow curve f(x) brightens the image but may flatten
      contrast in some brightness zones (where its local slope k_i
      is less than the Weber threshold k_th).  ALD detects these "flat"
      bins and replaces the curve locally with a steeper line, using
      cubic Bezier segments to smoothly reconnect to (0,0) and (1,1).

      A local histogram (32×32 mesh × 16 bins) is blurred and bilinearly
      interpolated to weight the 16 per-bin curves at every pixel,
      analogous to how CLAHE blends local equalisation transforms.
    """
    # ---- parameters ----
    n_mesh = 32
    n_bins = 16
    blur_ksize = 7
    n_curve_pts = 257
    debug = bool(dbg_path)

    H, W = gray_in.shape

    # 1. Global tone curve ------------------------------------------------
    knee_srgb = do_srgb_degam(0.5)
    f_global = glb_shadow_curve(gain, n_curve_pts, knee_srgb)
    x_curve = np.linspace(0, 1, n_curve_pts)

    def interp1_clip_local(x, y, xi):
        return np.interp(np.clip(xi, x[0], x[-1]), x, y, left=y[0], right=y[-1])

    # 2. Local histogram:  n_mesh × n_mesh × n_bins ----------------------
    bin_edges = np.linspace(0, 1, n_bins + 1)
    local_hist = np.zeros((n_mesh, n_mesh, n_bins), dtype=np.float64)
    cell_h = H / n_mesh
    cell_w = W / n_mesh

    for row in range(n_mesh):
        r_start = round(row * cell_h)
        r_end = round((row + 1) * cell_h)
        for col in range(n_mesh):
            c_start = round(col * cell_w)
            c_end = round((col + 1) * cell_w)
            cell_data = gray_in[r_start:r_end, c_start:c_end]
            local_hist[row, col, :], _ = np.histogram(cell_data, bins=bin_edges)

    # 3-6. Build 16 per-bin local curves f_i(x) --------------------------
    x_intv = np.linspace(0, 1, n_bins + 1)
    f_local = np.zeros((n_bins, n_curve_pts), dtype=np.float64)
    k_i_vals = np.zeros(n_bins)
    k_th_vals = np.zeros(n_bins)

    for i in range(n_bins):
        x_start = x_intv[i]
        x_end = x_intv[i + 1]
        x_mid = (x_start + x_end) / 2.0

        f_start = interp1_clip_local(x_curve, f_global, x_start)
        f_end = interp1_clip_local(x_curve, f_global, x_end)
        f_mid = interp1_clip_local(x_curve, f_global, x_mid)

        k_i = (f_end - f_start) / (x_end - x_start)
        k_th = f_mid / max(x_mid, 1e-6)

        k_i_vals[i] = k_i
        k_th_vals[i] = k_th

        if k_i >= k_th:
            f_local[i, :] = f_global
        else:
            # ---- line segment inside this bin ----
            y_start_line = np.clip(f_mid - k_th * (x_mid - x_start), 0, 1)
            y_end_line = np.clip(f_mid + k_th * (x_end - x_mid), 0, 1)

            n_line = 1024
            x_line = np.linspace(x_start, x_end, n_line)
            y_line = np.clip(f_mid + k_th * (x_line - x_mid), 0, 1)

            x_all, y_all = [], []

            # ---- left Bezier: (0,0) → (x_start, y_start_line) ----
            if x_start > 0:
                ctrl = _bezier_ctrl_left(x_start, y_start_line, k_th)
                bx, by = cubic_besizer(ctrl, 100)
                mask = bx < x_start
                x_all.extend(bx[mask].tolist())
                y_all.extend(by[mask].tolist())

            # ---- line segment ----
            x_all.extend(x_line.tolist())
            y_all.extend(y_line.tolist())

            # ---- right Bezier: (x_end, y_end_line) → (1,1) ----
            if x_end < 1:
                ctrl = _bezier_ctrl_right(x_end, y_end_line, k_th)
                bx, by = cubic_besizer(ctrl, 100)
                mask = bx > x_end
                x_all.extend(bx[mask].tolist())
                y_all.extend(by[mask].tolist())

            # ---- resample to uniform grid ----
            x_all = np.array(x_all)
            y_all = np.array(y_all)
            order = np.argsort(x_all)
            x_all, y_all = x_all[order], y_all[order]
            _, unique_idx = np.unique(x_all, return_index=True)
            x_all, y_all = x_all[unique_idx], y_all[unique_idx]
            f_local[i, :] = interp1_clip_local(x_all, y_all, x_curve)

    # 7. Spatially blur local histogram (xy only) ------------------------
    blur_sigma = blur_ksize / 3.0
    kernel_1d = cv2.getGaussianKernel(blur_ksize, blur_sigma)
    h_kernel = kernel_1d @ kernel_1d.T
    h_blurred = np.zeros_like(local_hist)
    for b in range(n_bins):
        h_blurred[:, :, b] = cv2.filter2D(local_hist[:, :, b], -1, h_kernel,
                                           borderType=cv2.BORDER_REPLICATE)

    # 8. Apply curves via CLAHE-like interpolation -----------------------
    gray_out = apply_local_curves(gray_in, f_local, h_blurred)

    # ===================================================================
    # Debug outputs
    # ===================================================================
    if debug:
        os.makedirs(dbg_path, exist_ok=True)

        # (a) All curves overlaid: global in black, per-bin in dashed
        plt.figure()
        plt.plot(x_curve, f_global, 'k-', linewidth=2, label='Global')
        for ii in range(n_bins):
            plt.plot(x_curve, f_local[ii, :], '--', linewidth=0.5)
        plt.axis([0, 1, 0, 1])
        plt.title('ALD Curves (black = global, dashed = local f_i)')
        plt.xlabel('Input'); plt.ylabel('Output')
        plt.savefig(os.path.join(dbg_path, 'ald_curves.png'))
        plt.close()

        # (a2) 16 local curves in a 4×4 subplot grid
        fig, axes = plt.subplots(4, 4, figsize=(14, 12))
        fig.suptitle('16 Local Curves f_i(x) — each with global reference',
                     fontsize=13, y=1.01)
        for ii in range(n_bins):
            ax = axes[ii // 4, ii % 4]
            ax.plot(x_curve, f_global, 'gray', linewidth=1.0, alpha=0.6,
                    label='Global')
            ax.plot(x_curve, f_local[ii, :], 'b-', linewidth=1.2,
                    label=f'f_{ii}')
            ax.set_xlim(0, 1); ax.set_ylim(0, 1)
            ax.set_title(f'Bin {ii}  (k_i={k_i_vals[ii]:.2f}, '
                         f'k_th={k_th_vals[ii]:.2f}, '
                         f'modified={"Y" if k_i_vals[ii] < k_th_vals[ii] else "N"})',
                         fontsize=8)
            ax.set_aspect('equal')
            if ii == 0:
                ax.legend(fontsize=7)
        plt.tight_layout()
        plt.savefig(os.path.join(dbg_path, 'ald_local_curves_4x4.png'),
                    dpi=150, bbox_inches='tight')
        plt.close()

        # (b) Mesh overlay on input
        _, ax = plt.subplots()
        ax.imshow(gray_in, cmap='gray')
        for row in range(n_mesh):
            for col in range(n_mesh):
                r_start = round(row * cell_h)
                c_start = round(col * cell_w)
                rect = plt.Rectangle((c_start, r_start), cell_w, cell_h,
                                     fill=False, edgecolor='r', linewidth=0.5)
                ax.add_patch(rect)
        ax.set_title('Mesh Grid Overlay')
        plt.savefig(os.path.join(dbg_path, 'ald_mesh.png'))
        plt.close()

        # (c) Raw histogram total count
        plt.figure()
        plt.imshow(np.sum(local_hist, axis=2), aspect='auto')
        plt.colorbar()
        plt.title('Histogram total count per mesh cell')
        plt.savefig(os.path.join(dbg_path, 'ald_hist_mesh.png'))
        plt.close()

        # (d) Blurred histogram total count
        plt.figure()
        plt.imshow(np.sum(h_blurred, axis=2), aspect='auto')
        plt.colorbar()
        plt.title('Blurred histogram total count per mesh cell')
        plt.savefig(os.path.join(dbg_path, 'ald_hist_blur.png'))
        plt.close()

        # (e) Slope comparison bar chart
        plt.figure()
        x_bins = np.arange(1, n_bins + 1)
        width = 0.35
        plt.bar(x_bins - width / 2, k_i_vals, width, label='k_i')
        plt.bar(x_bins + width / 2, k_th_vals, width, label='k_th')
        plt.legend()
        plt.title('Slope comparison per bin')
        plt.xlabel('Bin index'); plt.ylabel('Slope')
        plt.savefig(os.path.join(dbg_path, 'ald_slope.png'))
        plt.close()

        # (f) Histogram slice at middle mesh row
        mid_row = n_mesh // 2
        plt.figure()
        plt.imshow(h_blurred[mid_row, :, :].T, aspect='auto')
        plt.colorbar()
        plt.xlabel('Mesh column'); plt.ylabel('Bin index')
        plt.title(f'Blurred histograms along mesh row {mid_row}')
        plt.savefig(os.path.join(dbg_path, 'ald_hist_slice.png'))
        plt.close()

    return gray_out
