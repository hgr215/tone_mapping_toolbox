function out_gray = grid3d_tone(gray_in, gain, dbg_path)
    if nargin < 3
        dbg_path = '';
    end
    if nargin < 2
        gain = 2.5;
    end
    % params
    params = struct();
    params.nx = 33;
    params.ny = 33;
    params.nz = 33;
    params.sigma_xy = 0.1;
    params.sigma_z = 10;
    method = 2;
    detail_gain = 1;

    % gene sigma array
    sigmas_xy = [1];
    sigmas_z = [5.1];
    for i = 1:length(sigmas_xy)
        for j = 1:length(sigmas_z)
            params.sigma_xy = sigmas_xy(i);
            params.sigma_z = sigmas_z(j);
            base = grid3d_core(gray_in, params, dbg_path);
        end
    end

    base = grid3d_core(gray_in, params, dbg_path);
    detail = gray_in - base;

    base_tone = glb_tone(base, gain, dbg_path);

    switch (method)
    case 1
        % apply on base
        out_gray = base_tone + detail .* detail_gain;
    case 2
        % apply on gray in
        k = (base_tone + eps) ./ (base + eps);
        out_gray = gray_in .* k;
        out_gray = out_gray + (detail_gain - 1) * detail;
    end
    if ~isempty(dbg_path)
        % imwrite(base, fullfile(dbg_path, 'grid3d_base.jpg'), 'quality', 100);
        imwrite(gray_in, fullfile(dbg_path, 'gray_in.jpg'), 'quality', 100);
    end
end