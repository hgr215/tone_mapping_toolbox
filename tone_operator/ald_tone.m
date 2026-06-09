function gray_out = ald_tone(gray_in, gain, dbg_path)
    if nargin < 3
        dbg_path = '';
    end
    if nargin < 2
        gain = 2.5;
    end

    % ---- parameters ----
    n_mesh = 32;
    n_bins = 16;
    blur_ksize = 7;
    n_curve_pts = 257;
    debug = ~isempty(dbg_path);

    % apply_mode:
    %   'linear' — build local curves in linear domain, apply directly on
    %              gamma gray_in.  Bit-true to the first implementation.
    %   'gamma'  — convert the linear global curve to gamma-equivalent,
    %              then rebuild local curves in gamma domain.  Apply on
    %              gamma gray_in.  This lets the adaptive per-bin logic
    %              (k_i/k_th) operate in the same domain as the image.
    apply_mode = 'gamma';

    [H, W] = size(gray_in);

    % 1. Global tone curve (linear domain, same knee as glb_tone) ---------
    knee = do_srgb_degam(0.5);
    f_global = glb_shadow_curve(gain, n_curve_pts, knee);
    x_curve = linspace(0, 1, n_curve_pts);

    % 2. Local histogram:  n_mesh x n_mesh x n_bins -----------------------
    bin_edges = linspace(0, 1, n_bins + 1);
    local_hist = zeros(n_mesh, n_mesh, n_bins);
    cell_h = H / n_mesh;
    cell_w = W / n_mesh;

    for row = 1:n_mesh
        r_start = round((row - 1) * cell_h) + 1;
        r_end   = round(row * cell_h);
        for col = 1:n_mesh
            c_start = round((col - 1) * cell_w) + 1;
            c_end   = round(col * cell_w);
            cell_data = gray_in(r_start:r_end, c_start:c_end);
            local_hist(row, col, :) = histcounts(cell_data(:), bin_edges);
        end
    end

    % 3. Build local curves in linear domain (always, for linear mode) ----
    x_intv = linspace(0, 1, n_bins + 1);
    [f_local_lin, k_i_lin, k_th_lin, dbg_lin] = build_local_curves(...
        f_global, x_curve, x_intv, n_bins, n_curve_pts, debug);

    % 4. Gamma mode: rebuild local curves in gamma domain -----------------
    if strcmp(apply_mode, 'gamma')
        % Convert global curve:  f_gamma(t) = gam( f_lin( degam(t) ) )
        x_gamma = x_curve;
        x_l = do_srgb_degam(x_gamma);
        y_l = interp1_clip(x_curve, f_global, x_l);
        f_global_gamma = do_srgb_gam(y_l);

        % Rebuild local curves from gamma-domain global curve.
        % The per-bin adaptive logic now operates in gamma domain:
        %   - bin [i/16, (i+1)/16] partitions gamma brightness
        %   - k_i, k_th computed from gamma-domain curve slopes
        %   - Bezier transitions built in gamma coordinates
        [f_local, k_i_vals, k_th_vals, dbg_gamma] = build_local_curves(...
            f_global_gamma, x_curve, x_intv, n_bins, n_curve_pts, debug);
    else
        f_local = f_local_lin;
        k_i_vals = k_i_lin;
        k_th_vals = k_th_lin;
    end

    % 5. Spatially blur local histogram (xy only) -------------------------
    blur_sigma = blur_ksize / 3;
    h_kernel = fspecial('gaussian', [blur_ksize, blur_ksize], blur_sigma);
    h_blurred = zeros(size(local_hist));
    for b = 1:n_bins
        h_blurred(:, :, b) = imfilter(local_hist(:, :, b), h_kernel, 'replicate');
    end

    % 6. Apply curves -----------------------------------------------------
    %    Both modes: apply to gamma gray_in directly (no degamma on image).
    %    The framework converts gray_out / gray_in to linear domain and
    %    computes the gainmap for RGB.
    gray_out = apply_local_curves(gray_in, f_local, h_blurred);

    % 7. Debug outputs ----------------------------------------------------
    if debug
        % (a) Linear-domain curves
        fig = figure('Visible', 'off');
        plot(x_curve, f_global, 'k-', 'LineWidth', 2); hold on;
        for ii = 1:n_bins
            plot(x_curve, f_local_lin(ii, :), '--', 'LineWidth', 0.5);
        end
        axis([0, 1, 0, 1]);
        title('ALD Curves — linear domain (black=global, dashed=local f_i)');
        xlabel('Input (linear)'); ylabel('Output (linear)');
        saveas(fig, fullfile(dbg_path, 'ald_curves_lin.png'));
        close(fig);

        % (b) Gamma-domain curves (only in gamma mode)
        if strcmp(apply_mode, 'gamma')
            fig = figure('Visible', 'off');
            plot(x_curve, f_global_gamma, 'k-', 'LineWidth', 2); hold on;
            for ii = 1:n_bins
                plot(x_curve, f_local(ii, :), '--', 'LineWidth', 0.5);
            end
            axis([0, 1, 0, 1]);
            title('ALD Curves — gamma domain (black=global, dashed=local f_i)');
            xlabel('Input (gamma)'); ylabel('Output (gamma)');
            saveas(fig, fullfile(dbg_path, 'ald_curves_gamma.png'));
            close(fig);
        end

        % (c) 4x4 subplot: key points for the active mode's curves
        dbg_plot = dbg_lin;
        f_plot = f_local_lin;
        fg_plot = f_global;
        k_i_plot = k_i_lin;
        k_th_plot = k_th_lin;
        domain_str = 'linear';
        if strcmp(apply_mode, 'gamma')
            dbg_plot = dbg_gamma;
            f_plot = f_local;
            fg_plot = f_global_gamma;
            k_i_plot = k_i_vals;
            k_th_plot = k_th_vals;
            domain_str = 'gamma';
        end

        fig = figure('Visible', 'off', 'Position', [100, 100, 1600, 1200]);
        for ii = 1:n_bins
            subplot(4, 4, ii);
            plot(x_curve, fg_plot, 'Color', [0.7, 0.7, 0.7], 'LineWidth', 0.8); hold on;
            plot(x_curve, f_plot(ii, :), 'b-', 'LineWidth', 1.2);

            xi_s = x_intv(ii);
            xi_e = x_intv(ii + 1);
            yl = ylim;
            plot([xi_s, xi_s], yl, 'k--', 'LineWidth', 0.6);
            plot([xi_e, xi_e], yl, 'k--', 'LineWidth', 0.6);

            if dbg_plot(ii).is_modified
                plot(dbg_plot(ii).x_start, dbg_plot(ii).y_start_line, ...
                    'ro', 'MarkerSize', 5, 'MarkerFaceColor', 'r');
                plot(dbg_plot(ii).x_end,   dbg_plot(ii).y_end_line, ...
                    'ro', 'MarkerSize', 5, 'MarkerFaceColor', 'r');

                if ~isempty(dbg_plot(ii).ctrl_left)
                    cL = dbg_plot(ii).ctrl_left;
                    plot(cL(:,1), cL(:,2), 'ms-', 'LineWidth', 1.2, ...
                        'MarkerSize', 6, 'MarkerFaceColor', 'm');
                    plot(cL(1,1), cL(1,2), 'mo', 'MarkerSize', 7, 'LineWidth', 1.5);
                    plot(cL(4,1), cL(4,2), 'mo', 'MarkerSize', 7, 'LineWidth', 1.5);
                end
                if ~isempty(dbg_plot(ii).ctrl_right)
                    cR = dbg_plot(ii).ctrl_right;
                    plot(cR(:,1), cR(:,2), 'gs-', 'LineWidth', 1.2, ...
                        'MarkerSize', 6, 'MarkerFaceColor', 'g');
                    plot(cR(1,1), cR(1,2), 'go', 'MarkerSize', 7, 'LineWidth', 1.5);
                    plot(cR(4,1), cR(4,2), 'go', 'MarkerSize', 7, 'LineWidth', 1.5);
                end

                plot(dbg_plot(ii).raw_x, dbg_plot(ii).raw_y, 'c.', 'MarkerSize', 2);
            end

            xlim([0, 1]); ylim([0, 1]); axis square;
            mod_str = 'N';
            if dbg_plot(ii).is_modified; mod_str = 'Y'; end
            title(sprintf('Bin %d  (k_i=%.2f, k_{th}=%.2f, mod=%s)', ...
                ii, k_i_plot(ii), k_th_plot(ii), mod_str), 'FontSize', 8);
        end
        sgtitle(sprintf('16 Local Curves — %s domain', domain_str));
        saveas(fig, fullfile(dbg_path, 'ald_local_curves_4x4.png'));
        close(fig);

        % (d) Mesh overlay on input
        fig = figure('Visible', 'off');
        imshow(gray_in); hold on;
        for row = 1:n_mesh
            for col = 1:n_mesh
                r_start = round((row - 1) * cell_h) + 1;
                c_start = round((col - 1) * cell_w) + 1;
                rectangle('Position', [c_start, r_start, cell_w, cell_h], ...
                    'EdgeColor', 'r', 'LineWidth', 0.5);
            end
        end
        title('Mesh Grid Overlay');
        saveas(fig, fullfile(dbg_path, 'ald_mesh.png'));
        close(fig);

        % (e) Raw histogram total count per cell
        fig = figure('Visible', 'off');
        imagesc(sum(local_hist, 3)); axis image; colorbar;
        title('Histogram total count per mesh cell');
        saveas(fig, fullfile(dbg_path, 'ald_hist_mesh.png'));
        close(fig);

        % (f) Blurred histogram total count
        fig = figure('Visible', 'off');
        imagesc(sum(h_blurred, 3)); axis image; colorbar;
        title('Blurred histogram total count per mesh cell');
        saveas(fig, fullfile(dbg_path, 'ald_hist_blur.png'));
        close(fig);

        % (g) Slope comparison bar chart
        fig = figure('Visible', 'off');
        bar_data = [k_i_plot; k_th_plot]';
        bar(bar_data);
        legend('k_i', 'k_{th}');
        title(sprintf('Slope comparison per bin — %s domain', domain_str));
        xlabel('Bin index'); ylabel('Slope');
        saveas(fig, fullfile(dbg_path, 'ald_slope.png'));
        close(fig);

        % (h) Histogram slice at middle mesh row
        mid_row = round(n_mesh / 2);
        fig = figure('Visible', 'off');
        imagesc(squeeze(h_blurred(mid_row, :, :))'); axis image; colorbar;
        xlabel('Mesh column'); ylabel('Bin index');
        title(sprintf('Blurred histograms along mesh row %d', mid_row));
        saveas(fig, fullfile(dbg_path, 'ald_hist_slice.png'));
        close(fig);
    end
end

% =====================================================================
% Sub-function: build 16 local curves from a global curve
% =====================================================================

function [f_local, k_i_vals, k_th_vals, dbg_curve] = build_local_curves(...
        f_global, x_curve, x_intv, n_bins, n_curve_pts, store_dbg)
    % Build 16 per-bin local curves from a global tone curve.
    %
    % For each of the 16 uniformly-spaced bins in [0,1]:
    %   - k_i  = average slope of f_global over the interval
    %   - k_th = Weber threshold  f(x_mid) / x_mid
    %   - If k_i >= k_th: copy f_global as-is
    %   - If k_i <  k_th: replace the interval with a steeper line
    %     (slope = k_th) and use cubic Bezier transitions to (0,0)
    %     and (1,1) for a natural look.
    %
    % This function is domain-agnostic — it works on linear or gamma curves.

    f_local = zeros(n_bins, n_curve_pts);
    k_i_vals = zeros(1, n_bins);
    k_th_vals = zeros(1, n_bins);

    if store_dbg
        dbg_curve = struct();
    else
        dbg_curve = struct('is_modified', {});
    end

    for i = 1:n_bins
        x_start = x_intv(i);
        x_end   = x_intv(i + 1);
        x_mid   = (x_start + x_end) / 2;

        f_start = interp1_clip(x_curve, f_global, x_start);
        f_end   = interp1_clip(x_curve, f_global, x_end);
        f_mid   = interp1_clip(x_curve, f_global, x_mid);

        k_i  = (f_end - f_start) / (x_end - x_start);
        k_th = f_mid / max(x_mid, 1e-6);

        k_i_vals(i)  = k_i;
        k_th_vals(i) = k_th;

        if k_i >= k_th
            f_local(i, :) = f_global;
            if store_dbg
                dbg_curve(i).is_modified = false;
                dbg_curve(i).x_start = x_start;
                dbg_curve(i).x_end   = x_end;
            end
        else
            y_start_line = f_mid - k_th * (x_mid - x_start);
            y_end_line   = f_mid + k_th * (x_end   - x_mid);
            y_start_line = clip(y_start_line, 0, 1);
            y_end_line   = clip(y_end_line,   0, 1);

            n_line = 50;
            x_line = linspace(x_start, x_end, n_line)';
            y_line = f_mid + k_th * (x_line - x_mid);
            y_line = clip(y_line, 0, 1);

            x_all = [];
            y_all = [];

            % left Bezier: (0,0) -> (x_start, y_start_line)
            ctrl_left = [];
            if x_start > 0
                ctrl_left = bezier_ctrl_left(x_start, y_start_line, k_th);
                [bx, by] = cubic_besizer(ctrl_left, 100);
                mask = bx < x_start;
                x_all = [x_all; bx(mask)'];
                y_all = [y_all; by(mask)'];
            end

            % line segment
            x_all = [x_all; x_line];
            y_all = [y_all; y_line];

            % right Bezier: (x_end, y_end_line) -> (1,1)
            ctrl_right = [];
            if x_end < 1
                ctrl_right = bezier_ctrl_right(x_end, y_end_line, k_th);
                [bx, by] = cubic_besizer(ctrl_right, 100);
                mask = bx > x_end;
                x_all = [x_all; bx(mask)'];
                y_all = [y_all; by(mask)'];
            end

            % resample to uniform grid
            [x_all, idx] = sort(x_all);
            y_all = y_all(idx);
            [x_all, ia] = unique(x_all);
            y_all = y_all(ia);
            f_local(i, :) = interp1_clip(x_all, y_all, x_curve);

            if store_dbg
                dbg_curve(i).is_modified  = true;
                dbg_curve(i).x_start       = x_start;
                dbg_curve(i).x_end         = x_end;
                dbg_curve(i).y_start_line  = y_start_line;
                dbg_curve(i).y_end_line    = y_end_line;
                dbg_curve(i).ctrl_left     = ctrl_left;
                dbg_curve(i).ctrl_right    = ctrl_right;
                dbg_curve(i).raw_x         = x_all;
                dbg_curve(i).raw_y         = y_all;
            end
        end
    end
end

% =====================================================================
% Bezier control-point generators
% =====================================================================

function ctrl = bezier_ctrl_left(x_target, y_target, k_th)
    P0 = [0, 0];
    P3 = [x_target, y_target];
    d2 = x_target * 0.3;
    P2 = [x_target - d2, y_target - k_th * d2];
    P2 = max(P2, 0);
    P1 = [x_target * 0.3, y_target * 0.5];
    P1 = max(P1, 0);
    ctrl = [P0; P1; P2; P3];
end

function ctrl = bezier_ctrl_right(x_start, y_start, k_th)
    P0 = [x_start, y_start];
    P3 = [1, 1];
    d1 = (1 - x_start) * 0.3;
    P1 = [x_start + d1, y_start + k_th * d1];
    P1 = min(P1, 1);
    d2 = (1 - x_start) * 0.3;
    P2 = [1 - d2, 1 - d2];
    ctrl = [P0; P1; P2; P3];
end

% =====================================================================
% Vectorised application of 16 local curves
% =====================================================================

function gray_out = apply_local_curves(gray_in, f_local, h_blurred)
    [H, W] = size(gray_in);
    [n_bins, n_curve_pts] = size(f_local);

    h_interp = imresize(h_blurred, [H, W], 'bilinear');
    h_sum = sum(h_interp, 3);
    h_sum(h_sum == 0) = 1;
    h_interp = h_interp ./ h_sum;

    gray_idx = round(gray_in * (n_curve_pts - 1)) + 1;
    gray_idx = clip(gray_idx, 1, n_curve_pts);

    f_flat = f_local(:, gray_idx(:));
    f_3d = reshape(f_flat', H, W, n_bins);
    gray_out = sum(h_interp .* f_3d, 3);
    gray_out = clip(gray_out, 0, 1);
end
