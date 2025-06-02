function figplot(im, varargin)
    % ��ȡ��ǰ�����ĵ���ʱ����Ĳ�������
    if (nargin <=1)
        paramName = inputname(1);  % ��ȡ��һ���������������
    else
        paramName = inputname(2);
    end

    
    % ������ڲ������ƣ�������Ϊ figure �ı���
    if ~isempty(paramName)
        hFig = figure("Name", paramName);
    else
        hFig = figure;
    end
    
    
    % ��ʾͼ�� im
    plot(im, varargin{:});
    
    % �������������Ӹ���Ĵ����������ѡ������
end
