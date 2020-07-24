%-------------------------------------------------------------------------%
%Filename:  neq.m
%Author:    Oliver Johnson
%Date:      7/15/2014
%
% NEQ performs a numerical equal to relational comparison with
% user specified precision.
%
% Inputs:
%   A,B - Two arrays of identical, but arbitrary, size and dimensions.
%   prec - A scalar indicating the number of digits after the decimal point
%          to consider in the comparison.
%
% Outputs:
%   tf - A logical array of the same size and dimensions as A and B, with
%        logical value true wherever A == B to within the given precision.
%
% Note: neq(x,x-10^(-prec),prec) == false       (greater-than)
%       neq(x,x-10^(-(prec+1)),prec) == true    (equal)
%       neq(x,x+10^(-(prec+1)),prec) == true    (equal)
%       neq(x,x+10^(-prec),prec) == false       (less-than)
%       neq(x,x+10^(-(prec-1)),prec) == false   (less-than)
%-------------------------------------------------------------------------%
function tf = neq(A,B,prec)

ep = roundp(A-B,prec);
tf = ep == 0;