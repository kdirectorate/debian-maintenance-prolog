# Debian Maintenance Prolog 

This project started as a lesson plan created by Grok to teach me Prolog. I've always wanted to come up with a use for Prolog since I learned it a few decades ago. I finally thought up a use and via SWI-Prolog and Python3 I could implement it. I implemented about 80% of this code by hand and via AI autocomplete. The rest was 
mostly skeletons of modules created by Grok so that I would know the general structure.

This is implemented as a Prolog "conductor" with Python being the "hands" running SSH commands into the target. That's actually backwards, I think, of how it should be. Python should be the "conductor" providing facts to Prolog to make decisions. However, I did it this way because the point was to learn Prolog, not Python, so I wanted to do the maximum amount of Prolog coding.

There are still lots of things to do to this project to make it viable. I'm going to take what I've learned here and put it into a more production worthy version that is based on Python with Prolog making decisions. So consider this code finished. I will not be updating it. 

## USAGE:

```BASH
╰─$ swipl -g "set_prolog_flag(last_call_optimisation, false)" \
             -g "consult('main.pl')" \
             -g "debug_run(main)" -g "halt" -- -h          

=== Debian System Maintenance Tool ===
Usage: swipl -s main.pl [options]
Options:
  --dry-run           : Show what would be done without making changes
  --host <hostname>  : Specify the target host (default: default_target_host)
  --port <port>      : Specify the SSH port (default: default_target_port)
  --user <username>  : Specify the SSH user (default: default_target_user)
  -t                 : Create test data on remote server. DO NOT USE IN PROD
  -h                 : Display this help message
```

## EXAMPLE:
(Requires a user on the target system with a SSH key and sudo permissions without password.)

```BASH
╰─$ swipl -g "set_prolog_flag(last_call_optimisation, false)" \      
             -g "consult('main.pl')" \
             -g "debug_run(main)" -g "halt" -- --host debian12-maint-test --user shinhwa -t

=== Debian System Maintenance Tool ===
+---------------------------------+
| CREATING TEST DATA...           |
+---------------------------------+
Test temp files created.
Test apt dependencies created.
Test critical files tampered.
Test processes started.

========================================
Debian System Maintenance & Security Report
Host: debian12-maint-test
Generated: 2026-07-07 16:34:45   Mode: execute
========================================

[Security] Found 7 security issue(s):

=== high SEVERITY: Brute-force login attempts from 192.168.1.127 (5 failures) ===
Evidence: brute_force(192.168.1.127,5)
Action:   Immediately block the IP (fail2ban, ufw, or iptables). Review /var/log/auth.log or journalctl -u ssh. This is almost always malicious activity.

=== high SEVERITY: Modified file /etc/passwd modified 2.0 days ago ===
Evidence: modified_file(/etc/passwd,2.0)
Action:   Verify with: debsums -c ~w or dpkg -V. Check package manager history (apt history.log). If unexpected, treat as potential compromise. Compare mtime with last legitimate update.

=== medium SEVERITY: Non-standard user account: shinhwa (UID: 1000, home: /home/shinhwa) ===
Evidence: user_account(shinhwa,1000,/home/shinhwa)
Action:   Review /etc/passwd and /etc/shadow. If this account was not deliberately created for a service or user, consider removing it. Check for any cron jobs or sudo privileges.

=== high SEVERITY: Process cobaltstrike infinity (PID 1443) contains suspicious token cobaltstrike ===
Evidence: suspect_process(1443,shinhwa,cobaltstrike infinity)
Action:   Investigate immediately with: ps auxfww, lsof -p <PID>, and cat /proc/<PID>/exe. Kill only after confirmation.This is a classic sign of privilege escalation or malware.

=== high SEVERITY: Process nc infinity (PID 1425) contains suspicious token nc ===
Evidence: suspect_process(1425,shinhwa,nc infinity)
Action:   Investigate immediately with: ps auxfww, lsof -p <PID>, and cat /proc/<PID>/exe. Kill only after confirmation.This is a classic sign of privilege escalation or malware.

=== high SEVERITY: Process pwncat infinity (PID 1434) contains suspicious token pwncat ===
Evidence: suspect_process(1434,shinhwa,pwncat infinity)
Action:   Investigate immediately with: ps auxfww, lsof -p <PID>, and cat /proc/<PID>/exe. Kill only after confirmation.This is a classic sign of privilege escalation or malware.

=== low SEVERITY: Unexpected listening tcp port 631 ===
Evidence: listening_port(631,tcp)
Action:   Run: ss -tuln | grep LISTEN and journalctl -u <service>. If legitimate, add it to expected_listening_port/2 inpolicy or default_policy.pl. Consider firewall rules.

Log file analysis is currently disabled due to limitations in log rotation detection.

[APT] ACTION — auto-removing 2 package(s):
  - dctrl-tools
  - libapt-pkg-perl


Running Kernel:   - 6.1.0-49-amd64
[Kernels] ACTION — removing 1 kernel(s):
  - 6.1.0-13-amd64

[Temp Files] ACTION — deleting 1 temp file(s):
  - temp_file(/tmp/test_temp_20mb_expired,20.0,7.0)

========================================

--- End of Report ---


[INFO] Report written to maintenance_report.txt

>>> About to perform: maintenance actions
    Proceed? [y/N]: y
[INFO] Successfully removed apt packages.

[INFO] All marked apt packages removed.
[INFO] Successfully purged kernels.

[INFO] All marked kernels purged.

[INFO] All marked temp files deleted.
```
