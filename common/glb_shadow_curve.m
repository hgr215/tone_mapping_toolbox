function curve = glb_shadow_curve(gain, num, knee_point)
    P1 = [0.3, 0.3 * gain] * knee_point;  % x, y
    P2 = [knee_point * 0.4, knee_point * 0.4];
    
    control_points = [
        0, 0;
        P1;
        P2;
        knee_point, knee_point
    ];

    [curvex, curvey] = cubic_besizer(control_points, 500);
    curvex = [curvex, 1.0];
    curvey = [curvey, 1.0];
    axis_x = linspace(0, 1, num);
    curve = interp1_clip(curvex, curvey, axis_x);
    figplot(axis_x, curve); hold on; plot(axis_x, axis_x, '--');
end