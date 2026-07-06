/*  File:     src/security_scanner.pl
    Module:   security_scanner
    Purpose:  Declarative host-based security checks for the Debian maintenance tool.
              All policy decisions live here so they are auditable and easy to change.
*/

:- module(security_scanner, [
    explain_finding/2,
    collect_findings/1        % +Findings:list
]).

:- use_module(library(lists)).
:- use_module(library(pcre)).


:- use_module('config/default_policy').   % thresholds & whitelists live here
:- use_module('src/context').             % for modified_file/2 and other remote facts

% ============================================================
% MAIN ENTRY POINT
% ============================================================

collect_findings(Findings) :-
    collect_port_findings(PortFindings),
    collect_brute_force_findings(BruteFindings),
    collect_file_mod_findings(FileFindings),
    collect_suspicious_process_findings(ProcFindings),
    collect_uid0_findings(UID0Findings),
    collect_user_findings(UserFindings),
    append([FileFindings, ProcFindings, PortFindings, UID0Findings, UserFindings, BruteFindings], Unsorted),  % only include the checks that are implemented
    sort(Unsorted, Findings).   % remove any accidental duplicates


% Helper collectors — each uses findall so we get zero or more findings per category
collect_port_findings(Findings) :-
    findall(finding(What, Sev, Ev, Rec),
             check_unexpected_port(What, Sev, Ev, Rec),
            Findings).

collect_brute_force_findings(Findings) :-
    findall(finding(What, Sev, Ev, Rec),
            check_brute_force(What, Sev, Ev, Rec),
            Findings).

collect_file_mod_findings(Findings) :-
    findall(finding(What, Sev, Ev, Rec),
            check_recent_critical_mod(What, Sev, Ev, Rec),
            Findings).

collect_suspicious_process_findings(Findings) :-
    findall(finding(What, Sev, Ev, Rec),
            check_suspicious_process(What, Sev, Ev, Rec),
            Findings).

collect_uid0_findings(Findings) :-
    findall(finding(What, Sev, Ev, Rec),
            check_nonstandard_uid0(What, Sev, Ev, Rec),
            Findings).

collect_user_findings(Findings) :-
    findall(finding(What, Sev, Ev, Rec),
            check_nonstandard_user(What, Sev, Ev, Rec),
            Findings).

% ============================================================
% CHECK 1: Unexpected listening ports (uses negation as failure)
% ============================================================

check_unexpected_port(What, Severity, Evidence, Recommendation) :-
    % open_port(Netid, State, RecvQ, SendQ, LocalAddress, LocalPort, PeerAddress, PeerPort, Process, PID, Name)
    open_port(Netid, State, _, _, _, LocalPort, LocalAddress, _, _, _, _),

    % only consider ports that are actually listening
    State = "LISTEN",

    % normalize the data types so we can compare against the policy facts
    number_string(IntPort, LocalPort),
    
    % exclude any ports that are expected according to the policy facts
    \+ expected_listening_port(IntPort, Netid),           % ← negation as failure
    classify_port_severity(IntPort, Netid, LocalAddress, Severity),

    format(atom(What), 'Unexpected listening ~w port ~w', [Netid, IntPort]),
    Evidence = listening_port(IntPort, Netid),
    Recommendation = 'Run: ss -tuln | grep LISTEN and journalctl -u <service>. If legitimate, add it to expected_listening_port/2 in policy or default_policy.pl. Consider firewall rules.'.

% Green cut used here to make classification deterministic
classify_port_severity(Port, _Proto, _LocalAddress, high) :-
    Port > 32768,          % high-numbered ephemeral ports are common backdoor locations
    !.
classify_port_severity(_Port, _Proto, LocalAddress, low) :-
    (   LocalAddress == "127.0.0.1" ; LocalAddress == "::1" ),  % only listening on localhost
    !.
classify_port_severity(Port, tcp, _LocalAddress, medium) :-
    Port > 1024,           % non-privileged port
    !.
classify_port_severity(_Port, _Proto, _LocalAddress, low).

% ============================================================

% CHECK 2: Brute-force login attempts (aggregation + threshold)
% ============================================================

check_brute_force(What, high, Evidence, Recommendation) :-
    brute_force_from(IP, Count),
    format(atom(What), 'Brute-force login attempts from ~w (~w failures)', [IP, Count]),
    Evidence = brute_force(IP, Count),
    Recommendation = 'Immediately block the IP (fail2ban, ufw, or iptables). Review /var/log/auth.log or journalctl -u ssh. This is almost always malicious activity.'.

