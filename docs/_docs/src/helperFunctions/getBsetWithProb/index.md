---
layout: docs
title: getBsetWithProb.m
---

```
  Get a scaled version of the user-specified polytope via bisection method
  =============================================================================
  
  This function solves the following optimization problem
 
    minimize    vol( \theta Polytope(A,b))
    subject to  Prob{ w \in \theta Polytope(A,b) } = \gamma
                \gamma > 0
  where w is a RandomVector object, Polytope(A,b) = Polyhedron('H',[A b]) is a 
  polytope given by {x: Ax<=b} that CONTAINS the origin, \gamma is a probability 
  threshold [0,1] that the optimal bounded set (\theta^\ast Polytope(A,b))
  must have the probability of occurence.
 
  This problem is solved using an equivalent single-variable convex 
  optimization problem in
 
    J. Gleason, A. Vinod, and M. Oishi, "Lagrangian Approximations for
    Stochastic Reachability of a Target Tube," 2018.
    https://arxiv.org/abs/1810.07118 TODO
 
  Usage: See SReachSetLagBset.
  
  =============================================================================
  
  bounded_set = getBsetWithProb(dist, polytope, prob_threshold, n_particles)
  
  Inputs:
  -------
    dist            - RandomVector object
    polytope        - Polyhedron object whose scaled version is the bounded_set                     
    prob_threshold  - Probability threshold (gamma)
    n_particles     - Number of particles to use in the Monte-Carlo
                      simulation estimation of the probability in 
                      RandomVector/getProbPolyhedron
  
  Outputs:
  --------
    bounded_set     - Polyhedron object
 
  Notes:
  ------
  * Prob{ w \in \theta Polytope(A,b) } is computed using
    RandomVector/getProbPolyhedron
  
  ============================================================================
 
    This function is part of the Stochastic Reachability Toolbox.
    License for the use of this function is given in
         https://github.com/unm-hscl/SReachTools/blob/master/LICENSE
 
```