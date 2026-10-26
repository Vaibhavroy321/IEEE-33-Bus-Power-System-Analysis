
%% =========================================================
% IEEE 33-BUS POWER SYSTEM DISTURBANCE ANALYSIS
% MATLAB + MATPOWER
%
% 1. Base-case power flow
% 2. 20% load disturbance
% 3. Multiple loading scenarios
% 4. Single-line contingency analysis
% 5. Tie-switch network restoration
% 6. Solar PV integration
% 7. Engineering validation
% 8. Export figures and CSV results
%% =========================================================

clear;
clc;
close all;

define_constants;

%% STEP 1: INITIALIZE PROJECT AND OUTPUT FOLDERS

% Use the location of this MATLAB script.
script_path = mfilename('fullpath');

if isempty(script_path)
    project_dir = pwd;
else
    project_dir = fileparts(script_path);
end

figures_dir = fullfile(project_dir, 'figures');
results_dir = fullfile(project_dir, 'results');

% Create folders if they do not exist.
if ~isfolder(figures_dir)
    [ok, msg] = mkdir(figures_dir);
    if ~ok
        error('Cannot create figures folder: %s', msg);
    end
end

if ~isfolder(results_dir)
    [ok, msg] = mkdir(results_dir);
    if ~ok
        error('Cannot create results folder: %s', msg);
    end
end

fprintf('\n====================================\n');
fprintf('IEEE 33-BUS POWER SYSTEM ANALYSIS\n');
fprintf('====================================\n');

fprintf('Project folder: %s\n', project_dir);
fprintf('Figures folder: %s\n', figures_dir);
fprintf('Results folder: %s\n', results_dir);

%% STEP 2: LOAD NETWORK

mpc = loadcase('case33bw');

opts = mpoption('verbose', 0, 'out.all', 0);

bus_ids = mpc.bus(:, BUS_I);
nb = size(mpc.bus, 1);
nl = size(mpc.branch, 1);

V_limit = 0.95;
V_upper = 1.05;

fprintf('\nBuses: %d\n', nb);
fprintf('Branches: %d\n', nl);

%% STEP 3: BASE-CASE POWER FLOW

base = runpf(mpc, opts);

assert(base.success, 'Base power flow failed');

bus = base.bus(:, BUS_I);
V_base = base.bus(:, VM);

base_losses = base.branch(:, PF) + ...
              base.branch(:, PT);

total_loss_base = sum(base_losses) * 1000;

fprintf('\n--- BASE CASE ---\n');
fprintf('Minimum voltage: %.4f p.u.\n', min(V_base));
fprintf('Power losses: %.3f kW\n', total_loss_base);

%% STEP 4: 20% LOAD DISTURBANCE

mpc2 = mpc;

mpc2.bus(:, PD) = 1.20 * mpc.bus(:, PD);
mpc2.bus(:, QD) = 1.20 * mpc.bus(:, QD);

disturbed = runpf(mpc2, opts);

assert(disturbed.success, ...
    '20 percent load scenario failed');

V_disturbed = disturbed.bus(:, VM);

voltage_drop = V_base - V_disturbed;

disturbed_losses = disturbed.branch(:, PF) + ...
                   disturbed.branch(:, PT);

total_loss_disturbed = ...
    sum(disturbed_losses) * 1000;

loss_increase = 100 * ...
    (total_loss_disturbed - total_loss_base) ...
    / total_loss_base;

fprintf('\n--- 20%% LOAD DISTURBANCE ---\n');

fprintf('Minimum voltage: %.4f p.u.\n', ...
    min(V_disturbed));

fprintf('Power losses: %.3f kW\n', ...
    total_loss_disturbed);

fprintf('Loss increase: %.2f %%\n', ...
    loss_increase);

%% GRAPH 1: VOLTAGE PROFILE

figure('Name', 'Voltage Profile');

plot(bus, V_base, 'b-o', 'LineWidth', 1.5);
hold on;

plot(bus, V_disturbed, 'r--s', ...
    'LineWidth', 1.5);

yline(V_limit, 'k:', '0.95 p.u.');

xlabel('Bus Number');
ylabel('Voltage (p.u.)');
title('Voltage Profile Under 20% Load Increase');

legend('Normal', '20% Increased Load', ...
    'Voltage Limit', 'Location', 'best');

