function base = grid3d_core(gray_in, params, dbg_path)
    % grid3d_core - 3D grid based base-detail decomposition
    %
    % Syntax: base = grid3d_core(gray_in, params, dbg_path)
    %
    % Inputs:
    %    gray_in - Input grayscale image 0-1
    %    params - Structure containing parameters:
    %             h_x, h_y, h_z - grid sizes in x, y, z dimensions
    %             sigma_xy - spatial standard deviation
    %             sigma_z - intensity standard deviation
    %    dbg_path - (optional) path for saving debug images
    %
    % Outputs:
    %    base - Base layer of the input image

    if nargin < 3
        dbg_path = '';
    end

    [h, w] = size(gray_in);

    nx        = params.nx;
    ny        = params.ny;
    nz        = params.nz;
    sigma_xy  = params.sigma_xy;
    sigma_z   = params.sigma_z;

    % Create 3D grid: dimensions [ny+1, nx+1, nz+1, 2] (y, x, z, [sum,count])
    grid = zeros(ny + 1, nx + 1, nz + 1, 2);

    % gene stats.
    for yy = 1:h
        for xx = 1:w
            z_val = gray_in(yy, xx);
            % map coordinates to grid (use (coord-1)/(size-1) to avoid edge bias)
            x_grid = round( (xx - 1) / (w - 1) * nx ) + 1;
            y_grid = round( (yy - 1) / (h - 1) * ny ) + 1;
            z_grid = round( z_val * nz ) + 1;

            % clamp indices
            x_grid = min(max(x_grid, 1), nx + 1);
            y_grid = min(max(y_grid, 1), ny + 1);
            z_grid = min(max(z_grid, 1), nz + 1);

            grid(y_grid, x_grid, z_grid, 1) = grid(y_grid, x_grid, z_grid, 1) + z_val;
            grid(y_grid, x_grid, z_grid, 2) = grid(y_grid, x_grid, z_grid, 2) + 1;
        end
    end

    % spatial blur on each z-slice (xy blur)
    kernel_xy = fspecial('gaussian', [15, 15], sigma_xy);
    kernel_z = fspecial('gaussian', [33, 1], sigma_z);
    for zz = 1:size(grid,3)
        grid(:,:,zz,1) = imfilter(grid(:,:,zz,1), kernel_xy, 'same', 'symmetric');
        grid(:,:,zz,2) = imfilter(grid(:,:,zz,2), kernel_xy, 'same', 'symmetric');
    end
    % z-direction blur using 1D kernel and convn
    % create 1D gaussian kernel for z
    kz_len = max(3, min(51, 2 * round(3 * sigma_z) + 1)); % reasonable kernel length
    kernel_z2d = fspecial('gaussian', [kz_len, 1], sigma_z);
    kz = kernel_z2d(:,1);
    kz = kz / sum(kz(:));
    % convolve along z (preserve y,x) with symmetric padding along z
    klen = numel(kz);
    pad  = floor(klen/2);
    kz_kernel = reshape(kz, [1, 1, klen]);

    test_1 = squeeze(grid(8,8,:,1));

    if pad > 0
        % pad both ends along third dim with symmetric mirror, then use 'valid'
        tmp1 = padarray(grid(:,:,:,1), [0 0 pad], 'symmetric', 'both');
        tmp1 = convn(tmp1, kz_kernel, 'valid');
        grid(:,:,:,1) = tmp1;
        tmp2 = padarray(grid(:,:,:,2), [0 0 pad], 'symmetric', 'both');
        tmp2 = convn(tmp2, kz_kernel, 'valid');
        grid(:,:,:,2) = tmp2;
    else
        % kernel length 1, no padding needed
        grid(:,:,:,1) = convn(grid(:,:,:,1), kz_kernel, 'same');
        grid(:,:,:,2) = convn(grid(:,:,:,2), kz_kernel, 'same');
    end
    figplot(kz);
    kernel_xy_1d = kernel_xy(8,:) / sum(kernel_xy(8,:));
    figplot(kernel_xy_1d)

    test_2 = squeeze(grid(8,8,:,1));
    % figure;
    % plot(test_1);
    % hold on;
    % plot(test_2);
    test_3 = imfilter(test_1, kz, "same", "symmetric");
    % plot(test_3, 'green')

    % slice accelerated (with bug)
    % sx = nx + 1; sy = ny + 1; sz = nz + 1;
    % base = zeros(h, w);
    % grid_sum = squeeze(grid(:,:,:,1)); % [ny+1, nx+1, nz+1]
    % grid_cnt = squeeze(grid(:,:,:,2));
    % % query coordinates (Yq, Xq, Zq) in grid index space
    % [Xq, Yq] = meshgrid( (0:(w-1)) / max(w-1,1) * nx, (0:(h-1)) / max(h-1,1) * ny );
    % Zq = gray_in * nz;
    % % interpn expects coords in same order as data: Y(1:sy), X(1:sx), Z(1:sz)
    % Vsum = interpn(1:sy, 1:sx, 1:sz, grid_sum, Yq, Xq, Zq, 'linear', 0);
    % Vcnt = interpn(1:sy, 1:sx, 1:sz, grid_cnt, Yq, Xq, Zq, 'linear', 0);
    % base = gray_in; % default
    % mask = Vcnt > 0;
    % base(mask) = Vsum(mask) ./ Vcnt(mask);

    % slice no acceleration
    base = zeros(h, w);
    sx = nx + 1;
    sy = ny + 1;
    sz = nz + 1;
    for yy = 1:h
        for xx = 1:w
            z_val = gray_in(yy, xx);
            x_grid_f = (xx - 1) / max(w - 1,1) * nx; % fractional grid coord in [0, nx]
            y_grid_f = (yy - 1) / max(h - 1,1) * ny;
            z_grid_f = z_val * nz;
            x0 = floor(x_grid_f) + 1;
            y0 = floor(y_grid_f) + 1;
            z0 = floor(z_grid_f) + 1;
            x1 = min(x0 + 1, sx);
            y1 = min(y0 + 1, sy);
            z1 = min(z0 + 1, sz);
            x0 = min(max(x0,1), sx);
            y0 = min(max(y0,1), sy);
            z0 = min(max(z0,1), sz);
            dx = x_grid_f - (x0 - 1);
            dy = y_grid_f - (y0 - 1);
            dz = z_grid_f - (z0 - 1);
            % fetch corner values: each is [1x1x1x2], squeeze to [2,1]
            v000 = grid(y0, x0, z0, :);   % down-left-back
            v100 = grid(y0, x1, z0, :);   % down-right-back
            v010 = grid(y1, x0, z0, :);   % up-left-back
            v110 = grid(y1, x1, z0, :);   % up-right-back
            v001 = grid(y0, x0, z1, :);   % down-left-front
            v101 = grid(y0, x1, z1, :);   % down-right-front
            v011 = grid(y1, x0, z1, :);   % up-left-front
            v111 = grid(y1, x1, z1, :);   % up-right-front
            % bilinear interp on lower z (z0)
            vdown = (1-dx)*(1-dy).*v000 + dx*(1-dy).*v100 + (1-dx)*dy.*v010 + dx*dy.*v110;
            % bilinear interp on upper z (z1)
            vup   = (1-dx)*(1-dy).*v001 + dx*(1-dy).*v101 + (1-dx)*dy.*v011 + dx*dy.*v111;
            v = (1-dz).*vdown + dz.*vup; % interpolated [sum; count]
            % safety: if count>0 use average, else use original pixel
            if v(2) > 0
                base(yy, xx) = v(1) / v(2);
            else
                base(yy, xx) = z_val;
            end
        end
    end

    base = clip(base, 0, 1);
    % figshow(base, []);
    if ~isempty(dbg_path)
        imwrite(base, fullfile(dbg_path, sprintf('grid3d_base_xy%.1f_z%.1f.jpg', sigma_xy, sigma_z)), 'quality', 100);
        % imwrite(gray_in, fullfile(dbg_path, 'gray_in.jpg'), 'quality', 100);
    end
    ret = 0;
 end