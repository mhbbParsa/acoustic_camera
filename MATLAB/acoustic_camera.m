N  = 30;  Rarr = 0.045;  ga = pi*(3-sqrt(5));
i  = 0:N-1;
r  = Rarr.*sqrt((i+0.5)/N);
th = i.*ga;
X  = r.*cos(th);  Y = r.*sin(th);  Z = zeros(1,N);

n_of_sources = 2;
s_x = [1, -1];
s_y = [1, -1];
s_z = [3.5, 3.5];
intensity = [100 100];
speed_of_sound = 343;
frequency = 20000;
lambda = speed_of_sound/frequency;
u_max = 31/64;
u_vec   = linspace(-u_max, u_max, 32);
v_vec   = linspace(-u_max, u_max, 32);
[U,V]   = meshgrid(u_vec, v_vec);
visible = (U.^2 + V.^2) <= u_max.^2;
%W       = sqrt(max(1 - U.^2 - V.^2, 0));
%R  = 2.2;
%qx = R.*U;  qy = R.*V;  qz = R.*W;

field = zeros(size(U));
for j = 1:n_of_sources
  for k = 1:N
    distance  = sqrt((X(k)-s_x(j)).^2 + (Y(k)-s_y(j)).^2 + (Z(k)-s_z(j)).^2);
    amplitude  = intensity(j) ./ (4*pi*distance.^2);
    arriving_phase = 2*pi*(distance)/lambda;
    steering_phase = 2*pi*(U.*X(k) + V.*Y(k))/lambda;
    phase = arriving_phase + steering_phase;
    %fd = sqrt((qx-X(k)).^2 + (qy-Y(k)).^2 + (qz-Z(k)).^2);
    field = field + (amplitude .* exp(1j*phase));
  end
end

power = abs(field).^2;
%power(~visible) = 0;


[xg,yg] = meshgrid(1:32,1:32);
[xq,yq] = meshgrid(linspace(1,32,32), linspace(1,32,32));
power_up = interp2(xg,yg,power,xq,yq,'cubic');

u_f = linspace(-u_max,u_max,32); v_f = linspace(-u_max,u_max,32);

[Uf,Vf] = meshgrid(u_f,v_f);
%power_up(Uf.^2 + Vf.^2 > u_max.^2) = 0;
figure;
imagesc(u_vec, v_vec, power_up); axis xy image; colormap(turbo); colorbar;
xlabel('u = sin\theta'); ylabel('v = sin\phi');
title('Beamformed power');
hold on;
for j = 1:n_of_sources                                  % true source bearings
  nrm = sqrt(s_x(j).^2 + s_y(j).^2 + s_z(j).^2);
  plot(s_x(j)/nrm, s_y(j)/nrm, 'wo', 'MarkerSize',10, 'LineWidth',1.5);
end
hold off;