grid on;

%% GRAPH 2: POWER LOSS COMPARISON

figure('Name', 'Power Loss Comparison');

bar([total_loss_base, total_loss_disturbed]);

set(gca, 'XTick', 1:2, ...
    'XTickLabel', {'Normal', '+20% Load'});

ylabel('Active Power Loss (kW)');
title('Power Loss Comparison');

grid on;

%% STEP 5: FIVE LOWEST-VOLTAGE BUSES

[sorted_V, sorted_idx] = sort(V_disturbed);

weak_buses = bus(sorted_idx(1:5));
weak_voltages = sorted_V(1:5);

weak_table = table(weak_buses, weak_voltages, ...
    'VariableNames', ...
    {'Bus_Number', 'Voltage_pu'});

fprintf('\n--- FIVE LOWEST-VOLTAGE BUSES ---\n');

disp(weak_table);

%% GRAPH 3: BUS VOLTAGE REDUCTION

figure('Name', 'Bus Voltage Drop');

bar(bus, voltage_drop);

xlabel('Bus Number');
ylabel('Voltage Reduction (p.u.)');
title('Voltage Reduction Due to Increased Load');

grid on;

%% STEP 6: VOLTAGE VIOLATIONS

normal_violations = sum(V_base < V_limit);

disturbed_violations = ...
    sum(V_disturbed < V_limit);

fprintf('\n--- VOLTAGE VIOLATIONS ---\n');

fprintf('Normal: %d buses\n', normal_violations);
fprintf('Disturbed: %d buses\n', disturbed_violations);

%% GRAPH 4: VOLTAGE VIOLATIONS

figure('Name', 'Voltage Violations');

bar([normal_violations, disturbed_violations]);

set(gca, 'XTick', 1:2, ...
    'XTickLabel', {'Normal', '+20% Load'});

ylabel('Buses Below 0.95 p.u.');
title('Undervoltage Comparison');

grid on;

%% =========================================================
% STEP 7: MULTIPLE LOAD SCENARIOS
%% =========================================================

fprintf('\n====================================\n');
fprintf('MULTIPLE LOAD SCENARIOS\n');
fprintf('====================================\n');

load_factors = [1.0 1.1 1.2 1.3 1.5];

n = numel(load_factors);

voltage_profiles = NaN(nb, n);
min_voltages = NaN(n, 1);
power_losses = NaN(n, 1);
voltage_violations = NaN(n, 1);
converged = false(n, 1);

for k = 1:n

    test_case = mpc;

    test_case.bus(:, PD) = ...
        load_factors(k) * mpc.bus(:, PD);

    test_case.bus(:, QD) = ...
        load_factors(k) * mpc.bus(:, QD);

    result = runpf(test_case, opts);

    if ~result.success
        fprintf('Load %.2f: FAILED\n', load_factors(k));
        continue;
    end

    converged(k) = true;

    V = result.bus(:, VM);

    voltage_profiles(:, k) = V;
    min_voltages(k) = min(V);

    losses = result.branch(:, PF) + ...
             result.branch(:, PT);

    power_losses(k) = sum(losses) * 1000;

    voltage_violations(k) = sum(V < V_limit);

    fprintf('Load %.2f: SUCCESS\n', load_factors(k));

end

load_results = table( ...
    load_factors(:), converged, min_voltages, ...
    power_losses, voltage_violations, ...
    'VariableNames', { ...
    'Load_Factor', 'Converged', ...
    'Minimum_Voltage', 'Loss_kW', ...
    'Undervoltage_Buses'});

disp(load_results);

writetable(load_results, ...
    fullfile(results_dir, 'load_disturbance_results.csv'));

%% GRAPH 5: MULTIPLE VOLTAGE PROFILES

figure('Name', 'Multiple Load Voltage Profiles');

plot(bus, voltage_profiles, 'LineWidth', 1.5);

xlabel('Bus Number');
ylabel('Voltage (p.u.)');
title('Voltage Profiles for Different Loads');

legend('100%', '110%', '120%', '130%', '150%', ...
    'Location', 'best');

grid on;

%% GRAPH 6: MINIMUM VOLTAGE

figure('Name', 'Minimum Voltage Analysis');

