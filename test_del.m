clear;
close all;
I = linspace(0, 1, 1000);
%%
fact = -1;
sigma = 0.15;
ref = 0.5;
% 
% 
% I_remap = fact * (I - ref) .* exp(- (I - ref) .* (I - ref) ./ (2 * sigma * sigma));
% figplot(I, I_remap)
% 
% %% adaptive 1
% fact = -1;
% sigma = 0.2;
% ref = 0.22;
% I = linspace(0, 1, 1000);
% 
% sigma1 = min(sigma, ref);
% sigma2 = min(sigma, 1 - ref);
% 
% I_remap1 = fact * (I - ref) .* exp(- (I - ref) .* (I - ref) ./ (2 * sigma1 * sigma1));
% I_remap2 = fact * (I - ref) .* exp(- (I - ref) .* (I - ref) ./ (2 * sigma2 * sigma2));
% I_remap = zeros(1, 1000);
% I_remap(I < ref) = I_remap1((I < ref));
% I_remap(I >= ref) = I_remap2((I >= ref));
% figplot(I, I_remap)

%% adaptive2
zero_point = 0.7;  % for sigma0.2
sigma = 0.2;
ref = 0.72;
fact = 0.9;
I_ori = fact * I .* exp(-I.^2 ./ (2 * sigma^2));
figplot(I, I_ori);

% I_axis = linspace(0, 1, 65535);
% I_remap_curve = -fact * (I_axis - 0) .* exp(- (I_axis - 0).^2 / (2 * sigma^2));
% figplot(I_axis, I_remap_curve);

if zero_point > ref
    scale_left = ref / zero_point;
else
    scale_left = 1.0;
end

if zero_point > 1 - ref
    scale_right = (1 - ref) / zero_point;
else
    scale_right = 1.0;
end

I_left = interp1(I, I_ori, I ./ scale_left, 'linear', 'extrap') * scale_left;
I_right = interp1(I, I_ori, I ./ scale_right, 'linear', 'extrap') *scale_right;

axis([0, 1, -0.5, 0.5]);
figplot(I, I_left);
axis([0, 1, -0.5, 0.5]);
figplot(I, I_right);
axis([0, 1, -0.5, 0.5]);

y0 = [I_left(end:-1:1), -I_right];
figplot(linspace(0, 2, 2000), y0);
y= interp1(linspace(0, 2, 2000), y0, linspace(1-ref, 2- ref, 1000), 'linear', 'extrap');

% plot

figplot(I, y+I);
hold on;
plot(I, I, '--');
plot(ref, ref, '*');
