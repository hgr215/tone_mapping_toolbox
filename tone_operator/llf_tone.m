function out_gray = llf_tone(gray_in, gain, dbg_path)
    if nargin < 3
        dbg_path = '';
    end
    if nargin < 2
        gain = 2.5;
    end
    % params
    N = 16;
    sigmas = 0.2 * ones(1, 10);
    facts = 1 * ones(1, 10);
    detail_gain = 1.0;
    fact_per_l = ones(1, N);
    method = 2;

    base = llf(gray_in, sigmas, facts, N, fact_per_l, dbg_path);
    detail = gray_in - base;

    base_tone = glb_tone(base, gain);

    switch (method)
    case 1
        % apply on base
        figshow(base_tone);
        out_gray = base_tone + detail .* detail_gain;
    case 2
        % apply on gray in
        k = (base_tone + eps) ./ (base + eps);
        out_gray = gray_in .* k;
        out_gray = out_gray + (detail_gain - 1) * detail;
    end
    if ~isempty(dbg_path)
        imwrite(base, fullfile(dbg_path, 'llf_base.jpg'), 'quality', 100);
        imwrite(gray_in, fullfile(dbg_path, 'gray_in.jpg'), 'quality', 100);
    end
end