plot(load_factors, min_voltages, '-o', ...
    'LineWidth', 2);

hold on;
yline(V_limit, 'r--', '0.95 p.u.');

xlabel('Load Multiplier');
ylabel('Minimum Voltage (p.u.)');
title('Minimum Voltage vs Load');

grid on;

%% GRAPH 7: POWER LOSS SENSITIVITY

figure('Name', 'Power Loss Sensitivity');

plot(load_factors, power_losses, '-s', ...
    'LineWidth', 2);

xlabel('Load Multiplier');
ylabel('Power Loss (kW)');
title('Power Loss vs Load');

grid on;

%% GRAPH 8: LOAD-RELATED VOLTAGE VIOLATIONS

figure('Name', 'Voltage Violations by Scenario');

bar(load_factors, voltage_violations);

xlabel('Load Multiplier');
ylabel('Buses Below 0.95 p.u.');
title('Voltage Violations vs Load');

grid on;

%% =========================================================
% STEP 8: LINE OUTAGE ANALYSIS
%% =========================================================

fprintf('\n====================================\n');
fprintf('LINE OUTAGE ANALYSIS\n');
fprintf('====================================\n');

closed_lines = find(mpc.branch(:, BR_STATUS) == 1);
tie_lines = find(mpc.branch(:, BR_STATUS) == 0);

n_closed = numel(closed_lines);

line_number = closed_lines;

from_bus = mpc.branch(closed_lines, F_BUS);
to_bus = mpc.branch(closed_lines, T_BUS);

isolated_count = zeros(n_closed, 1);
is_connected = false(n_closed, 1);

slack_id = mpc.bus( ...
    mpc.bus(:, BUS_TYPE) == REF, BUS_I);

assert(numel(slack_id) == 1, ...
    'Expected one slack bus');

slack_idx = find(bus_ids == slack_id);

for j = 1:n_closed

    k = closed_lines(j);

    candidate = mpc;

    candidate.branch(k, BR_STATUS) = 0;

    active = candidate.branch(:, BR_STATUS) == 1;

    f = candidate.branch(active, F_BUS);
    t = candidate.branch(active, T_BUS);

    [okF, fi] = ismember(f, bus_ids);
    [okT, ti] = ismember(t, bus_ids);

    assert(all(okF & okT), ...
        'Invalid branch endpoint');

    % Include all buses, even isolated ones.
    G = graph(fi, ti, [], nb);

    components = conncomp(G);

    source_component = components(slack_idx);

    isolated = components(:) ~= source_component;

    isolated_count(j) = sum(isolated);

    is_connected(j) = ...
        isolated_count(j) == 0;

    fprintf('Line %d (%d-%d): %d buses isolated\n', ...
        k, from_bus(j), to_bus(j), ...
        isolated_count(j));

end

contingency_results = table( ...
    line_number, from_bus, to_bus, ...
    isolated_count, is_connected, ...
    'VariableNames', { ...
    'Line', 'From_Bus', 'To_Bus', ...
    'Isolated_Buses', 'Connected'});

disp(contingency_results);

writetable(contingency_results, ...
    fullfile(results_dir, 'line_outage_results.csv'));

%% GRAPH 9: LINE OUTAGE IMPACT

figure('Name', 'Line Outage Impact');

bar(line_number, isolated_count);

xlabel('Disconnected Branch');
ylabel('Isolated Buses');
title('Impact of Single-Line Outages');

grid on;

%% =========================================================
% STEP 9: NETWORK RESTORATION
%% =========================================================

fprintf('\n====================================\n');
fprintf('NETWORK RESTORATION\n');
fprintf('====================================\n');

fault_line = 7;

assert(ismember(fault_line, closed_lines), ...
    'Faulted branch must initially be closed');

fault_case = mpc;
fault_case.branch(fault_line, BR_STATUS) = 0;

n_ties = numel(tie_lines);

tie_id = tie_lines;
tie_from = mpc.branch(tie_lines, F_BUS);
tie_to = mpc.branch(tie_lines, T_BUS);

connected = false(n_ties, 1);
radial = false(n_ties, 1);
pf_converged = false(n_ties, 1);

min_voltage = NaN(n_ties, 1);
loss_kW = NaN(n_ties, 1);

