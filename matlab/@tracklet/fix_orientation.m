function fix_orientation(trj)
% Asaf gal
% 11/07/16
% dynamic programming version of angle disambiguation:
% this function uses the speed of the ant to assign the ant direction
% 
  
%% speed related values
% above this speed, the cost of having a mismatch between the speed angle
% and the ant orientation drops to zero
vmax = 0.008;
% maximum cost for the the speed (only matters relative to emax)
wmax = 0.25;% mm/s
% range of speed values over which the cost varies
D_V = 0.0005;
% center value of the sigmoid
v0 = 0.003;

%% eccentricity realated values
% maximum value of the eccentricity
emax = 0.7;
% minimum value
emin = 0.01;
% center value
e_C = 0.7;
% range 
D_e = 0.025;

%%


% intialize an orientation vector 
or = trj.ORIENT;
ec = trj.ECCENT;
v = trj.vnorm;
phi = trj.vang;
N = length(or);
 
% speed weight function
%w = @(v) (v<=vmax).*(min(wmax,lambda*v.^2))+(v>vmax)*0;
w = @(v) (v<=vmax).*(wmax).*sigmoid((v-v0 )/D_V)+(v>vmax)*0;

% eccentricity weight function
e = @(ec) (emax-emin)*sigmoid((ec-e_C )/D_e)+emin;%(min(emax,alpha*ec(n)^2));

% tag weight function

SM = zeros(2,N-1);
or_fixed = zeros(size(or));
 
tmpcost = zeros(1,2);
costprevnew = zeros(1,2);
costprev = zeros(1,2);

% for each position in the trajectory (starting at the second one)
for n=2:N
    %  for each possible value of the current state (0 or 1[i.e., +?])
    for scur=0:1
        % current value of the ant orienation
        thetacur = or(n) + scur*pi;
        % for each value of the previous state (0 or 1[i.e., +?])
        for sprev=0:1
            % previous value of the ant orientation
            thetaprev = or(n-1) + sprev*pi;
            % cost for this pair of configurations               
            costcur = (e(ec(n)))*abs(thetacur-thetaprev) + (w(v(n-1)))*abs(thetacur-phi(n-1));
            % temporary cost for the chosen previous state: previous cost + current cost
            tmpcost(sprev+1) = costprev(sprev+1) + costcur;            
        end
        % make the previous state the one that minimizes the temporary
        % cost
        sprev = argmin(tmpcost)-1;
        % store this state in SM
        SM(scur+1,n-1) = sprev;
        
        costprevnew(scur+1) = tmpcost(sprev+1);
 
  
    end
    
    costprev = costprevnew;
 
end
 

scur = argmin(costprev) - 1;
or_fixed(N) = or(N) + scur*pi;
s(N) = scur;
 
for n=N-1:-1:1
    
    scur = SM(scur+1,n);
    s(n) = scur;
    or_fixed(n) = or(n) + scur*pi;
 
end

trj.data_.ORIENT = angle(or_fixed);

end


