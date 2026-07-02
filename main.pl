% ============================================================
% main.pl - Lesson 1 entry point
% ============================================================
%
% TEACHING NOTE:
% For Lesson 1 we use the simple consult/1 mechanism.
% In Lesson 5 we will convert everything to proper modules
% with use_module/1 for better encapsulation.

% library(prolog_stack) installs the hook that attaches the call stack to
% exceptions so catch_with_backtrace/3 has frames to show.
:- use_module(library(prolog_stack)).

:- use_module(library(main)).

:- use_module('config/default_policy').
:- use_module('src/context').

:- use_module('src/ssh_bridge').
:- use_module('src/kernel_cleaner').
:- use_module('src/temp_cleanup').
:- use_module('src/log_manager').
:- use_module('src/apt_maintainer').
:- use_module('src/security_scanner').
:- use_module('src/report_generator').


/* Teaching note (debugging helper):
   debug_run(:Goal) runs Goal and, if it throws, prints a full user-level
   backtrace straight to the command line — no interactive toplevel needed.

   Usage:
       swipl -s main.pl -g "debug_run(lesson_7_test)" -g "halt"

   Note on stack frames: last-call optimisation (LCO) discards intermediate
   frames at COMPILE time, so to keep every frame you must disable the flag
   BEFORE the code is loaded, e.g.:
       swipl -g "set_prolog_flag(last_call_optimisation, false)" \
             -g "consult('main.pl')" \
             -g "debug_run(lesson_7_test)" -g "halt"
   Setting the flag at runtime has no effect on already-compiled predicates.
*/
debug_run(Goal) :-
    catch_with_backtrace(Goal,
                         Error,
                         ( print_message(error, Error), fail )).

% Optional banner so you know the files loaded cleanly
show_banner :-
    format('~n=== Debian System Maintenance Tool ===~n').

/* Teaching note:
   main.pl should stay small. Its job is:
   1. Parse CLI (later)
   2. Call the SSH bridge to collect data
   3. Ask each specialist module for decisions
   4. Produce the report (Lesson 7)
*/

make_changes:-
    confirm_action('maintenance actions'),
    target_host(Host),
    target_port(Port),
    target_user(User),

    % Remove apt packages that are marked for autoremove
    findall(P, autoremove_candidate(P), Packages),
    ( Packages == [] ->
        format('~n[INFO] No apt packages to remove.~n')
    ; actually_remove_apt_packages(Host, Port, User, Packages),
      format('~n[INFO] All marked apt packages removed.~n')
    ),

    % Purge old kernels
    findall(K, removable_kernel(K), Kernels),
    ( Kernels == [] ->
        format('~n[INFO] No kernels to purge.~n')
    ; actually_remove_kernels(Host, Port, User, Kernels),
      format('~n[INFO] All marked kernels purged.~n')
    ),

    % Remove temp files that are marked for deletion
    deleteable_temp_files(FilesToDelete),
    ( FilesToDelete == [] ->
        format('~n[INFO] No temp files to delete.~n')
    ; forall(
            member(F, FilesToDelete), 
            actually_remove_temp_file(Host, Port, User, F)
        ),
        format('~n[INFO] All marked temp files deleted.~n')
    ).

confirm_action(Description) :-
    format('~n>>> About to perform: ~w~n', [Description]),
    format('    Proceed? [y/N]: '),
    flush_output(user_output),
    read_line_to_string(user_input, Line),
    string_lower(Line, Lower),
    (   Lower == "y"
    ->  true
    ;   format('Action aborted by user.~n'), fail
    ).

removable_kernel(K) :-
    installed_kernel(K),
    running_kernel(Running),
    K \= Running.

parse_options([], Opts, Opts).
parse_options(['-h' | T], Acc, Opts) :-
    parse_options(T, [display_help(true) | Acc], Opts).

parse_options(['-t' | T], Acc, Opts) :-
    parse_options(T, [test_data(true) | Acc], Opts).

parse_options(['--dry-run' | T], Acc, Opts) :-
    parse_options(T, [dry_run(true) | Acc], Opts).
parse_options(['--host', Host | T], Acc, Opts) :-
    parse_options(T, [target_host(Host) | Acc], Opts).
parse_options(['--port', Port | T], Acc, Opts) :-
    parse_options(T, [target_port(Port) | Acc], Opts).
parse_options(['--user', User | T], Acc, Opts) :-
    parse_options(T, [target_user(User) | Acc], Opts).
parse_options([Unknown | T], Acc, Opts) :-
    format('Warning: unknown argument ~w~n', [Unknown]),
    parse_options(T, Acc, Opts).

main(Argv) :-
    show_banner,
    parse_options(Argv, [], OptionsRev),
    reverse(OptionsRev, Options),

    (   member(display_help(true), Options),
        format('Usage: swipl -s main.pl [options]~n'),
        format('Options:~n'),
        format('  --dry-run           : Show what would be done without making changes~n'),
        format('  --host <hostname>  : Specify the target host (default: debian12-maint-test)~n'),
        format('  --port <port>      : Specify the SSH port (default: 22)~n'),
        format('  --user <username>  : Specify the SSH user (default: shinhwa)~n'),
        format('  -t                 : Create test data on remote server. DO NOT USE IN PROD~n'),
        format('  -h                 : Display this help message~n'),
        halt(0)
    ;   true
    ),

    ( member(target_host(Host), Options) ; default_target_host(Host) ),
    ( member(target_port(Port), Options) ; default_target_port(Port) ),
    ( member(target_user(User), Options) ; default_target_user(User) ),
    assertz(target_host(Host)),
    assertz(target_port(Port)),
    assertz(target_user(User)),

    (member(dry_run(true), Options)
    ->  assertz(run_mode(dry_run))
    ;   assertz(run_mode(execute))
    ),

    ( member(test_data(true), Options),
        writeln("+---------------------------------+"),
        writeln("| CREATING TEST DATA...           |"),
        writeln("+---------------------------------+"),
        test_create_data(Host, Port, User)
     ; true   
    ),
    
    !, % no going back after this point, we have the options we need

    % Sync facts from the remote system via SSH and JSON
    sync_facts_from_remote(Host, Port, User),
    
    % Gather system state from synced facts and generate the report
    running_kernel(Running),
    findall(K, installed_kernel(K), Installed),
    findall(K, removable_kernel(K), SafeKernels),
    findall(P, autoremove_candidate(P), AutoremoveCandidates),
    findall(temp_file(P, S, A),
        (temp_file(P, S, A),
            file_should_be_deleted(P, S, A)), 
        TempFilesToDelete),
    assertz(deleteable_temp_files(TempFilesToDelete)),

    % security_scanner
    collect_findings(Findings),

    % Generate the report and write it to a file and the terminal
    write_and_display(
        generate_maintenance_report(SafeKernels, Findings, AutoremoveCandidates),
        'maintenance_report.txt'
    ),


    (   run_mode(execute) ->
        make_changes
    ;   format('~n[INFO] Dry run complete. No changes made.~n')
    ),
    halt(0).
    
