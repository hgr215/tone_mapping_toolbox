function out = do_srgb_degam(in)
% in = 0-1.0, out=0-1.0
    srgb_lut = get_srgb_lut();
    out = interp1_clip(srgb_lut, linspace(0, 1, 256), in);
end

