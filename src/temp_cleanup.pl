:- module(temp_cleanup, [
    file_should_be_deleted/3,
    reclaimed_space/2,
    actually_remove_temp_file/4
]).

:- use_module(library(lists)).
:- use_module('config/default_policy').   % thresholds & whitelists live here
:- use_module('src/context').             % for temp_file/3
:- use_module('src/ssh_bridge').          % for py_remote_executor/5

%% ============================================================
%% file_should_be_deleted(+MaxAgeDays, +MaxSizeMB, +FileTerm)
%% ============================================================
% Declarative policy rule: a file should be deleted if it is older than
% MaxAgeDays and larger than MaxSizeMB. FileTerm is a temp_file(Path,
file_should_be_deleted(_Path, SizeMB, AgeDays) :-
    max_temp_age_days(MaxAgeDays),
    max_temp_size_mb(MaxSizeMB),
    AgeDays > MaxAgeDays,
    SizeMB > MaxSizeMB.

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

actually_remove_temp_file(Host, Port, User, temp_file(Path, _, _)) :-
    py_remote_executor(Host, Port, User, 
        "remove_file", _{path: Path}, 
        _
    ).

