% ============================================================
% main.pl - Lesson 1 entry point
% ============================================================
%
% TEACHING NOTE:
% For Lesson 1 we use the simple consult/1 mechanism.
% In Lesson 5 we will convert everything to proper modules
% with use_module/1 for better encapsulation.

:- consult('facts.pl').
:- consult('kernel_cleaner.pl').
:- use_module('process_utils').
:- use_module('temp_cleanup').
:- use_module('facts').
:- use_module('ssh_bridge').

% Optional banner so you know the files loaded cleanly
show_banner :-
    format('~n=== Debian System Maintenance Tool ===~n').

run_demos :-
    show_banner,
    demo_lesson1,
    demo_lesson2,
    demo_lesson3.

% ============================================================
% demo_lesson1 - Convenience helper for Lesson 1 testing
% ============================================================
demo_lesson1 :-
    format('~n=== Lesson 1 Demo: Kernel Removal Policy ===~n~n'),

    running_kernel(Running),
    format('Currently running kernel: ~w~n~n', [Running]),

    findall(K, removable_kernel(K), Removable),
    length(Removable, Count),

    format('Kernels safe to remove: ~w~n', [Count]),
    (   Removable = []
    ->  format('No other kernels can be removed.~n')
    ;   format('The following kernels are safe to remove:~n'),
        maplist(print_kernel, Removable)
    ),

    format('~n(End of Lesson 1 demo)~n').

print_kernel(K) :-
    format('  ~w~n', [K]).

% ============================================================
% demo_lesson2 - Convenience helper for Lesson 2 testing
% ============================================================
demo_lesson2 :-
    format('~n=== Lesson 2 Demo: Temporary File Cleanup ===~n~n'),

    collect_temp_files(AllFiles),
    files_to_delete(AllFiles, ToDelete),
    reclaimed_space(ToDelete, Bytes),

    length(ToDelete, Count),
    MiB is Bytes / 1048576,

    format('Total temp files found:     ~w~n', [length(AllFiles)]),
    format('Files marked for deletion:  ~w~n', [Count]),
    format('Space that would be freed:  ~w bytes (~2f MiB)~n~n',
           [Bytes, MiB]),

    (   ToDelete = []
    ->  format('No files meet the current deletion policy.~n')
    ;   format('Files to be deleted:~n'),
        maplist(print_temp_file, ToDelete)
    ),

    format('~n(End of Lesson 2 demo)~n').

print_temp_file(temp_file(Path, Size, Age)) :-
    Hours is Age / 3600,
    format('  DELETE  ~w~n', [Path]),
    format('          Size: ~w bytes   Age: ~2f hours~n~n', [Size, Hours]).


% ============================================================
% demo_lesson3 - Convenience helper for Lesson 2 testing
% ============================================================
safe_get_running_kernel(K) :-
    catch(get_running_kernel(K), Error,
    (format("Caught error: ~w~n", [Error]), fail)).

demo_lesson3 :-
    format('~n=== Testing external process calls ===~n~n'),
    (   safe_get_running_kernel(K)
    ->  format('Running kernel: ~w~n', [K])
    ;   writeln('Failed to get kernel')
    ).

% ============================================================
% demo_lesson4 - SSH Bridge
% ============================================================
demo_lesson4 :-
    format('~n=== Lesson 4 Demo: SSH + JSON Bridge ===~n~n'),
    format('Syncing remote kernels from user@host...~n'),
    collect_remote_kernels('remote_host', 'remote_user', kernels(Running, Installed)).

