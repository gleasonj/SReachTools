function [underapprox_stoch_reach_avoid_polytope, ...
          optimal_input_vector_at_boundary_points, ...
          varargout] = ...
          getUnderapproxStochReachAvoidSet(...
                                        sys, ...
                                        target_tube, ...
                                        init_safe_set, ...
                                        probability_threshold_of_interest, ...
                                        tolerance_bisection, ...
                                        no_of_direction_vectors, ...
                                        affine_hull_of_interest_2D, ...
                                        varargin)
% SReachTools/stochasticReachAvoid/getUnderapproxStochReachAvoidSet: Obtain an
% open-loop controller-based underaproximative stochastic reach-avoid set using
% Fourier transform, convex optimization, and patternsearch
% =============================================================================
%
% getUnderapproxStochReachAvoidSet computes the open-loop controller-based
% underapproximative stochastic reach-avoid set  to the terminal hitting-time
% stochastic reach-avoid problem discussed in
%
% A. Vinod, and M. Oishi, "Scalable Underapproximative Verification of
% Stochastic LTI Systems Using Convexity and Compactness," in Proceedings of
% Hybrid Systems: Computation and Control (HSCC), 2018. 
%
% USAGE: See examples/verificationOfCwhDynamics.m
%
% =============================================================================
%
% [underapprox_stoch_reach_avoid_polytope, ...
%  optimal_input_vector_at_boundary_points, ...
%  varargout] = getUnderapproxStochReachAvoidSet(...
%                                        sys, ...
%                                        target_tube, ...
%                                        init_safe_set, ...
%                                        probability_threshold_of_interest, ...
%                                        tolerance_bisection, ...
%                                        no_of_direction_vectors, ...
%                                        affine_hull_of_interest_2D, ...
%                                        varargin)
% 
% Inputs:
% -------
%   sys                  - LtiSystem object describing the system to be verified
%   time_horizon         - Time horizon of the stochastic reach-avoid problem
%   target_tube          - Target tube to stay within [TargetTube object]
%   init_safe_set        - Safe set for initial state
%   probability_threshold_of_interest 
%                        - Probability threshold (\theta) that defines the
%                          stochastic reach-avoid set 
%                          {x_0: V_0^\ast( x_0) \geq \theta}
%   tolerance_bisection  - Bisection accuracy along each direction vector
%   no_of_direction_vectors
%                        - Number of unique directions defining the polytope
%                          vertices 
%   affine_hull_of_interest_2D
%                        - Affine hull whose slice of the stochastic reach-avoid
%                          set is of interest, Dimension state_dim-2
%                          Define this by Polyhedron('He',[A_eq, b_eq])
%   desired_accuracy     - (Optional) Accuracy expected for the integral of the
%                          Gaussian random vector X over the
%                          concatenated_target_tube [Default 5e-3]
%   PSoptions            - (Optional) Options for patternsearch [Default
%                          psoptimset('Display', 'off')]
%
% Outputs:
% --------
%   underapprox_stoch_reach_avoid_polytope
%                        - Underapproximative polytope of dimension
%                          sys.state_dim which underapproximates the
%                          terminal-hitting stochastic reach avoid set
%   optimal_input_vector_at_boundary_points 
%                        - Optimal open-loop policy ((sys.input_dim) *
%                          time_horizon)-dim.  vector U = [u_0; u_1; ...; u_N]
%                          (column vector) for each vertex of the polytope
%   xmax                 - (Optional) Initial state that has the maximum
%                          stochastic reach-avoid probability using an open-loop
%                          controller
%   optimal_input_vector_for_xmax
%                        - (Optional) Optimal open-loop policy
%                          ((sys.input_dim) * time_horizon)-dimensional
%                          vector U = [u_0; u_1; ...; u_N] (column vector) for
%                          xmax
%   max_underapprox_reach_avoid_prob
%                        - (Optional) Maximum attainable stochastic reach-avoid
%                          probability using an open-loop controller; Maximum
%                          terminal-hitting time reach-avoid probability at xmax
%   optimal_theta_i      - (Optional) Vector comprising of scaling factors along
%                          each direction of interest
%   optimal_reachAvoid_i - (Optional) Maximum terminal-hitting time reach-avoid
%                          probability at the vertices of the polytope
%
% See also examples/FtCVXUnderapproxVerifyCWH.mlx*.
%
% Notes:
% ------
% * NOT ACTIVELY TESTED: Builds on other tested functions.
% * MATLAB DEPENDENCY: Uses MATLAB's Global Optimization Toolbox; Statistics and
%                      Machine Learning Toolbox.
%                      Needs patternsearch for gradient-free optimization
%                      Needs normpdf, normcdf, norminv for Genz's algorithm
% * EXTERNAL DEPENDENCY: Uses MPT3 and CVX
%                      Needs MPT3 for defining a controlled system and the
%                      definition of the safe, the target (polytopic) sets, and
%                      the affine hull of interest
%                      Needs CVX to setup convex optimization problems that
%                      1) initializes the patternsearch-based optimization, and
%                      2) computes the upper bound for the bisection
% * Specify both desired_accuracy and PSoptions or neither to use the defaults 
% * max_underapprox_reach_avoid_prob is the highest threshold
%   that may be given while obtaining a non-trivial underapproximation
% * See @LtiSystem/getConcatMats for more information about the
%     notation used.
% 
% =============================================================================
% 
% This function is part of the Stochastic Reachability Toolbox.
% License for the use of this function is given in
%      https://github.com/unm-hscl/SReachTools/blob/master/LICENSE
%
%

    % DEPENDENCY CHECK: Check if dependencies have been installed correctly
    assert(exist('mpt_init','file')==2, ...
           'SReachTools:setup_error', ...
           ['This function uses MPT3. Please get it from ', ...
            'http://control.ee.ethz.ch/~mpt/3/.']);
    assert(exist('cvx_begin','file')==2, ...
           'SReachTools:setup_error', ...
           'This function uses CVX. Please get it from http://cvxr.com.');
    assert(exist('patternsearch','file')==2, ...
           'SReachTools:setup_error', ...
           'This function needs MATLAB''s Global Optimization Toolbox.');
    assert(exist('normcdf','file')==2, ...
           'SReachTools:setup_error', ...
           ['This function needs MATLAB''s Statistics and Machine Learning', ...
            ' Toolbox.']);

    % Get half space representation of the target tube and time horizon
    [concat_target_tube_A, concat_target_tube_b] = target_tube.concat();
    time_horizon = length(target_tube);
    
    % Construct U^N 
    % GUARANTEES: Non-empty input sets (polyhedron) and scalar
    %             time_horizon>0
    [concat_input_space_A, concat_input_space_b] = ...
                                        getConcatInputSpace(sys, time_horizon);

    % Check probability_threshold_of_interest is a scalar in (0,1]
    assert( isscalar(probability_threshold_of_interest) &&...
                probability_threshold_of_interest > 0 &&...
                probability_threshold_of_interest <= 1, ...
            'SReachTools:invalidArgs', ...
            'probability_threshold_of_interest must be a scalar in (0,1]');

    % Check tolerance_bisection is a scalar
    assert( isscalar(tolerance_bisection), ...
            'SReachTools:invalidArgs', ...
            'tolerance_bisection must be a scalar.');

    % Get the set of direction vectors
    % GUARANTEES: sanitized no_of_direction_vectors, affine_hull_of_interest_2D
    set_of_direction_vectors = computeDirectionVectors( ...
                                                 no_of_direction_vectors, ...
                                                 sys.state_dim, ...
                                                 affine_hull_of_interest_2D);

    % Compute H, mean_X_sans_input, cov_X_sans_input, Abar,
    % G_matrix. See @LtiSystem\getConcatMats for the notation.
    % GUARANTEES: Gaussian-perturbed LTI system (sys)
    [H, mean_X_sans_input_sans_initial_state, cov_X_sans_input, ...
     Abar, ~] = ...
     getHmatMeanCovForXSansInput(sys,zeros(sys.state_dim,1),time_horizon);

    % Parsing the optional arguments 
    if length(varargin) == 2
        % First optional argument is the desired_accuracy
        assert(isscalar(varargin{1}), ...
               'SReachTools:invalidArgs', ...
               'Expected a scalar value for desired_accuracy');
        desired_accuracy = varargin{1};
        % Second optional argument is the options for patternsearch,
        % PSoptions (TODO: No validation being done here)
        PSoptions = varargin{2};
    elseif isempty(varargin) == 0
        display_string = 'off';        % Turned it off to use the aligned output
        desired_accuracy = 1e-3;
        PSoptions = psoptimset('Display', display_string);
    else
        error('SReachTools:invalidArgs', ...
              ['desired_accuracy and PSoptions together are the only', ...
               ' additional options.']);
    end

    %% Computation of xmax and the associated optimal open-loop controller
    disp(['Computing the x_max for the Fourier transform-based ', ...
          'underapproximation']);
    [max_underapprox_reach_avoid_prob, ...
     xmax, ...
     optimal_input_vector_for_xmax] = ...
         computeXmaxForStochReachAvoidSetUnderapprox(...
                                        sys, ...
                                        time_horizon, ...
                                        init_safe_set, ...
                                        concat_input_space_A, ... 
                                        concat_input_space_b, ...
                                        concat_target_tube_A, ... 
                                        concat_target_tube_b, ...
                                        Abar, ...
                                        H, ...
                                        mean_X_sans_input_sans_initial_state, ...
                                        cov_X_sans_input, ...
                                        affine_hull_of_interest_2D, ...
                                        desired_accuracy, ...
                                        PSoptions);

    % If non-trivial underapproximative stochastic reach-avoid polytope
    if max_underapprox_reach_avoid_prob <...
        probability_threshold_of_interest
        % Stochastic reach-avoid underapproximation is empty and no admissible
        % open-loop policy exists
        fprintf(['Polytopic underapproximation does not exist for alpha =', ...
                 ' %1.2f since W(x_max) = %1.3f.\n\n'], ...
                 probability_threshold_of_interest, ...
                 max_underapprox_reach_avoid_prob);

        % Assigning the outputs to trivial results
        underapprox_stoch_reach_avoid_polytope = Polyhedron();
        optimal_input_vector_at_boundary_points = nan(...
                                          sys.input_dim * time_horizon, ...
                                          no_of_direction_vectors);
        optimal_theta_i = zeros(1, no_of_direction_vectors);
        optimal_reachAvoid_i = zeros(1, no_of_direction_vectors);
        optimal_inputs_i = nan(sys.input_dim * time_horizon, ...
                                 no_of_direction_vectors);
    else
        % Stochastic reach-avoid underapproximation is non-trivial
        fprintf(['Polytopic underapproximation exists for alpha = %1.2f ', ...
                 'since W(x_max) = %1.3f.\n\n'], ...
                 probability_threshold_of_interest, ...
                 max_underapprox_reach_avoid_prob);

        % For storing boundary points
        optimal_theta_i = zeros(1, no_of_direction_vectors);
        optimal_reachAvoid_i = zeros(1, no_of_direction_vectors);
        optimal_inputs_i = zeros(sys.input_dim * time_horizon, ...
                                 no_of_direction_vectors);

        %% Iterate over all direction vectors + xmax
        for direction_index = 1: no_of_direction_vectors
            % Get direction_index-th direction in the hyperplane
            direction = set_of_direction_vectors(:,direction_index);

            fprintf(['Analyzing direction (shown transposed) ', ...
                     ':%d/%d\n'],direction_index,no_of_direction_vectors);
            disp(direction');

            %% Bounds on theta \in [lower_bound_on_theta, upper_bound_on_theta]
            % Lower bound is always 0 as xmax could be a vertex
            lower_bound_on_theta = 0;
            % Computation of the upper bound
            A_times_direction = init_safe_set.A * direction;
            %% Compute theta_max for the given direction and update
            %% upper_bound_vector_theta_i(2), given by the optimization problem
            % minimize -theta
            % s.t.    theta*(A_init_safe_set*direction) <= init_safe_set.b-init_safe_set.A*xmax
            cvx_begin quiet
                variable theta(1)
                minimize -theta
                subject to
                    theta*A_times_direction <= init_safe_set.b-init_safe_set.A*xmax
            cvx_end
            upper_bound_on_theta = theta;
            fprintf('\bUpper bound of theta: %1.2f\n',upper_bound_on_theta);

            %% Maximum initial_state along the direction
            max_initial_state_along_direction = xmax + upper_bound_on_theta *...
                                                                    direction;

            %% Bisection-based computation of the maximum extension of the ray
            %% originating from xmax
            [optimal_theta_i(direction_index), ...
             optimal_inputs_i(:,direction_index), ...
             optimal_reachAvoid_i(direction_index)] = ...
                        computeBoundaryPointViaBisection(...
                            xmax, ...
                            direction, ...
                            max_underapprox_reach_avoid_prob, ...
                            optimal_input_vector_for_xmax, ...
                            lower_bound_on_theta, ...
                            upper_bound_on_theta, ...
                            tolerance_bisection, ...
                            probability_threshold_of_interest, ...
                            sys, ...
                            time_horizon, ...
                            concat_input_space_A, ... 
                            concat_input_space_b, ...
                            concat_target_tube_A, ... 
                            concat_target_tube_b, ...
                            H, ...
                            Abar, ...
                            mean_X_sans_input_sans_initial_state, ...
                            cov_X_sans_input, ...
                            desired_accuracy, ...
                            PSoptions);
        end
        %% Construction of underapprox_stoch_reach_avoid_polytope
        % TODO: Use native MPT based functions to provide projections (see end)
        vertex_underapprox_polytope = xmax +...
                                      optimal_theta_i.*set_of_direction_vectors;
        underapprox_stoch_reach_avoid_polytope = Polyhedron('V', ...
                                                  vertex_underapprox_polytope');
        % Assignment to the respective outputs of this function
        optimal_input_vector_at_boundary_points = optimal_inputs_i;
    end
    varargout{1} = xmax;
    varargout{2} = optimal_input_vector_for_xmax;
    varargout{3} = max_underapprox_reach_avoid_prob;
    varargout{4} = optimal_theta_i;
    varargout{5} = optimal_reachAvoid_i;
end

%% Alternatives to computing upper_bound_on_theta
% LINPROG: linprog-based computation for upper_bound_on_theta
%linprogOptions = optimoptions('linprog','Display','off');
%upper_bound_on_theta = linprog(-1, ...
%                               A_times_direction, ...
%                               init_safe_set.b-init_safe_set.A * xmax, ...
%                               [],[],[],[], ...
%                               linprogOptions);
% GUROBI: GUROBI-based computation for upper_bound_on_theta
%model_for_initial_guess_phi.obj = -1;
%model_for_initial_guess_phi.sense='<';
%model_for_initial_guess_phi.A = sparse(A_times_direction);
%model_for_initial_guess_phi.rhs = init_safe_set.b-init_safe_set.A*xmax;
%params.outputflag = 0;                        % Disable outputs of gurobi
%results = gurobi(model_for_initial_guess_phi,params);
%upper_bound_on_theta = results.x;

%% Checking if convex hull was computed properly
%minVRep(underapprox_stoch_reach_avoid_polytope);
%no_of_vertices_left = ...
%             size(underapprox_stoch_reach_avoid_polytope.V,1);
%if no_of_vertices_left ~= no_of_direction_vectors
%    fprintf(['\n### Convex hull ate away few points!\n No. of ', ...
%             'points left %d as opposed to %d\n'], ...
%             no_of_vertices_left, ...
%             no_of_direction_vectors);
%end

%% TODO: Use native MPT based functions to provide projections (see end)
% MPT requires vertices be specified row-wise (Don't give He because it
% can screw up the vertices due to numerical defects)
%, ...
%'He', affine_hull_of_interest_2D.He);
