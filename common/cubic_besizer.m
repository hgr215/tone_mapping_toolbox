function [curvex, curvey] = cubic_besizer(controlPoints, numPoints)
    % cubicBezier: 生成三阶贝塞尔曲线
    %
    % 输入:
    %   controlPoints: 4x2 矩阵，每行是一个控制点 [x, y]
    %   numPoints: 曲线上的点数
    %
    % 输出:
    %   bezierCurve: numPoints x 2 矩阵，每行是曲线上的一个点 [x, y]

    % 验证输入
    if size(controlPoints, 1) ~= 4 || size(controlPoints, 2) ~= 2
        error('controlPoints 必须是一个 4x2 的矩阵');
    end

    if numPoints < 2
        error('numPoints 必须大于或等于 2');
    end

    % 提取控制点坐标
    P0 = controlPoints(1, :);
    P1 = controlPoints(2, :);
    P2 = controlPoints(3, :);
    P3 = controlPoints(4, :);

    % 生成参数 t
    t = linspace(0, 1, numPoints);

    % 计算贝塞尔曲线上的点
    bezierCurve = zeros(numPoints, 2);
    for i = 1:numPoints
        bezierCurve(i, :) = (1 - t(i))^3 * P0 + ...
                            3 * (1 - t(i))^2 * t(i) * P1 + ...
                            3 * (1 - t(i)) * t(i)^2 * P2 + ...
                            t(i)^3 * P3;
    end

    curvex = bezierCurve(:, 1)';
    curvey = bezierCurve(:, 2)';
end
