function vq = interp1_clip(x, v, xq)
    minv = min(x, [], 'all');
    maxv = max(x, [], 'all');
    xqc = clip(xq, minv, maxv);
    vq = interp1(x, v, xqc);
end