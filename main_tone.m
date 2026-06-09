restoredefaultpath;      % Reset all custom paths
rehash toolboxcache;     % Refresh toolbox cache
close all; clear;
addpath('common');
addpath('llf');
addpath('tone_operator');
addpath('grid3d');

directory_path = 'data';
% sz = [11664,  8750];  % w, h
sz = [2048, 1536];
shadow_gain = 4.0;
enable_dbg = 1; % save curve, middle res to files. If want to clock running time, close it.

gf_us_en = 0;   % use guided filter to accelerate tone mapping. scale means do tone mapping on ds image

% method list
% method = 'llf';
% method = 'glb';
% method = 'dgain';
% method = 'gf';
% method = 'no_tone';
% method = '3dgrid';
method = 'ald';

%% 
raw_files = dir(fullfile(directory_path, '*.raw'))';
tif_files = dir(fullfile(directory_path, '*.tif'))';
jpg_files = dir(fullfile(directory_path, '*.jpg'))';
files = [raw_files, tif_files, jpg_files];
h = sz(2); w = sz(1);

% Unified input/output directory
output_dir = fullfile(directory_path, 'results');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

for i = 2:2(files)
% for i = 2:2
    raw_file_path = fullfile(directory_path, files(i).name);
    disp(['Processing file: ', files(i).name]);

    [~, file_name, ~] = fileparts(files(i).name);

    % Separate dbg directory for each image
    dbg_dir = fullfile(output_dir, [file_name, '_dbg']);
    if enable_dbg && ~exist(dbg_dir, 'dir')
        mkdir(dbg_dir);
    end

    if enable_dbg
        dbg_path = dbg_dir;
    else
        dbg_path = '';
    end

    % Algorithm selection
    switch method
        case 'llf'
            handle = @(gray_in, gain, dbg) llf_tone(gray_in, gain, dbg);
        case 'glb'
            handle = @(gray_in, gain, dbg) glb_tone(gray_in, gain, dbg);
        case 'dgain'
            handle = @(gray_in, gain, dbg) dgain_tone(gray_in, gain, dbg);
        case 'gf'
            handle = @(gray_in, gain, dbg) guided_filter_tone(gray_in, gain, dbg);
        case '3dgrid'
            handle = @(gray_in, gain, dbg) grid3d_tone(gray_in, gain, dbg);
        case 'notone'
            handle = @(gray_in, gain, dbg) no_tone(gray_in, gain, dbg);
        case 'ald'
            handle = @(gray_in, gain, dbg) ald_tone(gray_in, gain, dbg);
        otherwise
            error(['Unknown method: ', method]);
    end

    [rgb_out, rgb_in] = do_shadow_gain_hue_protect(raw_file_path, handle, shadow_gain, w, h, dbg_path, gf_us_en);

    % show and save
    output_file_in = fullfile(output_dir, [file_name, '_in.jpg']);
    imwrite(rgb_in, output_file_in, 'quality', 100);
    disp(['Saved processed image: ', output_file_in]);

    if gf_us_en
        gf_tag = '_gfus';
    else
        gf_tag = '';
    end
    output_file_out = fullfile(output_dir, sprintf('%s_%s%s.jpg', file_name, method, gf_tag));
    imwrite(rgb_out, output_file_out, 'quality', 100);
    disp(['Saved processed image: ', output_file_out]);
end

%%
function [rgb_out, rgb_ds] = do_shadow_gain_hue_protect(file_path, f, gain, w, h, dbg_path, gf_us_en)
    sz_ds = [1536, 2048];
    [~, ~, ext] = fileparts(file_path);
    switch (ext)
        case '.raw'
            % Assume the file stores 16-bit unsigned integer data
            fileID = fopen(file_path, 'rb');
            raw_data = fread(fileID, '*uint16');  % Note row-column order
            stride = size(raw_data, 1) / h;
            raw_data = reshape(raw_data, stride, h)';
            % figshow(raw_data);
            fclose(fileID);

            % 2. Demosaic
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
    rgb_lin     = do_srgb_degam(rgb_ds);
    gray_image  = rgb2gray(rgb_ds);
    
    t_start     = tic;
    if gf_us_en
        scale           = 4;  % do tone mapping on ds 4 image
        eps_gf             = 0.00000001;
        radius          = 5;
        gray_in_ds      = imresize(gray_image, 1 / scale, "bilinear");
        gray_out_ds     = f(gray_in_ds, gain, dbg_path);  % grayin / out is gamma domain

        % test debug
        gray_out        = guided_filter_upsampling(gray_in_ds, gray_out_ds, gray_image, radius, eps_gf, dbg_path);

        if exist('dbg_path', 'var') && ~isempty(dbg_path)
            % save I_remap
            imwrite(gray_image,                                 fullfile(dbg_path, 'gray_in_full.jpg'),  'quality', 99);
            imwrite(gray_in_ds,                                 fullfile(dbg_path, 'gray_in_ds.jpg'),    'quality', 99);
            imwrite(gray_out_ds,                                fullfile(dbg_path, 'gray_out_ds.jpg'),   'quality', 99);
            imwrite(imresize(gray_out_ds, scale, "bilinear"),   fullfile(dbg_path, 'gray_out_dsus.jpg'), 'quality', 99);
            imwrite(gray_out,                                   fullfile(dbg_path, 'gray_out_gfus.jpg') ,'quality', 99);
            
            % save GT gray:
            % gray_out_full = f(gray_image, gain, '');
            % imwrite(gray_out_full, fullfile(dbg_path,' gray_out_GT.jpg'));
        end
    else
        gray_out        = f(gray_image, gain, dbg_path);  % grayin / out is gamma domain
    end
    elapsed_time       = toc(t_start);
    fprintf('Processing time: %.2f seconds\n', elapsed_time);
    
    gray_in_lin        = do_srgb_degam(gray_image);
    gray_out_lin       = do_srgb_degam(gray_out);

    k = (gray_out_lin + eps) ./ (gray_in_lin + eps);

    rgb_out_lin(:, :, 1) = rgb_lin(:, :, 1) .* k;
    rgb_out_lin(:, :, 2) = rgb_lin(:, :, 2) .* k;
    rgb_out_lin(:, :, 3) = rgb_lin(:, :, 3) .* k;
    rgb_out_lin = clip(rgb_out_lin, 0, 1);

    % gainmap
    rgb_out = do_srgb_gam(rgb_out_lin);
    return;
end