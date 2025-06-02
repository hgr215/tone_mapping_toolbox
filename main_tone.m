restoredefaultpath;      % 重置所有自定义路径
rehash toolboxcache;     % 刷新工具箱缓存
close all; clear;
addpath('common');
addpath('llf');
addpath('tone_operator');

directory_path = 'data';
% sz = [11664,  8750];  % w, h
sz = [2048, 1536];
shadow_gain = 4.0;
enable_dbg = 1; % 新增：调试开关

method = 'llf';
% method = 'glb';
% method = 'dgain';
% method = 'gf';
% method = 'no_tone';

%% 
raw_files = dir(fullfile(directory_path, '*.raw'))';
tif_files = dir(fullfile(directory_path, '*.tif'))';
jpg_files = dir(fullfile(directory_path, '*.jpg'))';
files = [raw_files, tif_files, jpg_files];
h = sz(2); w = sz(1);

% 统一输入输出目录
output_dir = fullfile(directory_path, 'results');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

for i = 1:length(files)
    raw_file_path = fullfile(directory_path, files(i).name);
    disp(['Processing file: ', files(i).name]);

    [~, file_name, ~] = fileparts(files(i).name);

    % 每张图片单独的dbg目录
    dbg_dir = fullfile(output_dir, [file_name, '_dbg']);
    if enable_dbg && ~exist(dbg_dir, 'dir')
        mkdir(dbg_dir);
    end

    if enable_dbg
        dbg_path = dbg_dir;
    else
        dbg_path = '';
    end

    % 算法选择
    switch method
        case 'llf'
            handle = @(gray_in, gain, dbg) llf_tone(gray_in, gain, dbg);
        case 'glb'
            handle = @(gray_in, gain, dbg) glb_tone(gray_in, gain, dbg);
        case 'dgain'
            handle = @(gray_in, gain, dbg) dgain_tone(gray_in, gain, dbg);
        case 'gf'
            handle = @(gray_in, gain, dbg) guided_filter_tone(gray_in, gain, dbg);
        case 'notone'
            handle = @(gray_in, gain, dbg) no_tone(gray_in, gain, dbg);
        otherwise
            error(['Unknown method: ', method]);
    end

    [rgb_out, rgb_in] = do_shadow_gain_hue_protect(raw_file_path, handle, shadow_gain, w, h, dbg_path);

    % show and save
    output_file_in = fullfile(output_dir, [file_name, '_in.jpg']);
    imwrite(rgb_in, output_file_in, 'quality', 100);
    disp(['Saved processed image: ', output_file_in]);
    % figshow(rgb_in);

    output_file_out = fullfile(output_dir, sprintf('%s_%s.jpg', file_name, method));
    imwrite(rgb_out, output_file_out, 'quality', 100);
    disp(['Saved processed image: ', output_file_out]);
    % figshow(rgb_out);
end

%%
function [rgb_out, rgb_ds] = do_shadow_gain_hue_protect(file_path, f, gain, w, h, dbg_path)
    sz_ds = [1536, 2048];
    [~, ~, ext] = fileparts(file_path);
    switch (ext)
        case '.raw'
            % 假设文件中存储的是 16-bit 无符号整数数据
            fileID = fopen(file_path, 'rb');
            raw_data = fread(fileID, '*uint16');  % 注意行列顺序
            stride = size(raw_data, 1) / h;
            raw_data = reshape(raw_data, stride, h)';
            % figshow(raw_data);
            fclose(fileID);

            % 2. 去马赛克
            rgb_in = demosaic(raw_data, 'rggb');
            rgb_in = double(rgb_in) / 65535;
        case '.tif'
            rgb_in = imread(file_path);
            rgb_in = im2double(rgb_in);
        otherwise
            rgb_in = imread(file_path);
            rgb_in = im2double(rgb_in);
    end
    
    rgb_ds = imresize(rgb_in, sz_ds);
    rgb_lin = do_srgb_degam(rgb_ds);
    gray_image = rgb2gray(rgb_ds);

    gray_out = f(gray_image, gain, dbg_path);  % grayin / out is gamma domain
    
    gray_in_lin = do_srgb_degam(gray_image);
    gray_out_lin = do_srgb_degam(gray_out);
    k = (gray_out_lin + eps) ./ (gray_in_lin + eps);
    rgb_out_lin(:, :, 1) = rgb_lin(:, :, 1) .* k;
    rgb_out_lin(:, :, 2) = rgb_lin(:, :, 2) .* k;
    rgb_out_lin(:, :, 3) = rgb_lin(:, :, 3) .* k;
    rgb_out_lin = clip(rgb_out_lin, 0, 1);

    % gainmap
    rgb_out = do_srgb_gam(rgb_out_lin);
    return;
end
