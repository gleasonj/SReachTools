classdef SrtInternalError < SrtBaseException
% SReachTools/SrtInternalError: Custom exception object for Socbox 
% internal errors
% ============================================================================
% 
% Customized class for generating Socbox internal errors, subclass of the 
% standard MATLAB SrtBaseException class
%
% Usage:
% ------
% exc = SrtInternalError('error message')
%
% ============================================================================
%
% See also MException
%
% ============================================================================
%
%   This function is part of the Stochastic Optimal Control Toolbox.
%   License for the use of this function is given in
%        https://github.com/unm-hscl/SReachTools/blob/master/LICENSE
% 
    
    properties (Constant, Access = private)
        mnemonic = 'internal';
    end
    
    methods
        function obj = SrtInternalError(varargin)
            obj@SrtBaseException(SrtInternalError.mnemonic, varargin{:}); 
        end
    end

    methods (Static)
        function id = getErrorId()
            id = [SrtBaseException.getErrorComponent(), ':', ...
                SrtInternalError.mnemonic];
        end
    end
    
end

