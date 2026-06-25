/*  File:     src/security_scanner.pl
    Module:   security_scanner
    Purpose:  Declarative host-based security checks for the Debian maintenance tool.
              All policy decisions live here so they are auditable and easy to change.
*/

:- module(security_scanner, [
    run_security_scan/1,      % +Findings:list
    security_finding/4,       % finding(What, Severity, Evidence, Recommendation)
    explain_finding/1
]).

:- use_module(library(lists)).
:- use_module('../config/default_policy').   % thresholds & whitelists live here

% ============================================================
% POLICY FACTS (move more complex ones to default_policy.pl later)
% ============================================================

% Expected listening ports (extend as you add services)
expected_listening_port(22, tcp).     % SSH
expected_listening_port(80, tcp).
expected_listening_port(443, tcp).
expected_listening_port(53, udp).     % DNS if you run it
expected_listening_port(9000, tcp).     

critical_file('/etc/passwd').
critical_file('/etc/shadow').
critical_file('/etc/sudoers').
critical_file('/bin/login').
critical_file('/usr/sbin/sshd').
critical_file('/etc/ssh/sshd_config').
critical_file('/etc/ssh/ssh_config').

% Brute-force threshold (number of failed logins from one IP)
brute_force_threshold(3).

% Standard root-equivalent users (add any you deliberately created)
standard_root_user(root).
standard_root_user(toor).

% ============================================================
% MAIN ENTRY POINT
% ============================================================

%% run_security_scan(-Findings) is det.
%  Collects findings from all five checks.
%  This is the predicate you will call from main.pl or the report generator.
run_security_scan(Findings) :-
    collect_port_findings(PortFindings),
    collect_brute_force_findings(BruteFindings),
    collect_file_mod_findings(FileFindings),
    collect_suspicious_process_findings(ProcFindings),
    collect_uid0_findings(UID0Findings),
    append([PortFindings, BruteFindings, FileFindings, ProcFindings, UID0Findings],
           Unsorted),
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

% ============================================================
% CHECK 1: Unexpected listening ports (uses negation as failure)
% ============================================================

check_unexpected_port(What, Severity, Evidence, Recommendation) :-
    listening_port(Port, Proto),
    \+ expected_listening_port(Port, Proto),           % ← negation as failure
    classify_port_severity(Port, Proto, Severity),
    format(atom(What), 'Unexpected listening ~w port ~w', [Proto, Port]),
    Evidence = listening_port(Port, Proto),
    Recommendation = 'Run: ss -tuln | grep LISTEN  and  journalctl -u <service>. If legitimate, add it to expected_listening_port/2 in policy or default_policy.pl. Consider firewall rules.'.

% Green cut used here to make classification deterministic
classify_port_severity(Port, _Proto, high) :-
    Port > 32768,          % high-numbered ephemeral ports are common backdoor locations
    !.
classify_port_severity(Port, tcp, medium) :-
    Port > 1024,           % non-privileged port
    !.
classify_port_severity(_, _, low).

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
    findall(1, failed_login(IP, _, _), Attempts),
    length(Attempts, Count),
    brute_force_threshold(Thresh),
    Count >= Thresh.

% ============================================================
% CHECK 3: Recently modified critical system files
% ============================================================

check_recent_critical_mod(What, high, Evidence, Recommendation) :-
    modified_file(Path, AgeDays),
    critical_file(Path),
    AgeDays =< 7,                    % within last week
    format(atom(What), 'Critical file ~w modified ~w days ago', [Path, AgeDays]),
    Evidence = modified_file(Path, AgeDays),
    Recommendation = 'Verify with: debsums -c ~w or dpkg -V. Check package manager history (apt history.log). If unexpected, treat as potential compromise. Compare mtime with last legitimate update.'.

% ============================================================
% CHECK 4: Suspicious processes (root running from tmp or unusual locations)
% ============================================================

check_suspicious_process(What, high, Evidence, Recommendation) :-
    process(PID, root, Cmdline, ExePath),
    suspicious_exe_location(ExePath),
    format(atom(What), 'Root-owned process ~w (PID ~w) running from suspicious location', [Cmdline, PID]),
    Evidence = process(PID, root, Cmdline, ExePath),
    Recommendation = 'Investigate immediately with: ps auxfww, lsof -p <PID>, and cat /proc/<PID>/exe. Kill only after confirmation. This is a classic sign of privilege escalation or malware.'.

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
    user_account(User, 0, Home),
    \+ standard_root_user(User),           % negation as failure again
    format(atom(What), 'Non-standard UID 0 account: ~w (home: ~w)', [User, Home]),
    Evidence = user_account(User, 0, Home),
    Recommendation = 'This is extremely serious. Review /etc/passwd and /etc/shadow. Remove the account if it was not deliberately created. Check authorized_keys and cron jobs for this user.'.

% ============================================================
% Utility: pretty-print one finding
% ============================================================

explain_finding(finding(What, Severity, Evidence, Recommendation)) :-
    format('~n=== ~w SEVERITY: ~w ===~n', [Severity, What]),
    format('Evidence: ~w~n', [Evidence]),
    format('Action:   ~w~n', [Recommendation]).

% You can also export a version that takes a list and prints all.