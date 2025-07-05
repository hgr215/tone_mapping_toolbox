function gray_out = glb_tone(gray_in, gain, dbg_path)
    if nargin < 3
        dbg_path = '';
    end
    if nargin < 2
        gain = 2.5;
    end

    in_lin = do_srgb_degam(gray_in);
    in_lin = clip(in_lin, 0, 1);
    x = linspace(0, 1, 257);

    knee_srgb = do_srgb_degam(0.5);
    fprintf('knee point %f\n', knee_srgb);
    curve = glb_shadow_curve(gain, 257, knee_srgb);

    out_lin = interp1_clip(x, curve, in_lin);
    gray_out = do_srgb_gam(out_lin);
    
    if exist('dbg_path', 'var') && ~isempty(dbg_path)
        fig = figure('Visible', 'off');
        I_axis = linspace(0, 1, length(curve));
        plot(I_axis, curve);
        axis([0, 1, 0, 1]);
        title('GLB Curve');
        xlabel('I'); ylabel('GLB Curve');
        saveas(fig, fullfile(dbg_path, 'glb_curve.png'));
        close(fig);
    end
end

