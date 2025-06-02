function out_gray = guided_filter_tone(gray_in, gain, dbg_path, detail_gain)

    if nargin < 4
        detail_gain = 1.0;
    end
    if nargin < 3
        dbg_path = '';
    end
    if nargin < 2
        gain = 2.5;
    end

    % params
    radius = 65;
    eps_gf = 0.04;
    
    base = guided_filter_2d(gray_in, gray_in, radius, eps_gf);
    detail = gray_in - base;
    figshow(gray_in);
    figshow(base);

    base_tone = glb_tone(base, gain);

    k = (base_tone + eps) ./ (base + eps);
    out_gray = gray_in .* k;
    out_gray = out_gray + (detail_gain - 1) * detail;

    % debug
    if ~isempty(dbg_path)
        imwrite(base, fullfile(dbg_path, 'gf_base.jpg'), 'quality', 100);
    end
end