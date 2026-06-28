:- module(report_generator, [
    generate_maintenance_report/6,   % +Host, +SafeKernels, +TempToDelete, +SecurityFindings, +Mode
    write_report_to_file/2,
    report_kernels_section/2,        % +SafeKernels, +Mode
    report_temp_section/2,           % +TempToDelete, +Mode
    report_security_section/1,       % +SecurityFindings
    report_log_section/2,             % +LogEntries, +Mode
    report_apt_section/2              % +AptEntries, +Mode
]).

:- use_module(library(readutil)).   % for read_line_to_string if you want prompts here too
:- use_module('src/security_scanner').  % for explain_finding/1
:- use_module('src/ssh_bridge').  % for running_kernel/1, installed_kernel/1, temp_file/3

generate_maintenance_report(Host, SafeKernels, TempFiles, Findings, AptPackages, Mode) :-
    get_time(Stamp),
    format_time(atom(Timestamp), '%Y-%m-%d %H:%M:%S', Stamp),
    format('~n========================================~n'),
    format('Debian System Maintenance & Security Report~n'),
    format('Host: ~w~n', [Host]),
    format('Generated: ~w   Mode: ~w~n', [Timestamp, Mode]),
    format('========================================~n~n'),

    format('Running Kernel: '),
    (   running_kernel(RunningKernel) ->
        format('  - ~w~n', [RunningKernel])
    ;   format('  - Unknown (no running_kernel/1 fact)~n')
    ),
    report_kernels_section(SafeKernels, Mode),
    writeln(''),
    report_temp_section(TempFiles, Mode),
    writeln(''),
    report_security_section(Findings),
    writeln(''),
    %report_log_section([], Mode),  % TODO: replace [] with actual log entries when available
    writeln('Log file analysis is currently disabled due to limitations in log rotation detection.'),
    writeln(''),
    report_apt_section(AptPackages, Mode),  
    writeln(''),
    writeln(''),
    format('========================================~n'),
    format('~n--- End of Report ---~n~n').

report_apt_section([], _) :-
    format('[APT] No packages meet the auto-remove criteria.~n').
report_apt_section(ToRemove, dry_run) :-
    length(ToRemove, N),
    format('[APT] DRY RUN — would auto-remove ~d package(s):~n', [N]),
    forall(member(P, ToRemove), format('  - ~w~n', [P])).
report_apt_section(ToRemove, execute) :-
    length(ToRemove, N),
    format('[APT] ACTION — auto-removing ~d package(s):~n', [N]),
    forall(member(P, ToRemove), format('  - ~w~n', [P])).

report_kernels_section([], _) :-
    format('[Kernels] No old kernels are safe to remove.~n').
report_kernels_section(Ks, dry_run) :-
    length(Ks, N),
    format('[Kernels] DRY RUN — would remove ~d kernel(s):~n', [N]),
    forall(member(K, Ks), format('  - ~w~n', [K])).
report_kernels_section(Ks, execute) :-
    length(Ks, N),
    format('[Kernels] ACTION — removing ~d kernel(s):~n', [N]),
    forall(member(K, Ks), format('  - ~w~n', [K])).

report_security_section([]) :-
    format('[Security] No security issues found.~n').
report_security_section(Findings) :-
    length(Findings, N),
    format('[Security] Found ~d security issue(s):~n', [N]),
    forall(member(F, Findings), explain_finding(F)).

report_temp_section([], _) :-
    format('[Temp Files] No temp files meet the deletion criteria.~n').
report_temp_section(ToDelete, dry_run) :-
    length(ToDelete, N),
    format('[Temp Files] DRY RUN — would delete ~d temp file(s):~n', [N]),
    forall(member(F, ToDelete), format('  - ~w~n', [F])).
report_temp_section(ToDelete, execute) :-
    length(ToDelete, N),
    format('[Temp Files] ACTION — deleting ~d temp file(s):~n', [N]),
    forall(member(F, ToDelete), format('  - ~w~n', [F])).

% See notes in log_manager.pl about why this is not currently implemented.
report_log_section([], _) :-
    format('[Log Files] No log files meet the deletion criteria.~n').
report_log_section(ToDelete, dry_run) :-
    length(ToDelete, N),
    format('[Log Files] DRY RUN — would delete ~d log file(s):~n', [N]),
    forall(member(F, ToDelete), format('  - ~w~n', [F])).
report_log_section(ToDelete, execute) :-
    length(ToDelete, N),
    format('[Log Files] ACTION — deleting ~d log file(s):~n', [N]),
    forall(member(F, ToDelete), format('  - ~w~n', [F])).

write_report_to_file(GeneratorGoal, Filename) :-
    open(Filename, write, Stream),
    with_output_to(Stream, call(GeneratorGoal)),
    close(Stream),
    format('Report also written to ~w~n', [Filename]).