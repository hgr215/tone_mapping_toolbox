function out = do_srgb_gam(in)
% in = 0-1.0, out=0-1.0
    srgb_lut = get_srgb_lut();
    out = interp1_clip(linspace(0, 1, 256), srgb_lut, in);
end