for j = 1:n_ties

    candidate = fault_case;

    candidate.branch(tie_lines(j), BR_STATUS) = 1;

    active = candidate.branch(:, BR_STATUS) == 1;

    f = candidate.branch(active, F_BUS);
    t = candidate.branch(active, T_BUS);

    [okF, fi] = ismember(f, bus_ids);
    [okT, ti] = ismember(t, bus_ids);

    assert(all(okF & okT), ...
        'Invalid restoration branch endpoint');

    G = graph(fi, ti, [], nb);

    connected(j) = ...
        numel(unique(conncomp(G))) == 1;

    radial(j) = connected(j) && ...
        numedges(G) == nb - 1;

    if ~(connected(j) && radial(j))
        fprintf('Tie %d: Invalid topology\n', tie_lines(j));
        continue;
    end

    result = runpf(candidate, opts);

    pf_converged(j) = result.success;

    if ~result.success
        fprintf('Tie %d: Power flow failed\n', tie_lines(j));
        continue;
    end

    min_voltage(j) = min(result.bus(:, VM));

    losses = result.branch(:, PF) + ...
             result.branch(:, PT);

    loss_kW(j) = sum(losses) * 1000;

    fprintf('Tie %d: Vmin %.4f, Loss %.2f kW\n', ...
        tie_lines(j), min_voltage(j), loss_kW(j));

end

restoration_results = table( ...
    tie_id, tie_from, tie_to, ...
    connected, radial, pf_converged, ...
    min_voltage, loss_kW, ...
    'VariableNames', { ...
    'Tie_Line', 'From_Bus', 'To_Bus', ...
    'Connected', 'Radial', 'PF_Success', ...
    'Minimum_Voltage', 'Loss_kW'});

disp(restoration_results);

writetable(restoration_results, ...
    fullfile(results_dir, 'network_restoration_results.csv'));

valid_restoration = ...
    connected & radial & pf_converged;

if any(valid_restoration)

    valid_idx = find(valid_restoration);

    [best_restoration_loss, local_idx] = ...
        min(loss_kW(valid_idx));

    best_idx = valid_idx(local_idx);

    fprintf('\nBest converged radial restoration:\n');
    fprintf('Close tie branch: %d\n', tie_id(best_idx));
    fprintf('Loss: %.3f kW\n', best_restoration_loss);

else

    fprintf('\nNo valid single-tie restoration found.\n');

end

%% GRAPH 10: RESTORATION LOSSES

figure('Name', 'Restoration Power Losses');

bar(tie_id, loss_kW);

xlabel('Tie Switch Branch');
ylabel('Active Power Loss (kW)');
title('Restoration Loss Comparison');

grid on;

%% GRAPH 11: RESTORATION VOLTAGE

figure('Name', 'Restoration Voltage Comparison');

bar(tie_id, min_voltage);

hold on;
yline(V_limit, 'r--', '0.95 p.u.');

xlabel('Tie Switch Branch');
ylabel('Minimum Voltage (p.u.)');
title('Voltage After Restoration');

grid on;

%% =========================================================
% STEP 10: SOLAR PV INTEGRATION
%% =========================================================

fprintf('\n====================================\n');
fprintf('SOLAR PV INTEGRATION\n');
fprintf('====================================\n');

pv_buses = [6 18 33];

pv_capacity_kW = 500;
pv_capacity_MW = pv_capacity_kW / 1000;

n_pv = numel(pv_buses);

pv_voltage_profiles = NaN(nb, n_pv);

pv_success = false(n_pv, 1);
pv_min_voltage = NaN(n_pv, 1);
pv_max_voltage = NaN(n_pv, 1);
pv_losses = NaN(n_pv, 1);
pv_violations = NaN(n_pv, 1);

for j = 1:n_pv

    pv_case = mpc;

    bus_idx = find( ...
        pv_case.bus(:, BUS_I) == pv_buses(j));

    assert(numel(bus_idx) == 1, ...
        'PV bus not found');

    % Fixed active injection at unity power factor.
    % Negative net demand represents PV generation.
    pv_case.bus(bus_idx, PD) = ...
        pv_case.bus(bus_idx, PD) - pv_capacity_MW;

    result = runpf(pv_case, opts);

    if ~result.success
        fprintf('PV bus %d: FAILED\n', pv_buses(j));
        continue;
    end

    pv_success(j) = true;

    V = result.bus(:, VM);

    pv_voltage_profiles(:, j) = V;

    pv_min_voltage(j) = min(V);
    pv_max_voltage(j) = max(V);

    losses = result.branch(:, PF) + ...
             result.branch(:, PT);

    pv_losses(j) = sum(losses) * 1000;

    pv_violations(j) = sum(V < V_limit);

    fprintf('PV bus %d: Vmin %.4f, Loss %.2f kW\n', ...
        pv_buses(j), pv_min_voltage(j), pv_losses(j));

