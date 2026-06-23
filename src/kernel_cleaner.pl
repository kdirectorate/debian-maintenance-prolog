:- module(kernel_cleaner, [
    removable_kernel/3,          % Running, InstalledList, Kernel
    safe_to_remove_kernels/3,    % Running, InstalledList, SafeList
    keep_at_least_previous/4     % optional policy hook for later
]).

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
%% safe_to_remove_kernels(+Running, +Installed, -SafeList)
%% ============================================================
% Collect all safe-to-remove kernels using findall/3
% findall is like a declarative list comprehension: "collect every K
% for which removable_kernel/3 succeeds"
safe_to_remove_kernels(Running, Installed, SafeList) :-
    findall(K, removable_kernel(Running, Installed, K), SafeList).

%% ============================================================
%% keep_at_least_previous(+Running, +Installed, +N, -ToRemove)
%% ============================================================
% Example policy hook we can extend later (Lesson 7):
% keep the running kernel + at least N previous kernels
keep_at_least_previous(Running, Installed, _N, ToRemove) :-
    safe_to_remove_kernels(Running, Installed, Candidates),
    % for now we just return all candidates; later we can sort by version
    % and drop the last N
    ToRemove = Candidates.