% src/context.pl
% Global runtime state shared across all modules.
%
% This module owns all dynamic facts that represent:
%   - SSH connection parameters (set once at startup by main.pl)
%   - Remote system facts (synced by ssh_bridge.pl on each run)
%
% Any module that needs to read or assert these facts should
% use_module this file directly, avoiding circular dependencies.

:- module(context, [
    target_host/1,
    target_port/1,
    target_user/1,
    running_kernel/1,
    installed_kernel/1,
    temp_file/3,
    autoremove_candidate/1,
    modified_file/2,
    deleteable_temp_files/1,
    process/13,
    open_port/11,
    suspicious_process/1,
    run_mode/1,
    user/6,
    failed_login/3
]).

% Run mode — either dry_run or execute. Set once at startup by main.pl.
:- dynamic run_mode/1.

% SSH connection parameters — asserted once by main.pl after CLI parsing.
:- dynamic target_host/1.
:- dynamic target_port/1.
:- dynamic target_user/1.

% Remote system facts — retracted and re-asserted on each sync by ssh_bridge.pl.
:- dynamic running_kernel/1.
:- dynamic installed_kernel/1.
:- dynamic temp_file/3.           % temp_file(Path, SizeMB, AgeDays)
:- dynamic autoremove_candidate/1. % autoremove_candidate(PackageName)
:- dynamic modified_file/2.       % modified_file(Path, Timestamp)
:- dynamic open_port/11.          % open_port(Netid, State, RecvQ, SendQ, LocalAddress, LocalPort, PeerAddress, PeerPort, Process, PID, Name)
:- dynamic process/13.             % process(PID, PPID, UID, User, PCPU, PMEM, VSZ, RSS, TTY, Stat, StartTime, Time, Cmd)
:- dynamic user/6.                % user(Username, UID, GID, Groupname, HomeDir, Shell)
:- dynamic failed_login/3.        % failed_login(Timestamp, Username, SourceIP)

% Synthizized facts based on rules from the sync'd facts.
:- dynamic deleteable_temp_files/1.      % list of temp_file/3 that meet deletion criteria