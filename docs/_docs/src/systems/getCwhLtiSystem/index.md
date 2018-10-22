---
layout: docs
title: getCwhLtiSystem.m
---

```
  Create a LtiSystem object for the spacecraft dynamics using 
  Clohessy-Wiltshire-Hill (CWH) dynamics
  =============================================================================
 
  Constructs a LtiSystem object for the discrete-time linear time-invariant
  dynamics of an approaching spacecraft (the deputy) relative to a target (the
  chief).
  
  In addition, you can provide:
  - an input space for the control inputs are the components of the external
    force vector, i.e. the thruster control input.  
  - an additive Gaussian noise process noise vector that represents the
    uncertainty in the model due to external forces on the spacecraft not
    captured in the linearized model.  
  - Other parameters relevant to the Clohessy-Wiltshire-Hill (CWH) dynamics in
    the form of a struct (see Notes) 
 
  The continuous-time is given in (1),(2) of
       K. Lesser, M. Oishi, and R. S. Erwin, "Stochastic Reachability for
       Control of Spacecraft Relative Motion", in Proceedings of IEEE
       Conference on Decision and Control, 2013. 
  Alternatively, see 
    - Curtis, Howard D. Orbital mechanics for engineering students.
      Butterworth-Heinemann, 2013, Section 7.4
 
  The state of the system is [position in x, position in y, position in z,
  velocity in x, velocity in y, and velocity in z].
 
  Usage:
  ------
 
  % Create a LtiSystem for the CWH dynamics using the parameters given in Lesser
  % et. al, CDC 2013 paper.
 
  sys = getCwhLtiSystem(4, Polyhedron('lb', -0.01*ones(2,1), ...
            'ub',  0.01*ones(2,1)), RandomVector('Gaussian', zeros(4,1), ...
            diag([1e-4, 1e-4, 5e-8, 5e-8])));
 
  % Create a LtiSystem for the uncontrolled 6D CWH dynamics
  sys = getCwhLtiSystem(6);
 
  % Create a LtiSystem for the uncontrolled 4D CWH dynamics
  sys = getCwhLtiSystem(4, Polyhedron(), RandomVector('Gaussian',zeros(4,1), ...
            diag([1e-4, 1e-4, 5e-8, 5e-8])));
 
  % Create a LtiSystem for the controlled 6D CWH dynamics
  sys = getCwhLtiSystem(6, ...
            Polyhedron('lb',-0.01*ones(3,1),'ub', 0.01*ones(3,1)), ...
            RandomVector('Gaussian', zeros(6,1), ...
                  diag([1e-4, 1e-4, 1e-4, 5e-8, 5e-8, 5e-8])));
 
  =============================================================================
  
  sys = getCwhLtiSystem(dim);
  sys = getCwhLtiSystem(dim, user_params);
  sys = getCwhLtiSystem(dim, user_params, Name, Value);
 
  Inputs:
  -------
    dim         - Dimension of the CWH dynamics of interest (Needs to be 4 or 6)
    input_space - (Optional) Input space for the spacecraft (Polytope)
                  [Provide an empty polyhedron to create an uncontrolled but
                   perturbed system]
    disturbance - (Optional) Stochastic disturbance object describing the
                  disturbance affecting the dynamics
    user_params - (Optional) User parameter struct that gives as a name-value
                  pair different parameters affecting the dynamics.  Possible
                  values that may be adjusted are --- sampling_period,
                  orbital_radius, grav_constant, celes_mass, chief_mass,
                  orbit_ang_vel, disc_orbit_dist 
                  [If empty, default values are set.]
 
  Outputs:
  --------
    sys - LtiSystem object describing the CWH dynamics
 
  Notes:
  ------
  * This code and the parameters were obtained from Lesser's repeatability code
    for the 2013 CDC paper.
  * The default parameters for the CWH system dynamics are:
        sampling period              = 20 s
        orbital radius               = 850 + 6378.1 m
        gravitational constant       = 6.673e-11
        celestial body mass          = 5.9472e24 kg
        gravitational body           = grav_constant * celes_mass / 1e6
        orbital angular velocity     = sqrt(grav_body / orbital_radius^3)
        chief mass                   = 300 kg
        discretized orbital distance = orbit_ang_vel * sampling_period rad
 
  =============================================================================
 
    This function is part of the Stochastic Reachability Toolbox.
    License for the use of this function is given in
         https://github.com/unm-hscl/SReachTools/blob/master/LICENSE
  
```