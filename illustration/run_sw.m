clear all;
addpath('../functions');
addpath('_auxiliary_functions');

% Illustration of SVMA-IV identification bounds
% in Smets-Wouters (2007) DSGE model


%% Important settings

% Shock
plots.shock             = 'mp'; % Either 'mp' (monetary policy), 'tech' (technology shock); 'fg' (forward guidance)

% Model observables
settings.set_obsvars    = 1;    % Set of observables (see below for details)

% Plot settings
plots.iv_strength       = 0.5;  % Relative scale parameter for second IV in plot


%% Numerical settings

settings.VAR_poplaglength   = 350;      % Population VAR lag length
settings.use_KF             = 1;        % Use Kalman filter for FVR computations?
settings.VMA_hor            = 350;      % Maximal horizon in Wold/structural VMA representation; horizon M for bounds is set as function of that
settings.alpha_ngrid        = 1000;     % Grid points for lower bound on alpha
settings.bnd_recov          = 0;        % Weaker/practical lower bound on alpha?
settings.FVR_hor            = 1:1:11;           % Horizons for FVR analysis
settings.FVD_hor            = settings.FVR_hor; % Horizons for FVD analysis
settings.IRF_hor            = settings.FVR_hor; % Horizons for IRF analysis


%% Observables

if settings.set_obsvars == 1
    SW_model.obs_y = [5 4 19]; % (r,y,pi)
    SW_model.series = ['Interest Rate';'Real Output  ';'Inflation    '];
elseif settings.set_obsvars == 2
    SW_model.obs_y = [5 4 19 17 18]; % (r,y,pi,c,i)
    SW_model.series = ['Interest Rate';'Real Output  ';'Inflation    ';'Consumption  ';'Investment   '];
elseif settings.set_obsvars == 3
    SW_model.obs_y = [5 4 19 21]; % (r,y,pi,lab)
    SW_model.series = ['Interest Rate';'Real Output  ';'Inflation    ';'Hours        '];
elseif settings.set_obsvars == 4
    SW_model.obs_y = [5 4 19 17 18 20 21]; % (r,y,pi,c,i,w,lab)
    SW_model.series = ['Interest Rate';'Real Output  ';'Inflation    ';'Consumption  ';'Investment   ';'Wage         ';'Hours        '];
end


%% Solve model and collect properties

% Run Dynare
cd('_auxiliary_functions');
dynare(strcat('sw_', plots.shock, '_shock'), 'noclearall');
save_polfunction;
clean_folder;
load polfunction;

disp('I have solved and simulated the model.')

disp('Collecting model properties...')

% observables (includes IV)

SW_model.obs_x = [SW_model.obs_y, 34];

% specify shock

SW_model.shock = plots.shock;

% get IV parameters

SW_model.alpha    = alpha_ext;
SW_model.sigma_nu = sigma_nu_ext;

% size indicators

SW_model.n_y   = size(SW_model.obs_y,2);
SW_model.n_z   = 1;
SW_model.n_xi  = M_.exo_nbr; % 7 structural shocks + instrument noise
SW_model.n_eps = SW_model.n_xi - 1;
SW_model.n_nu  = 1;
SW_model.n_x   = SW_model.n_y + SW_model.n_z;
SW_model.n_s   = M_.nspred;

% get law of motion for all model variables

SW_model.decision = decision(2:end,:);

% ABCD representations

SW_model.ABCD = ABCD_fun(SW_model);

% delete superfluous variables

clean_workspace;

% Population IRFs + FVDs + Shock Sequences

[SW_model.IRF,SW_model.FVD,SW_model.M,SW_model.tot_weights] = pop_analysis(SW_model,settings);

disp('...done!')


%% Compute VAR Representation

disp('Getting the VAR representation...')
VAR_pop     = popVAR(SW_model,settings);
disp('...done!')


%% SVMA-IV analysis

disp('*** SVMA-IV analysis ***');

% Collect relevant second-moment properties
disp('Collecting implied second-moment properties...')
yzt_aux = get2ndmoments_VAR(VAR_pop,SW_model,settings);
disp('...done!')

% Compute bounds
settings.CI_for_R2_inv   = 1; % construct CI for R2_inv?
settings.CI_for_R2_recov = 1; % construct CI for R2_recov?
settings.CI_for_FVR      = 1; % construct CI for FVR?
settings.CI_for_FVD      = 1; % construct CI for FVD?
bounds_pop = get_IS(yzt_aux,SW_model,settings);


