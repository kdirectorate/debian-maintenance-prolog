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
    sync_facts_from_remote/3,
    actually_remove_kernels/4,
    actually_remove_apt_packages/4,
    actually_remove_temp_file/4,
    actually_remove_log_files/1,
    test_create_data/3
    ]).

:- use_module(library(process)).
:- use_module(library(http/json)).
:- use_module(library(lists)).

:- use_module(process_utils).
:- use_module('src/context').

% Remote system facts live in src/context.pl — imported via use_module above.
% ssh_bridge asserts into them; other modules query them from context directly.

% We're using a list here because the setup time for SSH connections is significant, 
% and we want to avoid repeated connections for each file.
actually_remove_apt_packages(Host, Port, User, Packages) :-
    py_remote_executor(Host, Port, User, "remove_packages", _{packages: Packages}, Response),
    ( Response.status = "success" ->
        format("[INFO] Successfully removed apt packages.~n")
    ; format("[ERR] Failed to remove apt packages: ~w~n", [Response.message]),
      fail
    ).

actually_remove_log_files(_LogFiles) :-
    true. % TODO: implement the actual removal logic

actually_remove_temp_file(Host, Port, User, temp_file(Path, _, _)) :-
    py_remote_executor(Host, Port, User, 
        "remove_file", _{path: Path}, 
        _
    ).

actually_remove_kernels(Host, Port, User, Kernels) :-
    py_remote_executor(Host, Port, User, "purge_kernels", _{kernels: Kernels}, Response),
    ( Response.status = "success" ->
        format("[INFO] Successfully purged kernels.~n")
    ; format("[ERR] Failed to purge kernels: ~w~n", [Response.message]),
      fail
    ).


% -----------------------------------------------------------
% SYNC predicates to collect facts from the remote system via SSH and JSON
% -----------------------------------------------------------

sync_facts_from_remote(Host, Port, User) :-
    sync_remote_kernels(Host, Port, User), 
    sync_remote_temp_files(Host, Port, User),
    sync_apt_autoremove(Host, Port, User),
    sync_remote_processes(Host, Port, User),
    sync_remote_sockets(Host, Port, User),
    sync_modified_files(Host, Port, User).

sync_remote_sockets(Host, Port, User) :-
    collect_remote_sockets(Host, Port, User, JsonList),
    /*
    'netid': parts[0],
    'state': parts[1],
    'recv_q': int(parts[2]),
    'send_q': int(parts[3]),
    'local_address': la,
    'local_port': lp,
    'peer_address': pa,
    'peer_port': pp,
    'process': proc,
    'pid': pid,
    'name': name
    */
    retractall(open_port(_, _, _, _, _, _, _, _, _, _, _)),
    maplist(json_to_open_port, JsonList, OpenPorts),
    maplist(assertz_open_port, OpenPorts),
    length(OpenPorts, Count),
    format("[INFO] Loaded ~w open ports from remote.~n~n", [Count]).

collect_remote_sockets(Host, Port, User, Sockets) :-
    py_remote_executor(Host, Port, User, "get_remote_sockets", Response),
    ( Response.status = "success" ->
        Sockets = Response.data.sockets
    ; format("[ERR] Failed to collect sockets from remote: ~w~n", [Response.message]),
      fail
    ).

json_to_open_port(Dict, [Netid, State, RecvQ, SendQ, LocalAddress, 
    LocalPort, PeerAddress, PeerPort, Process, PID, Name]) :-
    
    Netid = Dict.netid,
    State = Dict.state,
    RecvQ = Dict.recv_q,
    SendQ = Dict.send_q,
    LocalAddress = Dict.local_address,
    LocalPort = Dict.local_port,
    PeerAddress = Dict.peer_address,
    PeerPort = Dict.peer_port,
    Process = Dict.process,
    PID = Dict.pid,
    Name = Dict.name.

assertz_open_port([Netid, State, RecvQ, SendQ, LocalAddress, LocalPort, PeerAddress, 
        PeerPort, Process, PID, Name]) :-

    assertz(open_port(
        Netid, State, RecvQ, SendQ, LocalAddress, LocalPort, PeerAddress, 
        PeerPort, Process, PID, Name)).

sync_remote_processes(Host, Port, User) :-

    collect_remote_processes(Host, Port, User, JsonList),
    retractall(process(_,_, _, _, _, _, _, _, _, _, _, _, _)),
    maplist(json_to_process, JsonList, ProcessTerms),
    maplist(assertz_process, ProcessTerms),
    length(ProcessTerms, Count),
    
    format("[INFO] Loaded ~w processes from remote.~n~n", [Count]).

