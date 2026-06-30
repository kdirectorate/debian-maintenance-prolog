:- module(temp_cleanup, [
    file_should_be_deleted/3,
    reclaimed_space/2
]).

:- use_module(library(lists)).
:- use_module('config/default_policy').   % thresholds & whitelists live here
:- use_module('src/ssh_bridge').  % for temp_file/3


/* Teaching note:
   Lesson 2 introduced head/tail recursion. We keep a recursive helper
   but also demonstrate findall + a filter predicate — both are valid
   and idiomatic. The filter predicate (file_should_be_deleted/3) is
   the declarative "policy rule".
*/


%% ============================================================
%% file_should_be_deleted(+MaxAgeDays, +MaxSizeMB, +FileTerm)
%% ============================================================
% Declarative policy rule: a file should be deleted if it is older than
% MaxAgeDays and larger than MaxSizeMB. FileTerm is a temp_file(Path,
file_should_be_deleted(Path, SizeMB, AgeDays) :-
    max_temp_age_days(MaxAgeDays),
    max_temp_size_mb(MaxSizeMB),
    AgeDays > MaxAgeDays,
    SizeMB > MaxSizeMB,
    format('~n[INFO] File ~w (~w MB, ~w days old) is older than ~w days and larger than ~w MB, marked for deletion.~n', [Path, SizeMB, AgeDays, MaxAgeDays, MaxSizeMB]).


%% ============================================================
%% reclaimed_space(+FileList, -TotalBytes)
%% ============================================================
% Sum the sizes of all files in FileList to compute the total space
% that would be reclaimed if they were deleted. This is a classic
% head/tail recursion pattern.
reclaimed_space([], 0).
reclaimed_space([temp_file(_, Size, _)|Rest], Total) :-
    reclaimed_space(Rest, RestTotal),
    Total is Size + RestTotal.