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
temp_file('/tmp/old_large_cache.tmp', 5242880, 172800).   % 5MB, ~2 days old  -> DELETE
temp_file('/var/tmp/huge_old_log',   10485760, 259200).  % 10MB, 3 days old -> DELETE
temp_file('/tmp/recent_big_file',     3145728,  3600).   % 3MB, 1h old      -> KEEP
temp_file('/tmp/tiny_old.txt',           4096, 172800).   % tiny + old       -> KEEP (size threshold)
temp_file('/var/tmp/medium_old',      2097152,  90000).   % 2MB, ~25h old    -> DELETE
temp_file('/tmp/session_cache_1234',   1048576,  72000).   % 1MB, 20h old     -> borderline