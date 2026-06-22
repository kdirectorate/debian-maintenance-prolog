:- module(process_utils, [
    get_running_kernel/1,
    run_command_capture/4,
    call_python/3
]).

:- use_module(library(process)).

%% ============================================================
%% get_running_kernel(-Kernel)
%% ============================================================
%% Runs `uname -r` on the local machine and unifies Kernel with
%% the trimmed kernel version string (e.g. '6.1.0-17-amd64').
%%
%% This predicate demonstrates the classic pattern:
%%   1. process_create/3 spawns the command with a stdout pipe
%%   2. We read the pipe as a normal Prolog stream
%%   3. We wait for the process and check its exit status
%%   4. We clean the output with normalize_space/2
%%
%% Teaching note: Prolog treats the pipe handle exactly like
%% an open file stream. This is why read_string/3 works directly.
get_running_kernel(Kernel) :-
    run_command_capture('uname', ['-r'], Output, Status),
    handle_process_status(Status, Output, Kernel).

%% Helper to keep the main predicate clean
handle_process_status(exit(0), Output, Kernel) :-
    normalize_space(atom(Kernel), Output).
handle_process_status(exit(Code), _Output, _Kernel) :-
    format("Command failed with exit code ~w~n", [Code]),
    fail.
handle_process_status(signal(Sig), _Output, _Kernel) :-
    format("Command killed by signal ~w~n", [Sig]),
    fail.

%% ============================================================
%% run_command_capture(+Command, +Args, -Output, -Status)
%% ============================================================
%% Generic helper you can reuse. Returns the raw stdout as a string.
%% Later we will extend this for stderr and better error handling.
run_command_capture(Command, Args, Output, Status) :-
    process_create(path(Command), Args,
                   [ stdout(pipe(Out)),
                     process(Pid)
                   ]),
    read_string(Out, _, Output),
    close(Out),
    process_wait(Pid, Status).

%% call_python_hello
%% Demonstrates that calling Python (or any program) from Prolog
%% uses exactly the same process_create/3 pattern.
call_python(Args, Output, Status) :-
    run_command_capture('python3', Args, Output, Status).


