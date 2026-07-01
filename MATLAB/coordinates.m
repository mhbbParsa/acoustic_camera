%% ---- array (unchanged) ----
N  = 30;  Rarr = 0.09;  ga = pi*(3-sqrt(5));
i  = 0:N-1;
r  = Rarr.*sqrt((i+0.5)/N);
th = i.*ga;
X  = r.*cos(th);  Y = r.*sin(th);  Z = zeros(1,N);


lambda = 343/10000;
scale  = 2048 / lambda;
X_fix  = round(X * scale);
Y_fix  = round(Y * scale);
disp(X_fix); disp(Y_fix);