function Oh = guided_filter_upsampling(Il, Ol, Ih, r, eps, dbg_path)
    % Guided filter upsampling
    % Il: low-resolution input image
    % Ol: low-resolution output image
    % Ih: high-resolution guidance image
    % r: filter radius
    % eps: regularization parameter

    if nargin < 5
        eps = 0.0001; % default value
    end

    if nargin < 4
        r = 17; % default radius
    end

    % Il is I, Ol is p
    h       = fspecial("average", 2*r + 1);
    meanI   = imfilter(Il, h, "symmetric");
    meanp   = imfilter(Ol, h, "symmetric");
    meanIp  = imfilter(Ol .* Il, h, "symmetric");
    meanII  = imfilter(Il .^ 2, h, "symmetric");

    varI = meanII - meanI .^ 2;
    covIp  = meanIp - meanI .* meanp;
    a = covIp ./ (varI + eps);
    b = meanp - a .* meanI;  % match p = aI + b

    mean_a = imfilter(a, h, "symmetric");
    mean_b=  imfilter(b, h, "symmetric");
    
    a_us = imresize(mean_a, size(Ih), "bilinear");
    b_us = imresize(mean_b, size(Ih), "bilinear");
    Oh = a_us .* Ih + b_us;

    if exist('dbg_path', 'var') && ~isempty(dbg_path)
        % save I_remap
        imwrite(a_us / 4, fullfile(dbg_path, 'a_us.jpg'));
        imwrite(b_us, fullfile(dbg_path,' b_us.jpg'));
        imwrite(mean_a / 4, fullfile(dbg_path, 'mean_a.jpg'));
        imwrite(mean_b, fullfile(dbg_path,' mean_b.jpg'));
    end
    
    % Scale the output to [0, 1]
    Oh = clip(Oh, 0, 1);
end