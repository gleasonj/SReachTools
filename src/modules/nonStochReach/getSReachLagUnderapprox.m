function [underapprox_set, varargout] = getSReachLagUnderapprox(sys, ...
    target_tube, disturbance_set, equi_dir_vecs)
% Get underapproximation of stochastic reach set
% =========================================================================
%
% This function will compute the underapproximation of the stochastic reach
% set via Algorithm 1 in
% 
%      J. D. Gleason, A. P. Vinod, and M. M. K. Oishi. 2018. Lagrangian 
%      Approximations for Stochastic Reachability of a Target Tube. 
%      online. (2018). https://arxiv.org/abs/1810.07118
%
% Usage: See examples/lagrangianApproximations.m
%
% =========================================================================
%
% underapprox_set = getSReachLagUnderapprox(sys, target_tube, disturbance_set)
%
% Inputs:
% -------
%   sys              - LtiSystem object
%   target_tube      - Tube object
%   disturbance_set  - Polyhedron/SReachEllipsoid object (bounded set) OR a
%                       collection of these objects which individually satisfy 
%                       the probability bound(a convex hull of the individual 
%                       results taken posteriori)
%
% Outputs:
% --------
%   underapprox_set  - Polyhedron object
%   effective_target_tube
%                    - [Optional] Tube comprising of an underapproximation
%                           of the stochastic reach sets across the time horizon
%
% Notes:
% * From computational geometry, intersections and Minkowski differences are
%   best performed in facet representation and Minkowski sums are best
%   performed in vertex representation. However, since in this computation,
%   all three operations are required, scalability of the algorithm is severly
%   hampered, despite theoretical elegance.
%   
% =========================================================================
% 
%   This function is part of the Stochastic Reachability Toolbox.
%   License for the use of this function is given in
%        https://github.com/unm-hscl/SReachTools/blob/master/LICENSE
% 
% 

    % validate the inputs
    inpar = inputParser();
    inpar.addRequired('sys', @(x) validateattributes(x, ...
        {'LtiSystem', 'LtvSystem'}, {'nonempty'}));
    inpar.addRequired('target_tube', @(x) validateattributes(x, ...
        {'Tube'}, {'nonempty'}));
    inpar.addRequired('disturbance', @(x) validateattributes(x, ...
        {'Polyhedron','SReachEllipsoid'}, {'nonempty'}));
    
    try
        inpar.parse(sys, target_tube, disturbance_set);
    catch cause_exc
        exc = SrtInvalidArgsError.withFunctionName();
        exc = addCause(exc, cause_exc);
        throwAsCaller(exc);
    end
    
    if sys.state_dim > 4
        warning('SReachTools:runtime',['Because both vertex and facet ', ...
            'representation of polyhedra are required for the necessary set', ...
            ' recursion operations, computing for systems greater than 4 ', ...
            'dimensions can take significant computational time and effort.']);
    end
    
    tube_length = length(target_tube);
    n_disturbances = length(disturbance_set);


    % initialize polyhedron array
    effective_target_tube(tube_length) = target_tube(end);
    effective_target = effective_target_tube(end);

    if sys.islti()
        inverted_state_matrix = inv(sys.state_mat);
        minus_bu = (-sys.input_mat) * sys.input_space;
        dist_mat = sys.dist_mat;
        % minkSumInner TODO                    
        % Ainv_minus_bu = inverted_state_matrix * minus_bu;
    end
    
    if tube_length > 1
        if sys.state_dim > 2 && n_disturbances > 1
            % TODO [[url once note has been added to the google group]].'])
            warning('SReachTools:runtime', ['The convex hull operation may', ...
                'produce inconsistent or inaccurate results for systems ', ...
                'with dimensions greater than 2.'])
        end

        % iterate backwards
        for itt = tube_length-1:-1:1
            % Computing effective target tube for current_time
            current_time = itt - 1;
            if sys.isltv()
                % Overwrite the following parameters with their
                % time-varying counterparts
                inverted_state_matrix = inv(sys.state_mat(current_time));
                minus_bu = (-sys.input_mat(current_time)) * sys.input_space;
                dist_mat = sys.dist_mat(current_time);
                % minkSumInner TODO                    
                % Ainv_minus_bu = inverted_state_matrix * minus_bu;
            end
                
            vertices = [];
            
            for idist = 1:n_disturbances
                % Account for disturbance matrix
                if n_disturbances > 1
                    effective_dist = dist_mat * disturbance_set{idist};
                else
                    effective_dist = dist_mat * disturbance_set;
                end
                
                if isa(effective_dist, 'SReachEllipsoid')
                    % support function of the effective_dist - vectorized to
                    % handle Implementation of Kolmanovsky's 1998-based
                    % minkowski difference
                    new_target_A = effective_target.A;            
                    new_target_b = effective_target.b - ...
                        effective_dist.support_fun(new_target_A);
                    new_target= Polyhedron('H',[new_target_A new_target_b]);
                else                                   % MPT's Polyhedron object
                    if effective_dist.isEmptySet
                        % No requirement of robustness
                        new_target = effective_target;
                    else
                        % Compute a new target set for this iteration that
                        % is robust to the disturbance
                        new_target = effective_target - effective_dist;
                    end
                end