%% brute_force_from(-IP, -Count) 
%  Uses findall + length (classic aggregation pattern you already know from temp_cleanup)
brute_force_from(IP, Count) :-
    failed_login(_Timestamp, _Username, IP),  % find all failed logins from this IP
    findall(1, failed_login(_, _, IP), Attempts),
    length(Attempts, Count),
    brute_force_threshold(Thresh),
    Count >= Thresh.


% ============================================================
% CHECK 3: Recently modified critical system files
% ============================================================

check_recent_critical_mod(What, high, Evidence, Recommendation) :-
    critical_file(Path),
    modified_file(Path, AgeDays),
    AgeDays =< 7,                    % within last week
    format(atom(What), 'Modified file ~w modified ~w days ago', [Path, AgeDays]),
    Evidence = modified_file(Path, AgeDays),
    Recommendation = 'Verify with: debsums -c ~w or dpkg -V. Check package manager history (apt history.log). If unexpected, treat as potential compromise. Compare mtime with last legitimate update.'.

% ============================================================
% CHECK 4: Suspicious processes (root running from tmp or unusual locations)
% ============================================================

check_suspicious_process(What, high, Evidence, Recommendation) :-
    process(PID, _, _, User, _, _, _, _, _, _, _, _, Cmd),
    suspicious_exe_location(Cmd),  % check if the command is running from a suspicious location
    format(atom(What), 'Process ~w (PID ~w) running from suspicious location', [Cmd, PID]),
    Evidence = suspect_process(PID, User, Cmd),
    Recommendation = 'Investigate immediately with: ps auxfww, lsof -p <PID>, and cat /proc/<PID>/exe. Kill only after confirmation. This is a classic sign of privilege escalation or malware.'.

check_suspicious_process(What, high, Evidence, Recommendation) :-
    process(PID, _, _, User, _, _, _, _, _, _, _, _, Cmd),
    suspicious_process(Suspicious),
    atomic_list_concat(['\\b', Suspicious, '\\b'], Pattern), 
    re_match(Pattern, Cmd, []),
    format(atom(What), 'Process ~w (PID ~w) contains suspicious token ~w',
           [Cmd, PID, Suspicious]),
    Evidence = suspect_process(PID, User, Cmd),
    Recommendation = 'Investigate immediately with: ps auxfww, lsof -p <PID>, and cat /proc/<PID>/exe. Kill only after confirmation. This is a classic sign of privilege escalation or malware.'.

% TODO: add /dev/shm, /dev/mqueue, /var/run, and other tmpfs locations to suspicious_exe_location/1
% TODO: Move this to default_policy.pl and make it configurable, so users can add their own suspicious locations.
suspicious_exe_location(ExePath) :-
    ( sub_atom(ExePath, 0, _, _, '/tmp/')
    ; sub_atom(ExePath, 0, _, _, '/var/tmp/')
    ; sub_atom(ExePath, 0, _, _, '/home/')
    ; sub_atom(ExePath, 0, _, _, '/root/.cache/')
    ).

% ============================================================
% CHECK 5: Non-standard UID 0 accounts
% ============================================================

check_nonstandard_uid0(What, high, Evidence, Recommendation) :-
    user(Username, UID, _GID, HomeDir, _Shell, _Comment),
    UID =:= 0,
    \+ standard_root_user(Username),           % negation as failure again
    format(atom(What), 'Non-standard UID 0 account: ~w (home: ~w)', [Username, HomeDir]),
    Evidence = user_account(Username, 0, HomeDir),
    Recommendation = 'This is extremely serious. Review /etc/passwd and /etc/shadow. Remove the account if it was not deliberately created. Check authorized_keys and cron jobs for this user.'.

% ============================================================
% Bonus check: Non-standard user accounts (UID > 0)
% ============================================================

check_nonstandard_user(What, medium, Evidence, Recommendation) :-
    user(Username, UID, _GID, HomeDir, _Shell, _Comment),
    UID > 0,
    \+ standard_user(Username),           % negation as failure again
    format(atom(What), 'Non-standard user account: ~w (UID: ~w, home: ~w)', [Username, UID, HomeDir]),
    Evidence = user_account(Username, UID, HomeDir),
    Recommendation = 'Review /etc/passwd and /etc/shadow. If this account was not deliberately created for a service or user, consider removing it. Check for any cron jobs or sudo privileges.'.

% ============================================================
% Utility: pretty-print one finding
% ============================================================

explain_finding(Stream, finding(What, Severity, Evidence, Recommendation)) :-
    format(Stream, '~n=== ~w SEVERITY: ~w ===~n', [Severity, What]),
    format(Stream, 'Evidence: ~w~n', [Evidence]),
    format(Stream, 'Action:   ~w~n', [Recommendation]).

% You can also export a version that takes a list and prints all.