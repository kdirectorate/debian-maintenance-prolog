:- module(kernel_cleaner, [
    removable_kernel/3,          % Running, InstalledList, Kernel
    keep_at_least_previous/3,     % optional policy hook for later
    actually_remove_kernels/4     % Host, Port, User, Kernels
]).

:- use_module('config/default_policy').
:- use_module(ssh_bridge).  % for py_remote_executor/5

/* ============================================================
   kernel_cleaner.pl
   Lesson 5 – Modularity + evolving from facts to passed data
   ============================================================ */

/* Teaching note:
   In Lessons 1–2 we used static facts (running_kernel/1, installed_kernel/1).
   Now that the SSH bridge gives us real data, we pass the data as arguments.
   This makes the predicates pure, testable, and easy to call from main.pl
   after the bridge returns JSON that we convert to Prolog lists.
*/

%% ============================================================
%% removable_kernel(+Running, +Installed, +K)
%% ============================================================
% Core safety rule (never remove the running kernel)
removable_kernel(Running, Installed, K) :-
    member(K, Installed),
    K \= Running.                    % negation as failure – safety guarantee

%% ============================================================
%% keep_at_least_previous(+Running, +Installed, +N, -ToRemove)
%% ============================================================
% Example policy hook we can extend later (Lesson 7):
% keep the running kernel + at least N previous kernels
keep_at_least_previous(Running, Installed, ToRemove) :-
    findall(K, removable_kernel(Running, Installed, K), Candidates),
    sort(Candidates, SortedCandidates),  % sort by version (lexical
    
    length(SortedCandidates, NumCandidates),
    kernels_to_keep(Keep),  % from default_policy.pl
    NumToKeep is max(0, NumCandidates - Keep),  % keep at least the running kernel
    length(ToRemove, NumToKeep),
    append(ToRemove, _, SortedCandidates).  % take the first NumToKeep candidates
    
actually_remove_kernels(Host, Port, User, Kernels) :-
    py_remote_executor(Host, Port, User, "purge_kernels", _{kernels: Kernels}, Response),
    ( Response.status = "success" ->
        format("[INFO] Successfully purged kernels.~n")
    ; format("[ERR] Failed to purge kernels: ~w~n", [Response.message]),
      fail
    ).