%               % One-step backward reach set via MPT
%               one_step_backward_reach_set = inverted_state_matrix *...
%                         (new_target + minus_bu);                    
%               % minkSumInner TODO                    
%                 one_step_backward_reach_set = minkSumInner(...
%                     inverted_state_matrix * new_target, Ainv_minus_bu);
                % Use ray-shooting algorithm to underapproximate one-step
                % backward reach set
                one_step_backward_reach_set = oneStepBackReachSet(sys,...
                    new_target, equi_dir_vecs);

                % Guarantee staying within target_tube by intersection
                effective_target = intersect(one_step_backward_reach_set,...
                    target_tube(itt));

                % Collect the vertices of the effective_target for each 
                % disturbance set to compute the convex hull. However, don't 
                % trigger conversion unless you really have to
                if n_disturbances > 1
                    vertices = [vertices; effective_target.V];                
                end
            end

            if n_disturbances > 1
                % Compute the polyhedron from the vertices
                effective_target_tube(itt) = Polyhedron(vertices);
            else
                effective_target_tube(itt) = effective_target;
            end
        end
    end     

    underapprox_set = effective_target_tube(1);
    if tube_length > 1 && nargout > 1
        varargout{1} = effective_target_tube;
    end
end

function under_polytope = oneStepBackReachSet(sys, target_set, equi_dir_vecs)
    [dir_vecs_dim, n_vertices] = size(equi_dir_vecs);
    if dir_vecs_dim ~= (sys.state_dim + sys.input_dim)
        throw(SrtInvalidArgsError(['Direction vectors should be a ',...
            'collection of column vectors, each (sys.state_dim + ',...
            'sys.input_dim)-dimensional.']));
    end
    
    % Compute the polytope in X*U
    x_u_reaches_target_set_A = [target_set.A*state_mat target_set.A*input_mat];
    x_u_reaches_target_set_Ae = [target_set.Ae*state_mat target_set.Ae*input_mat];
    x_u_reaches_target_set_b = target_set.b;
    x_u_reaches_target_set_be = target_set.be;
    x_u_reaches_target_set = Polyhedron('A',x_u_reaches_target_set_A,...
        'b', x_u_reaches_target_set_b, 'Ae',x_u_reaches_target_set_Ae,...
        'be', x_u_reaches_target_set_be);
    
    % Compute the chebyshev-center of x_u_reaches_target_set
    x_u_reaches_target_set_cheby = x_u_reaches_target_set.chebyCenter();
    
    % Compute vrep-based underapproximation
    boundary_point_mat = zeros(dir_vecs_dim, n_vertices);
    for dir_indx = 1:n_vertices
        cvx_begin quiet
            variable theta;
            variable boundary_point;
            
            maximize opt_theta;
            subject to
                theta >= 0;
                boundary_point == x_u_reaches_target_set_cheby +...
                    theta * equi_dir_vecs(:, dir_indx);
                x_u_reaches_target_set_A * boundary_point <=...
                    x_u_reaches_target_set_b;
                x_u_reaches_target_set_Ae * boundary_point ==...
                    x_u_reaches_target_set_be;
        cvx_end        
        switch cvx_status
            case 'Solved'
                boundary_point_mat (:, dir_indx) = boundary_point;
            case 'Inaccurate/Solved'
                warning('SReachTools:runTime', ['CVX returned ',...
                    'Inaccurate/Solved, while solving a subproblem for ',...
                    'Lagrangian underapproximation. Continuing nevertheless!']);
                boundary_point_mat (:, dir_indx) = boundary_point;
            otherwise
                throw(SrtDevError(sprintf(['Underapproximation failed! ',...
                    'CVX_status: %s'], cvx_status)));
        end
    end
    x_u_reaches_target_set_vrep_underapprox=Polyhedron('V',boundary_point_mat');
    
    % Compute projection onto the x space
    under_polytope =...
        x_u_reaches_target_set_vrep_underapprox.projection(1:sys.state_dim);    
    % Compute the half-space representation
    under_polytope.computeHRep();
end