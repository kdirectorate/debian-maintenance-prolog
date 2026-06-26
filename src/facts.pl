% ============================================================
% facts.pl - Lesson 1: Modeling system state as Prolog facts
% ============================================================
%
% TEACHING NOTE:
% A FACT is the most basic building block in Prolog.
% It declares that something is true, with no conditions.
% Facts are the "database" that our rules will later query.
%
% Syntax reminder:
%   predicate_name(AtomOrVariable, ...).
% Atoms (constants) start with lowercase or are single-quoted.
% Variables start with UPPERCASE or underscore.
%
% In a real run of our tool, Python will collect this data over SSH
% and we will assert these facts dynamically. For Lesson 1 we hard-code
% a tiny example so we can focus purely on logic and unification.

:- module(facts, [
    running_kernel/1,
    installed_kernel/1,
    temp_file/3,
    listening_port/2,
    failed_login/3,
    modified_file/2,
    process/4,
    user_account/3,
    log_file/2,
    critical_file/1,
    autoremove_candidate/1
    ]).

% === Facts generated from `apt autoremove --dry-run` ===

% All packages that apt wants to remove
autoremove_candidate('libdbus-glib-1-2').
autoremove_candidate('libmodule-scandeps-perl').
autoremove_candidate('libslirp0').
autoremove_candidate('libu2f-udev').
autoremove_candidate('slirp4netns').
autoremove_candidate('tini').


log_file('/var/log/bigfile.log', 20971520).
log_file('/var/log/smallfile.log', 1000).
log_file('/var/log/rotated.log.1', 20971520).

modified_file('/etc/passwd', 4).

process('sshd', 1234, 'root', '2024-06-01T12:00:00Z').

user_account('alice', '1001', '2024-06-01T12:00:00Z').

failed_login('alice', '192.168.1.100', '2024-06-01T12:34:56Z').

listening_port(22, tcp).      % SSH
listening_port(80, tcp).      % HTTP
listening_port(443, tcp).     % HTTPS

critical_file('/etc/passwd').
critical_file('/etc/shadow').
critical_file('/etc/sudoers').
critical_file('/bin/login').
critical_file('/usr/sbin/sshd').

% -----------------------------------------------------------
% running_kernel/1
% The single kernel we are currently booted into.
% Never remove this one (safety rule we will encode next).
% -----------------------------------------------------------
running_kernel('6.1.0-17-amd64').

% -----------------------------------------------------------
% installed_kernel/1
% All linux-image packages present on the system.
% Includes the running kernel + older ones that can potentially be removed.
% -----------------------------------------------------------
installed_kernel('6.1.0-17-amd64').   % the running one
installed_kernel('5.10.0-8-amd64').
installed_kernel('4.19.0-21-amd64').

% -----------------------------------------------------------
% temp_file/3  (Path, SizeBytes, AgeSeconds)
% Example temporary files. We will process these with recursion in Lesson 2.
% -----------------------------------------------------------
% Sample temp files for Lesson 2
% ============================================================
% temp_file(Path, SizeBytes, AgeSeconds)
% ============================================================

% DELETE because it is older than 5 days (even though size is fine)
temp_file('/tmp/old_large_cache.tmp', 5242880, 518400). 
% DELETE because it is older than 5 days (size is exactly 10MB but age triggers it)
temp_file('/var/tmp/huge_old_log',   10485760, 518400).
% DELETE because older than 5 days
temp_file('/var/tmp/medium_old',      2097152, 518400).
% KEEP - too recent (well under both thresholds)
temp_file('/tmp/recent_big_file',     3145728,   3600).
% KEEP - tiny size, even though old
temp_file('/tmp/tiny_old.txt',           4096, 432000).
% borderline case - exactly 5 days old and exactly 10MB
% With strict ">" this will be KEPT (AgeDays = 5 is not > 5, SizeMB = 10 is not > 10)
temp_file('/tmp/session_cache_1234', 10485760, 432000).
% 3 deletes and 3 keeps
