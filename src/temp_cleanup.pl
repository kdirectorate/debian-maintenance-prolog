:- module(temp_cleanup, [
    file_should_be_deleted/1,    % AgeDays, SizeMB, FileTerm
    files_to_delete/4,
    reclaimed_space/2
]).

:- use_module(library(lists)).
:- use_module('config/default_policy').   % thresholds & whitelists live here

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
% MaxAgeDays or larger than MaxSizeMB. FileTerm is a temp_file(Path,
file_should_be_deleted(temp_file(_Path, SizeBytes, AgeSeconds)) :-
    AgeDays is AgeSeconds / 86400,
    SizeMB is SizeBytes / (1024*1024),
    max_temp_age_days(MaxAgeDays),
    max_temp_size_mb(MaxSizeMB),
    (   AgeDays > MaxAgeDays
    ;   SizeMB > MaxSizeMB
    ).

%% ============================================================
%% files_to_delete(+MaxAgeDays, +MaxSizeMB, +FileList, -ToDelete)
%% ============================================================
% Collect all files that meet the deletion policy using findall/3
files_to_delete(MaxAgeDays, MaxSizeMB, FileList, ToDelete) :-
    findall(
        F, 
        (member(F, FileList), file_should_be_deleted(MaxAgeDays, MaxSizeMB, F)), 
        ToDelete
    ).

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