function figshow(im, varargin)
    % ��ȡ��ǰ�����ĵ���ʱ����Ĳ�������
    paramName = inputname(1);  % ��ȡ��һ���������������
    
    % ������ڲ������ƣ�������Ϊ figure �ı���
    if ~isempty(paramName)
        hFig = figure("Name", paramName);
    else
        hFig = figure;
    end
    
    
    % ��ʾͼ�� im
    imshow(im, varargin{:});
    
    % �������������Ӹ���Ĵ����������ѡ������
end
