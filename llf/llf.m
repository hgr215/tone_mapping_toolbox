% Perform the local laplacian filter using the function
% f(x,ref)=x+fact*(I-ref)*exp(-(I-ref)²/(2*sigma²))

% Perform the local laplacian filter using any function

% This script implements edge-aware detail and tone manipulation as
% described in :
% Fast and Robust Pyramid-based Image Processing.
% Mathieu Aubry, Sylvain Paris, Samuel W. Hasinoff, Jan Kautz, and Frédo Durand.
% MIT technical report, November 2011

% INPUT
% I : input greyscale image
% r : a function handle to the remaping function
% N : number discretisation values of the intensity
%

% OUTPUT
% F : filtered image

% aubry.mathieu@gmail.com Sept 2012

function F = llf(I, sigmas, facts, N, fact_per_l, dbg_path)
    % Local Laplacian Filter (LLF) implementation
    % I: input grayscale image, normalized to [0,1]
    % sigmas, facts: parameter arrays for each level
    % N: number of discretization values
    % dbg_path: (optional) debug output directory

    [height, width] = size(I);
    n_levels = ceil(log2(max(height, width))) + 1;
    discretisation = linspace(0, 1, N);
    step = discretisation(2);

    % Interpolate parameters for each level
    assert(length(sigmas) >= 2);
    assert(length(facts) >= 2);
    sigma_interp = interp1(linspace(0, 1, length(sigmas)), sigmas, linspace(0, 1, N), 'linear', 'extrap');
    fact_interp  = interp1(linspace(0, 1, length(facts)),  facts,  linspace(0, 1, N), 'linear', 'extrap');

    input_gaussian_pyr = gaussian_pyramid(I, n_levels);
    output_laplace_pyr = laplacian_pyramid(I, n_levels);
    output_laplace_pyr{n_levels} = input_gaussian_pyr{n_levels};

    for i = 1:length(discretisation)
        ref  = discretisation(i);
        sigma = sigma_interp(i);
        fact  = fact_interp(i);

        % 计算 remap 曲线并插值
        I_axis = linspace(0, 1, 65535);
        % I_remap_curve = -fact * (I_axis - ref) .* exp(- (I_axis - ref).^2 / (2 * sigma^2));
        I_remap_curve = guiran_curve(sigma, fact, 65535, ref);

        I_remap = interp1(I_axis, I_remap_curve, I, 'linear', 'extrap');
        temp_laplace_pyr = laplacian_pyramid(I_remap, n_levels);

        % 累加到输出金字塔
        for level = 1:n_levels-1
            mask = (abs(input_gaussian_pyr{level} - ref) < step);
            weight = 1 - abs(input_gaussian_pyr{level} - ref) / step;
            output_laplace_pyr{level} = output_laplace_pyr{level} + ...
                fact_per_l(level) * mask .* temp_laplace_pyr{level} .* weight;
        end
        debugg = 1;

        % Debug: plot remap curve
        if exist('dbg_path', 'var') && ~isempty(dbg_path)
            fig = figure('Visible', 'off');
            plot(I_axis, I_remap_curve + I_axis);
            axis([0, 1, 0, 1]);
            title(['I_{remap} curve, ref = ', num2str(ref)]);
            xlabel('I'); ylabel('I_{remap}');
            saveas(fig, fullfile(dbg_path, sprintf('remap_curve_ref_g[%0.3f].png', ref)));
            close(fig);

            % save I_remap
            imwrite(I_remap + I, fullfile(dbg_path, sprintf('I_remap_g[%0.3f].jpg', ref)))
        end
    end

    F = reconstruct_laplacian_pyramid(output_laplace_pyr);
end
