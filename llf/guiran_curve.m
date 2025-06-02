function y = guiran_curve(sigma, fact, N, ref)
    I = linspace(0, 1, N);
    zero_point = 0.5; % 可根据需要调整

    I_ori = fact * I .* exp(-I.^2 ./ (2 * sigma^2));

    if zero_point > ref
        scale_left = ref / zero_point;
    else
        scale_left = 1.0;
    end

    if zero_point > 1 - ref
        scale_right = (1 - ref) / zero_point;
    else
        scale_right = 1.0;
    end

    I_left = interp1(I, I_ori, I ./ (scale_left + eps), 'linear', 'extrap') * scale_left;
    I_right = interp1(I, I_ori, I ./ (scale_right + eps), 'linear', 'extrap') * scale_right;

    y0 = [I_left(end:-1:1), -I_right];
    y = interp1(linspace(0, 2, N * 2), y0, linspace(1-ref, 2-ref, N), 'linear', 'extrap');
    % figplot(y);
    y = clip(y + I, 0, 1) - I;
end