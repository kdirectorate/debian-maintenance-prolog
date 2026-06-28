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

% test facts
:- use_module('src/facts').

:- use_module('config/default_policy').
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

parse_options([], Opts, Opts).
parse_options(['-h' | T], Acc, Opts) :-
    parse_options(T, [display_help(true) | Acc], Opts).

parse_options(['-t' | T], Acc, Opts) :-
    parse_options(T, [test_data(true) | Acc], Opts).

parse_options(['-dry-run' | T], Acc, Opts) :-
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
        format('  -dry-run           : Show what would be done without making changes~n'),
        format('  --host <hostname>  : Specify the target host (default: debian12-maint-test)~n'),
        format('  --port <port>      : Specify the SSH port (default: 22)~n'),
        format('  --user <username>  : Specify the SSH user (default: shinhwa)~n'),
        format('  -t                 : Create test data on remote server. DO NOT USE IN PROD'),
        format('  -h                 : Display this help message~n'),
        halt(0)
    ;   true
    ),

    ( member(target_host(Host), Options) ; default_target_host(Host) ),
    ( member(target_port(Port), Options) ; default_target_port(Port) ),
    ( member(target_user(User), Options) ; default_target_user(User) ),

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
    findall(K, removable_kernel(Running, Installed, K), SafeKernels),
    findall(P,
        (   temp_file(P, S, A),
            file_should_be_deleted( temp_file(P, S, A))
        ),
        TempFiles
    ),
    /* findall(log_file(Path, SizeBytes),
        (   log_file(Path, SizeBytes),
            log_should_be_truncated(log_file(Path, SizeBytes))
        ),
        LogFiles
    ),*/
    findall(P, autoremove_candidate(P), AutoremoveCandidates),
    collect_findings(Findings),
    generate_maintenance_report('localhost', SafeKernels, TempFiles, Findings, AutoremoveCandidates, dry_run).

    % Process command-line arguments (later)