collect_remote_processes(Host, Port, User, Processes) :-
    py_remote_executor(Host, Port, User, "get_remote_processes", Response),
    ( Response.status = "success" ->
        Processes = Response.data.processes
    ; format("[ERR] Failed to collect processes from remote: ~w~n", [Response.message]),
      fail
    ).

json_to_process(Dict, [PID, PPID, UID, User, PCPU, PMEM, VSZ, RSS, TTY, Stat, StartTime, Time, Cmd]) :-
    PID = Dict.pid,
    PPID = Dict.ppid,
    UID = Dict.uid,
    User = Dict.user,
    PCPU = Dict.pcpu,
    PMEM = Dict.pmem,
    VSZ = Dict.vsz,
    RSS = Dict.rss,
    TTY = Dict.tty,
    Stat = Dict.stat,
    StartTime = Dict.start_time,
    Time = Dict.time,
    Cmd = Dict.cmd.

assertz_process([PID, PPID, UID, User, PCPU, PMEM, VSZ, RSS, TTY, Stat, StartTime, Time, Cmd]) :-
    assertz(process(PID, PPID, UID, User, PCPU, PMEM, VSZ, RSS, TTY, Stat, StartTime, Time, Cmd)).


sync_modified_files(Host, Port, User) :-
    collect_modified_files(Host, Port, User, JsonList),
    retractall(modified_file(_, _)),
    maplist(json_to_modified_file, JsonList, ModifiedFiles),
    maplist(assertz_modified_file, ModifiedFiles),
    length(ModifiedFiles, Count),
    format("[INFO] Loaded ~w modified files from remote.~n~n", [Count]).

collect_modified_files(Host, Port, User, ModifiedFiles) :-
    py_remote_executor(Host, Port, User, "collect_modified_files", Response),
    ( Response.status = "success" ->
        ModifiedFiles = Response.data.modified_files
    ; format("[ERR] Failed to collect modified files from remote: ~w~n", [Response.message]),
      fail
    ).

%% json_to_modified_file(+List, -Term) is det.
% Converts a JSON 3-element list [Path, SizeMB, Timestamp] into a Prolog term
% modified_file(Path, Timestamp).
json_to_modified_file([Path, _SizeMB, Timestamp], modified_file(PathAtom, Timestamp)) :-
    atom_string(PathAtom, Path).

assertz_modified_file(modified_file(Path, Timestamp)) :-
    assertz(modified_file(Path, Timestamp)).

    %% sync_apt_autoremove(+Host, +Port, +User) is det.
% Add facts about packages that apt wants to remove to the Prolog database.
sync_apt_autoremove(Host, Port, User) :-
    collect_apt_autoremove(Host, Port, User, AutoremoveCandidates),
    retractall(autoremove_candidate(_)),
    maplist(json_to_autoremove_candidate, AutoremoveCandidates, PrologCandidates),
    maplist(assertz_autoremove_candidate, PrologCandidates),
    length(PrologCandidates, Count),
    format("[INFO] Loaded ~w apt autoremove candidates from remote.~n~n", [Count]).

%% collect_apt_autoremove(+Host, +Port, +User, -AutoremoveCandidates) is det.
% Calls the Python helper and returns apt autoremove information on success
collect_apt_autoremove(Host, Port, User, AutoremoveCandidates) :-
    py_remote_executor(Host, Port, User, "collect_apt_autoremove", Response),
    ( Response.status = "success" ->
        AutoremoveCandidates = Response.data.autoremove_candidates
    ; format("[ERR] Failed to collect apt autoremove information from remote: ~w~n", [Response.message]),
      fail
    ).

json_to_autoremove_candidate(PackageName, PackageAtom) :-
    atom_string(PackageAtom, PackageName).

assertz_autoremove_candidate(Package) :- assertz(autoremove_candidate(Package)).

%% sync_remote_kernels(+Host, +User) is det.
% High-level convenience predicate.
% After it succeeds, your removable_kernel/1 rule (Lesson 1) will
% reason over the real kernels on the remote machine.
sync_remote_kernels(Host, Port, User) :-
    collect_remote_kernels(Host, Port, User, kernels(Running, Installed)),
    retractall(running_kernel(_)),
    retractall(installed_kernel(_)),
    json_to_installed_kernel(Running, RunningTerm),
    assertz(running_kernel(RunningTerm)),
    format('~n[INFO] Loaded running kernel from remote: ~w~n', [Running]),
    json_to_installed_kernel_list(Installed, InstalledTerms),
    maplist(assertz_installed, InstalledTerms),
    length(Installed, Count),
    format('~n[INFO] Running kernel from remote: ~w~n', [Running]),
    format('[INFO] Loaded ~w other installed kernels.~n~n', [Count]).

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