%% Plot SVMA-IV results

disp('Plotting results...')

% Scale parameter alpha

figure(1)
hold on
plot(bounds_pop.alpha_plot.omega_grid,bounds_pop.alpha_plot.alpha_LB_vals.^2,'linewidth',2,'linestyle','-','color',[0 0 0])
set(gcf,'color','w')
set(gca,'FontSize',18);
set(gca,'TickLabelInterpreter','latex')
title('Spectral Density of 2-Sided Predictor','fontsize',22,'interpreter','latex')
xlabel('Frequency','FontSize',20,'interpreter','latex')
xlim([0 pi])
ylim([0 1])
grid on
hold off
pos = get(gcf, 'Position');
set(gcf, 'Position', [pos(1) pos(2) 1.1*pos(3) 1*pos(4)]);
set(gcf, 'PaperPositionMode', 'auto');

% FVR

plotwidth = 0.275;
gapsize = 0.05;
gapsize_edges = (1-3*plotwidth-2*gapsize)/2;
left_pos = [gapsize_edges, gapsize_edges + gapsize + plotwidth, gapsize_edges + 2*gapsize + 2*plotwidth];
for j = 1:3
    figure(2)
    subplot(1,3,j)
    pos = get(gca, 'Position');
    pos(1) = left_pos(j);
    pos(3) = plotwidth;
    set(gca,'Position', pos)
    set(gca,'FontSize',18);
    set(gca,'TickLabelInterpreter','latex')
    hold on
    plot(settings.FVR_hor-1,bounds_pop.FVR_true(:,j),'linewidth',2,'linestyle','-','color',[0 0 0])
    plot(settings.FVR_hor-1,bounds_pop.FVR_UB(:,j),'linewidth',1,'linestyle',':','color',[0 0 0])
    plot(settings.FVR_hor-1,bounds_pop.FVR_LB(:,j),'linewidth',1,'linestyle','--','color',[0 0 0])
    plot(settings.FVR_hor-1,plots.iv_strength*bounds_pop.FVR_LB(:,j),'linewidth',1,'linestyle','--','color',[0 0 0])
    set(gcf,'color','w')
    xlim([0 size(settings.FVR_hor,2)-1])
    limsy=get(gca,'YLim');
    ylim([0 limsy(2)])
    xlabel('Horizon (Quarters)','FontSize',20,'interpreter','latex')
    title(['FVR of ',SW_model.series(j,:)],'fontsize',22,'interpreter','latex')
    if j == 2
        legend({'Truth','Upper Bound','Lower Bounds'},'Location','South','fontsize',20,'interpreter','latex')
    end
    grid on
    hold off
end
pos = get(gcf, 'Position');
set(gcf, 'Position', [pos(1) pos(2) 2.1*pos(3) 1.1*pos(4)]);
set(gcf, 'PaperPositionMode', 'auto');

clear gapsize gapsize_edges j left_pos plotwidth pos

% FVD

plotwidth = 0.275;
gapsize = 0.05;
gapsize_edges = (1-3*plotwidth-2*gapsize)/2;
left_pos = [gapsize_edges, gapsize_edges + gapsize + plotwidth, gapsize_edges + 2*gapsize + 2*plotwidth];
for j = 1:3
    figure(3)
    subplot(1,3,j)
    pos = get(gca, 'Position');
    pos(1) = left_pos(j);
    pos(3) = plotwidth;
    set(gca,'Position', pos)
    set(gca,'FontSize',18);
    set(gca,'TickLabelInterpreter','latex')
    hold on
    plot(settings.FVD_hor-1,SW_model.FVD(:,j),'linewidth',2,'linestyle','-','color',[0 0 0])
    plot(settings.FVD_hor-1,bounds_pop.FVD_LB(:,j),'linewidth',1,'linestyle','--','color',[0 0 0])
    plot(settings.FVD_hor-1,plots.iv_strength*bounds_pop.FVD_LB(:,j),'linewidth',1,'linestyle','--','color',[0 0 0])
    set(gcf,'color','w')
    xlim([0 size(settings.FVD_hor,2)-1])
    limsy=get(gca,'YLim');
    ylim([0 limsy(2)])
    xlabel('Horizon (Quarters)','FontSize',20,'interpreter','latex')
    title(['FVD of ',SW_model.series(j,:)],'fontsize',22,'interpreter','latex')
    if j == 2
        legend({'Truth','Lower Bounds'},'Location','South','fontsize',20,'interpreter','latex')
    end
    grid on
    hold off
