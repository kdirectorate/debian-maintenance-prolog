% ============================================================
% temp_cleanup.pl - Lesson 2: Recursion, Lists, and Collections
% ============================================================

:- module(temp_cleanup,
    [ collect_temp_files/1,
      files_to_delete/2,
      reclaimed_space/2,
      should_delete_temp/1,
      temp_cleanup_plan/2
    ]).

% ------------------------------------------------------------
% collect_temp_files/1  —  Using findall/3
% ------------------------------------------------------------
collect_temp_files(Files) :-
    findall(temp_file(Path, Size, Age),
            temp_file(Path, Size, Age),
            Files).

% ------------------------------------------------------------
% The Policy Rule (declarative and easy to change)
% ------------------------------------------------------------
should_delete_temp(temp_file(_Path, Size, Age)) :-
    Age > 86400,          % older than 24 hours
    Size > 1048576.       % larger than 1 MiB

% ------------------------------------------------------------
% files_to_delete/2  —  Classic head/tail recursion
% ------------------------------------------------------------
files_to_delete([], []).

files_to_delete([File | Rest], [File | ToDeleteRest]) :-
    should_delete_temp(File),
    files_to_delete(Rest, ToDeleteRest).

files_to_delete([_Skip | Rest], ToDelete) :-
    files_to_delete(Rest, ToDelete).

% ------------------------------------------------------------
% reclaimed_space/2  —  Another recursion (summing)
% ------------------------------------------------------------
reclaimed_space([], 0).

reclaimed_space([temp_file(_, Size, _) | Rest], TotalBytes) :-
    reclaimed_space(Rest, RestBytes),
    TotalBytes is Size + RestBytes.

% ------------------------------------------------------------
% Convenience predicate
% ------------------------------------------------------------
temp_cleanup_plan(FilesToDelete, BytesReclaimed) :-
    collect_temp_files(All),
    files_to_delete(All, FilesToDelete),
    reclaimed_space(FilesToDelete, BytesReclaimed).