% ============================================================
% main.pl - Lesson 1 entry point
% ============================================================
%
% TEACHING NOTE:
% For Lesson 1 we use the simple consult/1 mechanism.
% In Lesson 5 we will convert everything to proper modules
% with use_module/1 for better encapsulation.

:- use_module('config/default_policy').
:- use_module('src/kernel_cleaner').
:- use_module('src/temp_cleanup').
:- use_module('src/log_manager.pl').
:- use_module('src/apt_maintainer.pl').
:- use_module('src/security_scanner.pl').

% Optional banner so you know the files loaded cleanly
show_banner :-
    format('~n=== Debian System Maintenance Tool ===~n').

/* Teaching note:
   main.pl should stay small. Its job is:
   1. Parse CLI (later)
   2. Call the SSH bridge to collect data
   3. Ask each specialist module for decisions
   4. Produce the report (Lesson 7)
*/


run_lesson5_demo :-
    show_banner,

    % Example data that would normally come from the SSH bridge
    Running = '6.1.0-17-amd64',
    Installed = ['6.1.0-17-amd64', '6.1.0-16-amd64', '5.10.0-8-amd64', '5.10.0-7-amd64'],
    TempFiles = [temp_file('/tmp/old.log', 50*1024*1024, 10*86400),
                 temp_file('/tmp/recent.tmp', 100*1024, 3600)],
                 
    safe_to_remove_kernels(Running, Installed, SafeKernels),
    SafeKernelsTest = ['6.1.0-16-amd64', '5.10.0-8-amd64', '5.10.0-7-amd64'],
    % Test the value of SafeKernels against the expected value
    SafeKernels = SafeKernelsTest,  
    format('Kernels safe to remove: ~w~n', [SafeKernels]),
    
    % Temp file example (mock data)

    max_log_size_mb(F), max_temp_age_days(S), 
    files_to_delete(F, S, TempFiles, ToDelete),
    
    format('Temp files to delete: ~w~n', [ToDelete]),
    
    writeln('Orchestration successful. All modules loaded and cooperating.').