json_to_installed_kernel_list([], []).
json_to_installed_kernel_list([KernelString | Rest], [KernelAtom | RestTerms]) :-
    atom_string(KernelAtom, KernelString),
    json_to_installed_kernel_list(Rest, RestTerms).

json_to_installed_kernel(KernelString, KernelAtom) :-
    atom_string(KernelAtom, KernelString).

assertz_installed(K) :- assertz(installed_kernel(K)).

%% sync_remote_temp_files(+Host, +User, -TempFiles) is det.
% Calls the Python helper and returns a list of temp_file(Path, SizeBytes, AgeDays) on success
% or fails with a meaningful message on error.
sync_remote_temp_files(Host, Port, User) :-
    collect_remote_temp_files(Host, Port, User, JsonList),
    retractall(temp_file(_, _, _)),
    maplist(json_to_temp_file, JsonList, TempFiles),
    maplist(assertz_temp_file, TempFiles),
    length(TempFiles, Count),
    format('~n[INFO] Loaded ~w temp files from remote.~n~n', [Count]).

collect_remote_temp_files(Host, Port, User, TempFiles) :-
    py_remote_executor(Host, Port, User, "collect_temp_files", Response),
    ( Response.status = "success" ->
        TempFiles = Response.data.temp_files
    ; format("[ERR] Failed to collect temp files from remote: ~w~n", [Response.message]),
      fail
    ).


assertz_temp_file(temp_file(Path, SizeMB , AgeDays)) :-
    assertz(temp_file(Path, SizeMB, AgeDays)).

%% json_to_temp_file(+Dict, -Term) is det.
% Converts a JSON list of 3 elements [Path, SizeMB, AgeDays] into a Prolog term
% temp_file(Path, SizeMB, AgeDays).
json_to_temp_file([Path, SizeMB, AgeDays], temp_file(PathAtom, SizeMB, AgeDays)) :-
    atom_string(PathAtom, Path).
    
% -----------------------------------------------------------------------
% Helper functions to setup the test environment
% DO not call in production, only test.
% -----------------------------------------------------------------------
test_create_data(Host, Port, User) :-
    test_create_temp_files(Host, Port, User),
    test_create_apt_dependencies(Host, Port, User),
    test_tamper_critical_files(Host, Port, User),
    test_start_test_processes(Host, Port, User).

test_start_test_processes(Host, Port, User) :-
    py_remote_executor(Host, Port, User, "t_start_test_processes", Response),
    (   Response.status = "success" ->
            writeln("Test processes started.")
    ;   format("[ERR] Failed to start test processes: ~w~n", [Response.message]),
        fail
    ).


test_tamper_critical_files(Host, Port, User) :-
    py_remote_executor(Host, Port, User, "t_tamper_critical_files", Response),
    (   Response.status = "success" ->
            writeln("Test critical files tampered.")
    ;   format("[ERR] Failed to tamper test critical files: ~w~n", [Response.message]),
        fail
    ).

test_create_apt_dependencies(Host, Port, User) :-
    py_remote_executor(Host, Port, User, "t_create_apt_dependencies", Response),
    (   Response.status = "success" ->
            writeln("Test apt dependencies created.")
    ;   format("[ERR] Failed to create test apt dependencies: ~w~n", [Response.message]),
        fail
    ).

test_create_temp_files(Host, Port, User) :-
    py_remote_executor(Host, Port, User, "t_create_tmp_files", Response),
    (   Response.status = "success" ->
            writeln("Test temp files created.")
    ;   format("[ERR] Failed to create test temp files: ~w~n", [Response.message]),
        fail
    ).

% -----------------------------------------------------------------------
% py_remote_executor
% Calls the Python helper with the given action and returns a Prolog dict
% representing the JSON response. Fails with a message if the Python helper fails.
% -----------------------------------------------------------------------

%% py_remote_executor(+Host, +Port, +User, +Action, +Parms, -Response) is det.
py_remote_executor(Host, Port, User, Action, Parms, Response) :-

    % Convert the Parms dict to a JSON string
    with_output_to(string(ParmsString),
        json_write_dict(current_output, Parms, [])),

    process_utils:call_python(
        ['python/remote_executor.py', 
        '--host', Host, '--port', Port, '--user', User, '--action', Action,
        '--parms', ParmsString],
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


%% py_remote_executor(+Host, +Port, +User, +Action, -Response) is det.
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

