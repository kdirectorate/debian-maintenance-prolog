% ============================================================
% kernel_cleaner.pl - Lesson 1: First declarative policy rule
% ============================================================
%
% TEACHING NOTE:
% This file demonstrates the core idea of the entire project:
% We encode MAINTENANCE POLICY as pure logic rules.
% The rule below answers: "Which kernels are safe to remove?"
%
% It uses:
%   - Conjunction (,)          = logical AND
%   - Unification via variables
%   - Negation as failure (\=) = "not the same"
%
% This rule will later be extended with more safety conditions
% (e.g. keep the previous kernel, check dependencies, etc.).

:- module(kernel_cleaner, [removable_kernel/1]).

% -----------------------------------------------------------
% removable_kernel/1
% A kernel is removable if it is installed AND it is not the running kernel.
% -----------------------------------------------------------
removable_kernel(K) :-
    installed_kernel(K),
    running_kernel(Running),
    K \= Running.

% TEACHING NOTE:
% Because we have three installed_kernel facts and only one running_kernel,
% Prolog will find TWO solutions via backtracking.
% The running kernel itself will never be returned because K \= Running fails for it.