:- module(report_generator, [
    generate_maintenance_report/4,   % +SafeKernels, +Findings, +AptPackages, +Mode
    write_and_display/2
]).

:- use_module(library(readutil)).   % for read_line_to_string if you want prompts here too

:- use_module('src/context').  % for deleteable_temp_files/1
:- use_module('src/security_scanner').  % for explain_finding/1
:- use_module('src/ssh_bridge').  % for running_kernel/1, installed_kernel/1, temp_file/3

generate_maintenance_report(SafeKernels, Findings, AptPackages, Stream) :-
    get_time(Stamp),
    target_host(Host),
    run_mode(RunMode),
    deleteable_temp_files(FilesToDelete),
    format_time(atom(Timestamp), '%Y-%m-%d %H:%M:%S', Stamp),
    format(Stream, '~n========================================~n', []),
    format(Stream, 'Debian System Maintenance & Security Report~n', []),
    format(Stream, 'Host: ~w~n', [Host]),
    format(Stream, 'Generated: ~w   Mode: ~w~n', [Timestamp, RunMode]),
    format(Stream, '========================================~n~n', []),

    format(Stream, 'Running Kernel: ', []),
    (   running_kernel(RunningKernel) ->
        format(Stream, '  - ~w~n', [RunningKernel])
    ;   format(Stream, '  - Unknown (no running_kernel/1 fact)~n', [])
    ),
    report_kernels_section(Stream, SafeKernels, RunMode),
    nl(Stream),
    report_temp_section(Stream, FilesToDelete, RunMode),
    nl(Stream),
    report_security_section(Stream, Findings),
    nl(Stream),
    %report_log_section([], Mode),  % TODO: replace [] with actual log entries when available
    format(Stream, 'Log file analysis is currently disabled due to limitations in log rotation detection.~n', []),
    nl(Stream),
    report_apt_section(Stream, AptPackages, RunMode),  
    nl(Stream),
    nl(Stream),
    format(Stream, '========================================~n', []),
    format(Stream, '~n--- End of Report ---~n~n', []).

write_and_display(GeneratorGoal, Filename) :-
    open(Filename, write, FileStream),
    call(GeneratorGoal, FileStream),
    close(FileStream),
    call(GeneratorGoal, current_output),
    format('~n[INFO] Report written to ~w~n', [Filename]).
% -----------------------------------------------------------
% APT section
% -----------------------------------------------------------
report_apt_section(Stream, [], _) :-
    format(Stream, '[APT] No packages meet the auto-remove criteria.~n', []).
report_apt_section(Stream, ToRemove, dry_run) :-
    length(ToRemove, N),
    format(Stream, '[APT] DRY RUN — would auto-remove ~d package(s):~n', [N]),
    forall(member(P, ToRemove), format(Stream, '  - ~w~n', [P])).
report_apt_section(Stream, ToRemove, execute) :-
    length(ToRemove, N),
    format(Stream, '[APT] ACTION — auto-removing ~d package(s):~n', [N]),
    forall(member(P, ToRemove), format(Stream, '  - ~w~n', [P])).

% -----------------------------------------------------------
% Kernels section
% -----------------------------------------------------------
report_kernels_section(Stream, [], _) :-
    format(Stream, '[Kernels] No old kernels are safe to remove.~n', []).
report_kernels_section(Stream, Ks, dry_run) :-
    length(Ks, N),
    format(Stream, '[Kernels] DRY RUN — would remove ~d kernel(s):~n', [N]),
    forall(member(K, Ks), format(Stream, '  - ~w~n', [K])).
report_kernels_section(Stream, Ks, execute) :-
    length(Ks, N),
    format(Stream, '[Kernels] ACTION — removing ~d kernel(s):~n', [N]),
    forall(member(K, Ks), format(Stream, '  - ~w~n', [K])).

% -----------------------------------------------------------
% Security section
% -----------------------------------------------------------
report_security_section(Stream, []) :-
    format(Stream, '[Security] No security issues found.~n', []).
report_security_section(Stream, Findings) :-
    length(Findings, N),
    format(Stream, '[Security] Found ~d security issue(s):~n', [N]),
    forall(member(F, Findings), explain_finding(Stream,F)).

% -----------------------------------------------------------
% Temp files section
% -----------------------------------------------------------
report_temp_section(Stream, [], _) :-
    format(Stream, '[Temp Files] No temp files meet the deletion criteria.~n', []).
report_temp_section(Stream, ToDeleteTempFiles, dry_run) :-
    length(ToDeleteTempFiles, N),
    format(Stream, '[Temp Files] DRY RUN — would delete ~d temp file(s):~n', [N]),
    forall(member(F, ToDeleteTempFiles), format(Stream, '  - ~w~n', [F])).
report_temp_section(Stream, ToDeleteTempFiles, execute) :-
    length(ToDeleteTempFiles, N),
    format(Stream, '[Temp Files] ACTION — deleting ~d temp file(s):~n', [N]),
    forall(member(F, ToDeleteTempFiles), format(Stream, '  - ~w~n', [F])).

% -----------------------------------------------------------
% Log files section
% -----------------------------------------------------------
% See notes in log_manager.pl about why this is not currently implemented.
report_log_section(Stream, [], _) :-
    format(Stream, '[Log Files] No log files meet the deletion criteria.~n', []).
report_log_section(Stream, ToDelete, dry_run) :-
    length(ToDelete, N),
    format(Stream,  '[Log Files] DRY RUN — would delete ~d log file(s):~n', [N]),
    forall(member(F, ToDelete), format(Stream, '  - ~w~n', [F])).
report_log_section(Stream, ToDelete, execute) :-
    length(ToDelete, N),
    format(Stream, '[Log Files] ACTION — deleting ~d log file(s):~n', [N]),
    forall(member(F, ToDelete), format(Stream, '  - ~w~n', [F])).
