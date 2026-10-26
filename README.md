# IEEE 33-Bus Distribution Network Analysis

## Overview
Steady-state AC power-flow analysis of the IEEE 33-bus
distribution network using MATLAB and MATPOWER.

## Project Objectives
- Analyze network voltage profiles and power losses
- Evaluate multiple electrical loading scenarios
- Study single-line outages and network connectivity
- Investigate restoration using tie switches
- Evaluate distributed solar PV integration

## Technologies
- MATLAB
- MATPOWER 8.1
- AC power-flow analysis
- Graph-based network analysis

## Network Model
The project uses the MATPOWER case33bw benchmark.

## Simulations
1. Base-case power flow
2. 20 percent load disturbance
3. Multiple loading scenarios
4. Single-line contingency analysis
5. Tie-switch network restoration
6. Solar PV integration at buses 6, 18 and 33
7. Engineering validation

## Results
Simulation data are available in the results folder.
Generated visualizations are available in figures.

## Running the Project
1. Install MATLAB and MATPOWER.
2. Add MATPOWER to the MATLAB search path.
3. Open disturbance_analysis.m.
4. Run the MATLAB script.
5. Review figures and results.

## Limitations
This study uses steady-state AC power flow.
It does not simulate transient stability or fault currents.
PV is represented as fixed active-power injection.
Voltage checks do not establish full grid-code compliance.

## Acknowledgement
The IEEE 33-bus benchmark is provided through MATPOWER.
Refer to MATPOWER documentation and licensing information.