end
pos = get(gcf, 'Position');
set(gcf, 'Position', [pos(1) pos(2) 2.1*pos(3) 1.1*pos(4)]);
set(gcf, 'PaperPositionMode', 'auto');

clear gapsize gapsize_edges j left_pos plotwidth pos

disp('...done!')


%% SVAR-IV analysis

disp('*** SVAR-IV analysis ***');

SW_model.FVR = bounds_pop.FVR_UB * bounds_pop.alpha_LB^2/SW_model.alpha^2; % True FVR in SW model

disp('Doing the SVAR-IV analysis...')
[SVARIV.IRF,SVARIV.FVD,SVARIV.weights] = SVARIV_analysis(VAR_pop,SW_model,settings);
disp('...done!')


%% Plot SVAR-IV results

disp('Plotting results...')

% IRF

plotwidth = 0.275;
gapsize = 0.05;
gapsize_edges = (1-3*plotwidth-2*gapsize)/2;
left_pos = [gapsize_edges, gapsize_edges + gapsize + plotwidth, gapsize_edges + 2*gapsize + 2*plotwidth];
for j = 1:3
    figure(4)
    subplot(1,3,j)
    pos = get(gca, 'Position');
    pos(1) = left_pos(j);
    pos(3) = plotwidth;
    set(gca,'Position', pos)
    set(gca,'FontSize',18);
    hold on
    plot(settings.IRF_hor-1,SW_model.IRF(1:settings.IRF_hor(end),j),'linewidth',2,'linestyle','-','color',[0 0 0])
    plot(settings.IRF_hor-1,SVARIV.IRF(1:settings.IRF_hor(end),j),'linewidth',2,'linestyle',':','color',[0 0 0])
    set(gcf,'color','w')
    xlim([0 settings.IRF_hor(end)-1])
    xlabel('Horizon (Quarters)','FontSize',22,'interpreter','latex')
    title(['IRF of ',SW_model.series(j,:)],'fontsize',25,'interpreter','latex')
    if j == 2
        legend({'Truth','SVAR-IV'},'Location','South','fontsize',16,'interpreter','latex')
    end
    grid on
    hold off
end
pos = get(gcf, 'Position');
set(gcf, 'Position', [pos(1) pos(2) 2.1*pos(3) 1.1*pos(4)]);
set(gcf, 'PaperPositionMode', 'auto');

clear gapsize gapsize_edges j left_pos plotwidth pos

% FVD

plotwidth = 0.275;
gapsize = 0.05;
gapsize_edges = (1-3*plotwidth-2*gapsize)/2;
left_pos = [gapsize_edges, gapsize_edges + gapsize + plotwidth, gapsize_edges + 2*gapsize + 2*plotwidth];
for j = 1:3
    figure(5)
    subplot(1,3,j)
    pos = get(gca, 'Position');
    pos(1) = left_pos(j);
    pos(3) = plotwidth;
    set(gca,'Position', pos)
    set(gca,'FontSize',18);
    hold on
    plot(settings.FVD_hor-1,SW_model.FVR(1:settings.FVD_hor(end),j),'linewidth',2,'linestyle','-','color',[0 0 0])
    plot(settings.FVD_hor-1,SVARIV.FVD(1:settings.FVD_hor(end),j),'linewidth',2,'linestyle',':','color',[0 0 0])
    set(gcf,'color','w')
    xlim([0 settings.FVD_hor(end)-1])
    ylim([0 1])
    xlabel('Horizon (Quarters)','FontSize',22,'interpreter','latex')
    title(['FVR of ',SW_model.series(j,:)],'fontsize',25,'interpreter','latex')
    if j == 2
        legend({'Truth','SVAR-IV'},'Location','North','fontsize',16,'interpreter','latex')
    end
    grid on
    hold off
end
pos = get(gcf, 'Position');
set(gcf, 'Position', [pos(1) pos(2) 2.1*pos(3) 1.1*pos(4)]);
set(gcf, 'PaperPositionMode', 'auto');

clear gapsize gapsize_edges j left_pos plotwidth pos

disp('...done!')


cd('..');

