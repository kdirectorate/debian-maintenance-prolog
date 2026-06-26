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
    sync_remote_kernels/3,
    actually_remove_kernels/1,
    actually_remove_temp_files/1,
    actually_remove_log_files/1,
    actually_remove_apt_packages/0
    ]).

:- use_module(library(process)).
:- use_module(library(http/json)).
:- use_module(library(lists)).

:- use_module(process_utils).

% Dynamic predicates to hold the running and installed kernels on the remote system
% They start empty; we will retractall + assertz every time we sync.
:- dynamic running_kernel/1.
:- dynamic installed_kernel/1.

actually_remove_apt_packages() :-
    true. % TODO: implement the actual removal logic
    
actually_remove_log_files(_LogFiles) :-
    true. % TODO: implement the actual removal logic    

actually_remove_temp_files(_TempFiles) :-
    true. % TODO: implement the actual removal logic

actually_remove_kernels(_Kernels) :-
    true. % TODO: implement the actual removal logic
    
%% sync_remote_kernels(+Host, +User) is det.
% High-level convenience predicate.
% After it succeeds, your removable_kernel/1 rule (Lesson 1) will
% reason over the real kernels on the remote machine.
sync_remote_kernels(Host, Port, User) :-
    collect_remote_kernels(Host, Port, User, kernels(Running, Installed)),
    retractall(running_kernel(_)),
    retractall(installed_kernel(_)),
    assertz(running_kernel(Running)),
    maplist(assertz_installed, Installed),
    length(Installed, Count),
    format('~n[INFO] Running kernel from remote: ~w~n', [Running]),
    format('[INFO] Loaded ~w other installed kernels.~n~n', [Count]).

assertz_installed(K) :- assertz(installed_kernel(K)).

%% collect_remote_kernels(+Host, +Port, +User, -Kernels) is det.
% Calls the Python helper and returns kernels(Running, Installed) on success
% or fails with a meaningful message on error.
collect_remote_kernels(Host, Port, User, kernels(Running, Installed)) :-
    py_remote_executor(Host, Port, User, "collect_kernels", Response),
    ( Response.status = "success" ->
        Running = Response.data.running_kernel,
        Installed = Response.data.installed_kernels
    ; format("[ERR] Failed to collect kernels from remote: ~w~n", [Response.message]),
      fail
    ).

%% sync_remote_temp_files(+Host, +User, -TempFiles) is det.
% Calls the Python helper and returns a list of temp_file(Path, SizeBytes, AgeDays) on success
% or fails with a meaningful message on error.
sync_remote_temp_files(Host, Port, User) :-
    collect_remote_temp_files(Host, Port, User, TempFiles),
    retractall(temp_file(_, _, _)),
    maplist(assertz_temp_file, TempFiles),
    length(TempFiles, Count),
    format('~n[INFO] Loaded ~w temp files from remote.~n~n', [Count]).

assertz_temp_file(temp_file(Path, SizeBytes, AgeDays)) :-
    assertz(temp_file(Path, SizeBytes, AgeDays)).

collect_remote_temp_files(Host, Port, User, TempFiles) :-
    py_remote_executor(Host, Port, User, "collect_temp_files", Response),
    ( Response.status = "success" ->
        TempFiles = Response.data.temp_files
    ; format("[ERR] Failed to collect temp files from remote: ~w~n", [Response.message]),
      fail
    ).

%% py_remote_executor(+Host, +Port, +User, +Action, -Response) is det.
% Calls the Python helper with the given action and returns a Prolog dict
% representing the JSON response. Fails with a message if the Python helper fails.
py_remote_executor(Host, Port, User, Action, Response) :-
    process_utils:call_python(
        ['python/remote_executor.py', '--host', Host, '--port', Port, '--user', User, '--action', Action],
        Output,
        Status
    ),
    (   parse_remote_response(Output, Response)
    ->  (   Status = exit(0)
        ->  check_remote_success(Response)
        ;   format('[ERR] 1 Python helper failed with status: ~w~n', [Status]),
            catch(format('~w~n', [Response.message]), _, true),
            fail
        )
    ;   format('[ERR] Failed to parse response~n', []),
        (   Status = exit(0) -> true
        ;   format('[ERR] 2 Python helper failed with status: ~w~n', [Status]),
            catch(format('~w~n', [Output]), _, true)
        ),
        fail
    ).

%% parse_remote_response(+Output, -Response) is det.
% Parses the JSON output from the Python helper into a Prolog dict.
parse_remote_response(Output, Response) :-
    catch(
        atom_json_dict(Output, Response, []),
        E,
        ( format('[ERR] Failed to parse JSON from Python helper: ~w~n ~w~n', [E, Output]),
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

