function gray_out = dgain_tone(gray_in, gain, dbg_path)
    if nargin < 3
        dbg_path = '';
    end
    if nargin < 2
        gain = 2.5;
    end

    in_lin = do_srgb_degam(gray_in);
    in_lin = clip(in_lin, 0, 1);
    in_out = in_lin .* gain;
    % in_out = clip(lin_out, 0, 1);
    gray_out = do_srgb_gam(in_out);
    
    % Add debug output here if needed:
    if ~isempty(dbg_path)
        % imwrite or other debug output
    end
end