end

loss_reduction_percent = ...
    100 * (total_loss_base - pv_losses) ...
    / total_loss_base;

pv_results = table( ...
    pv_buses(:), ...
    repmat(pv_capacity_kW, n_pv, 1), ...
    pv_success, pv_min_voltage, ...
    pv_max_voltage, pv_losses, ...
    loss_reduction_percent, pv_violations, ...
    'VariableNames', { ...
    'PV_Bus', 'Capacity_kW', 'Converged', ...
    'Minimum_Voltage', 'Maximum_Voltage', ...
    'Loss_kW', 'Loss_Reduction_Percent', ...
    'Undervoltage_Buses'});

disp(pv_results);

writetable(pv_results, ...
    fullfile(results_dir, 'solar_pv_results.csv'));

%% GRAPH 12: PV VOLTAGE PROFILES

figure('Name', 'Solar PV Voltage Profiles');

plot(bus, V_base, 'k-', 'LineWidth', 2);
hold on;

plot(bus, pv_voltage_profiles, ...
    'LineWidth', 1.5);

yline(V_limit, 'r:', '0.95 p.u.');

xlabel('Bus Number');
ylabel('Voltage (p.u.)');
title('Voltage Profiles With Solar PV');

legend('No PV', 'PV Bus 6', ...
    'PV Bus 18', 'PV Bus 33', ...
    'Voltage Limit', 'Location', 'best');

grid on;

%% GRAPH 13: PV NETWORK LOSSES

figure('Name', 'PV Network Loss Comparison');

bar([total_loss_base; pv_losses]);

set(gca, 'XTick', 1:4, ...
    'XTickLabel', ...
    {'No PV', 'Bus 6', 'Bus 18', 'Bus 33'});

ylabel('Power Loss (kW)');
title('Network Losses With PV');

grid on;

%% GRAPH 14: PV MINIMUM VOLTAGE

figure('Name', 'PV Minimum Voltage Comparison');

bar([min(V_base); pv_min_voltage]);

hold on;
yline(V_limit, 'r--', '0.95 p.u.');

set(gca, 'XTick', 1:4, ...
    'XTickLabel', ...
    {'No PV', 'Bus 6', 'Bus 18', 'Bus 33'});

ylabel('Minimum Voltage (p.u.)');
title('Minimum Voltage With PV');

grid on;

%% GRAPH 15: PV LOSS REDUCTION

figure('Name', 'PV Loss Reduction');

bar(pv_buses, loss_reduction_percent);

xlabel('PV Installation Bus');
ylabel('Loss Reduction (%)');
title('Loss Reduction by PV Location');

grid on;

%% STEP 11: BEST PV LOCATION

valid_pv = find(pv_success);

if ~isempty(valid_pv)

    [best_pv_loss, local_idx] = ...
        min(pv_losses(valid_pv));

    best_idx = valid_pv(local_idx);

    fprintf('\n--- BEST PV LOCATION BY LOSSES ---\n');

    fprintf('PV bus: %d\n', pv_buses(best_idx));
    fprintf('Loss: %.3f kW\n', best_pv_loss);

    fprintf('Loss reduction: %.2f %%\n', ...
        loss_reduction_percent(best_idx));

else

    fprintf('No PV scenario converged.\n');

end

%% =========================================================
% STEP 12: ENGINEERING VALIDATION
%% =========================================================

fprintf('\n====================================\n');
fprintf('ENGINEERING VALIDATION\n');
fprintf('====================================\n');

base_voltage_error = ...
    max(abs(voltage_profiles(:, 1) - V_base));

base_loss_error = ...
    abs(power_losses(1) - total_loss_base);

base_check = converged(1) && ...
    base_voltage_error < 1e-6 && ...
    base_loss_error < 1e-4;

