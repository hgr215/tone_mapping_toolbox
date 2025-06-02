function figplot(im, varargin)
    % 获取当前函数的调用时传入的参数名称
    if (nargin <=1)
        paramName = inputname(1);  % 获取第一个输入参数的名称
    else
        paramName = inputname(2);
    end

    
    % 如果存在参数名称，则设置为 figure 的标题
    if ~isempty(paramName)
        hFig = figure("Name", paramName);
    else
        hFig = figure;
    end
    
    
    % 显示图像 im
    plot(im, varargin{:});
    
    % 你可以在这里添加更多的代码来处理可选参数等
end
