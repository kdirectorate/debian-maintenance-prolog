:- module(log_manager, [
    logs_to_truncate/3
]).

/* Teaching note (Lesson 5):
   This module will decide which /var/log files are "out of control".
   Typical policy: size > 100 MiB AND not a rotated archive (*.gz, *.1, etc.).
   We will use negation as failure (\+) to say "not a rotated log".
   Data will come from the bridge as a list of log_file(Path, SizeBytes, Mtime).
*/
logs_to_truncate(_MaxSizeMB, [], []).

% TODO (Lesson 6/7): implement real logic + truncation strategy