all_loads_ok = all(converged);

all_closed_lines_tested = ...
    numel(line_number) == numel(closed_lines);

restoration_found = any(valid_restoration);

all_pv_ok = all(pv_success);

pv_reduces_losses = ...
    any(pv_success & pv_losses < total_loss_base);

validation_name = { ...
    'Base case consistency'; ...
    'All load scenarios converged'; ...
    'All closed lines tested'; ...
    'At least one restoration found'; ...
    'All PV scenarios converged'; ...
    'At least one PV case reduces losses'};

validation_pass = [ ...
    base_check; ...
    all_loads_ok; ...
    all_closed_lines_tested; ...
    restoration_found; ...
    all_pv_ok; ...
    pv_reduces_losses];

validation_table = table( ...
    validation_name, validation_pass, ...
    'VariableNames', ...
    {'Validation_Check', 'Passed'});

disp(validation_table);

writetable(validation_table, ...
    fullfile(results_dir, 'validation_results.csv'));

% Additional voltage screening
fprintf('\n--- VOLTAGE SCREENING ---\n');

fprintf('Base case within 0.95-1.05 p.u.: %d\n', ...
    all(V_base >= V_limit & V_base <= V_upper));

fprintf('PV cases within 0.95-1.05 p.u.:\n');

for j = 1:n_pv

    if pv_success(j)

        voltage_ok = ...
            pv_min_voltage(j) >= V_limit && ...
            pv_max_voltage(j) <= V_upper;

        fprintf('Bus %d: %d\n', ...
            pv_buses(j), voltage_ok);

    end

end

%% =========================================================
% STEP 13: EXPORT ALL FIGURES
% CORRECTED ABSOLUTE-PATH VERSION
%% =========================================================

fprintf('\n====================================\n');
fprintf('EXPORTING ALL FIGURES\n');
fprintf('====================================\n');

% Ensure the folder exists before exporting.
if ~isfolder(figures_dir)

    [ok, msg] = mkdir(figures_dir);

    if ~ok
        error('Cannot create figure folder: %s', msg);
    end

end

% Find all figures.
all_figures = findall(0, 'Type', 'figure');

% Sort by figure number.
[~, order] = sort([all_figures.Number]);

all_figures = all_figures(order);

export_count = 0;

for k = 1:numel(all_figures)

    fig = all_figures(k);

    % Get figure title.
    fig_name = get(fig, 'Name');

    if isempty(fig_name)
        fig_name = sprintf('Figure_%02d', k);
    end

    % Remove characters invalid in filenames.
    fig_name = regexprep(fig_name, ...
        '[^a-zA-Z0-9_-]', '_');

    % Create complete absolute destination.
    filename = fullfile( ...
        figures_dir, ...
        sprintf('%02d_%s.png', k, fig_name));

    % Export with fallback.
    try

        exportgraphics(fig, filename, ...
            'Resolution', 300);

        export_count = export_count + 1;

        fprintf('Saved: %s\n', filename);

    catch ME

        warning('exportgraphics failed: %s', ...
            ME.message);

        try

            saveas(fig, filename);

            export_count = export_count + 1;

            fprintf('Saved using fallback: %s\n', ...
                filename);

        catch ME2

            warning('Figure %d could not be saved: %s', ...
                k, ME2.message);

        end

    end

end

%% STEP 14: FINAL PROJECT SUMMARY

fprintf('\n====================================\n');
fprintf('FINAL PROJECT SUMMARY\n');
fprintf('====================================\n');

fprintf('Network: IEEE 33-bus\n');
fprintf('Software: MATLAB + MATPOWER\n');

fprintf('Load scenarios: %d\n', ...
    numel(load_factors));

fprintf('Line contingencies: %d\n', ...
    numel(closed_lines));

fprintf('Tie-switch candidates: %d\n', ...
    numel(tie_lines));

fprintf('PV placement scenarios: %d\n', ...
    numel(pv_buses));

fprintf('Figures exported: %d of %d\n', ...
    export_count, numel(all_figures));

fprintf('\nFigure directory:\n%s\n', figures_dir);

fprintf('\nResults directory:\n%s\n', results_dir);

fprintf('\nSIMULATION SCRIPT FINISHED.\n');
