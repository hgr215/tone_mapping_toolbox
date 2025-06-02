function out_gray = no_tone(gray_in, gain, dbg_path)
    if nargin < 3
        dbg_path = '';
    end
    if nargin < 2
        gain = 2.5;
    end
    out_gray = gray_in;
    if ~isempty(dbg_path)
        % imwrite 或其他调试输出
    end
end

