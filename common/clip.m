function out = clip(x, lo, hi)
    out = max(x, lo);
    out = min(out, hi);
end

