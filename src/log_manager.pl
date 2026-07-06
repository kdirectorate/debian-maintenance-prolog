:- module(log_manager, [
    log_should_be_truncated/1
]).

:- use_module(config/default_policy, [
    max_log_size_mb/1
]).
/* Teaching note (Lesson 5):
   This module will decide which /var/log files are "out of control".
   Typical policy: size > 100 MiB AND not a rotated archive (*.gz, *.1, etc.).
   We will use negation as failure (\+) to say "not a rotated log".
   Data will come from the bridge as a list of log_file(Path, SizeBytes, Mtime).

   Note: I changed the name the instructor had so that it would more
   closely match the style of the temp file predicates we already had.


    TODO: The entire logic behind this is flawed. We need a better way to
    determine if a log is roated or not. For example, /var/log/syslog.1 is a rotated log, 
    but /var/log/syslog is also a rotated log. Probably going to need to check
    the logrotate config to see what the actual log files are. 

    Basically just don't call these for now.
*/
log_should_be_truncated(log_file(Path, SizeBytes, _Mtime)) :-
    max_log_size_mb(MaxSizeMB),
    SizeMB is SizeBytes / (1024 * 1024),
    SizeMB > MaxSizeMB,
    \+ is_rotated_log(Path).

is_rotated_log(Path) :-
    file_name_extension(_Base, Ext, Path),
    rotated_extension(Ext).

rotated_extension(gz).
rotated_extension(Ext) :-
    atom_number(Ext, N),
    integer(N),
    N >= 0.

actually_remove_log_files(_LogFiles) :-
    true. % TODO: implement the actual removal logic
