function res = guided_filter_2d(p, I, r, eps)
    % GF2: Guided Filter with 2D box kernel
    % p:    input image, normalized to [0, 1]
    % I:    guidance image, normalized to [0, 1]
    % r:    filter radius
    % eps:  regularization parameter

    if nargin < 4
        eps = 0.0001; % default value
    end

    if nargin < 3
        r = 17; % default radius
    end

    kernel   = fspecial("average", 2*r + 1);

    mean_I   = imfilter(I,      kernel, "replicate");
    mean_p   = imfilter(p,      kernel, "replicate");
    mean_Ip  = imfilter(I .* p, kernel, "replicate");
    corr_I   = imfilter(I .* I, kernel, "replicate");

    var_I    = corr_I  - mean_I  .* mean_I;
    cov_Ip   = mean_Ip - mean_I  .* mean_p;

    a        = cov_Ip ./ (var_I + eps);
    b        = mean_p - a .* mean_I;
    mean_a   = imfilter(a, kernel, "replicate");
    mean_b   = imfilter(b, kernel, "replicate");
    res      = mean_a .* I + mean_b;
    res      = clip(res, 0, 1); % Clip the result to [0, 1]
end