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
    fprintf('knee point %f', knee_srgb);
    curve = glb_shadow_curve(gain, 257, knee_srgb);

    out_lin = interp1_clip(x, curve, in_lin);
    gray_out = do_srgb_gam(out_lin);
    
    if ~isempty(dbg_path)
        % imwrite 或其他调试输出
    end
end

