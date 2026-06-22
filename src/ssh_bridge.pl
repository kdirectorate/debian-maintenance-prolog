% src/ssh_bridge.pl
% Lesson 4 – SSH + JSON bridge
%
% Teaching goals demonstrated:
%   - Using process_create/3 to invoke an external Python helper safely
%   - Capturing stdout and parsing it with library(http/json)
%   - Turning external structured data into Prolog facts via assertz/1
%   - Dynamic predicates so our policy rules from Lesson 1 work on live data
%   - Clean error propagation (Python error JSON → Prolog failure + message)

:- module(ssh_bridge, [
    collect_remote_kernels/3,
    sync_remote_kernels/2
    ]).

:- use_module(library(process)).
:- use_module(library(http/json)).
:- use_module(library(lists)).

:- use_module(process_utils).

% Dynamic predicates to hold the running and installed kernels on the remote system
% They start empty; we will retractall + assertz every time we sync.
:- dynamic running_kernel/1.
:- dynamic installed_kernel/1.

%% sync_remote_kernels(+Host, +User) is det.
% High-level convenience predicate.
% After it succeeds, your removable_kernel/1 rule (Lesson 1) will
% reason over the real kernels on the remote machine.
sync_remote_kernels(Host, User) :-
    collect_remote_kernels(Host, User, kernels(Running, Installed)),
    retractall(running_kernel(_)),
    retractall(installed_kernel(_)),
    assertz(running_kernel(Running)),
    maplist(assertz_installed, Installed),
    length(Installed, Count),
    format('~n[INFO] Running kernel from remote: ~w~n', [Running]),
    format('[INFO] Loaded ~w other installed kernels.~n~n', [Count]).

assertz_installed(K) :- assertz(installed_kernel(K)).

%% collect_remote_kernels(+Host, +User, -Kernels) is det.
% Calls the Python helper and returns kernels(Running, Installed) on success
% or fails with a meaningful message on error.
collect_remote_kernels(Host, User, kernels(Running, Installed)) :-
    py_remote_executor(Host, User, "collect_kernels", Response),
    ( Response.status = "success" ->
        Running = Response.data.running_kernel,
        Installed = Response.data.installed_kernels
    ; format("[ERR] Failed to collect kernels from remote: ~w~n", [Response.message]),
      fail
    ).

%% py_remote_executor(+Host, +User, +Action, -Response) is det.
% Calls the Python helper with the given action and returns a Prolog dict
% representing the JSON response. Fails with a message if the Python helper fails.
py_remote_executor(Host, User, Action, Response) :-
    process_utils:call_python(
        ['python/remote_executor.py', '--host', Host, '--user', User, '--action', Action],
        Output,
        Status
    ),
    ( Status = exit(0)
    -> parse_remote_response(Output, Response),
       check_remote_success(Response)
    ; format('[ERR] Python helper failed with status: ~w~n', [Status]),
      fail
    ).

%% parse_remote_response(+Output, -Response) is det.
% Parses the JSON output from the Python helper into a Prolog dict.
parse_remote_response(Output, Response) :-
    catch(
        atom_json_dict(Output, Response, []),
        _E,
        ( format('[ERR] Failed to parse JSON from Python helper: ~w~n', [Output]),
          fail
        )
    ).

%% check_remote_success(+Response) is det.
% Checks if the Python helper reported success. If not, fails with an error message.
check_remote_success(Response) :-
    ( Response.status = "success"
    -> true
    ; format('[ERR] Python helper reported error: ~w~n', [Response.message]),
      fail
    ).

