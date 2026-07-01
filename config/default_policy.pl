:- module(default_policy, [
    expected_listening_port/2,
    max_temp_age_days/1,
    max_temp_size_mb/1,
    max_log_size_mb/1,
    brute_force_threshold/1,
    keep_last_n_kernels/1,
    standard_root_user/1,
    default_target_host/1,
    default_target_port/1,
    default_target_user/1,
    critical_file/1,
    report_file/1
]).

% ============================================================
% POLICY FACTS 
% ============================================================

default_target_host('localhost').
default_target_port(22).  % default SSH port
default_target_user('root').

report_file('./maintenance_report.log').
    
max_temp_age_days(5).
max_temp_size_mb(10).
max_log_size_mb(10).
brute_force_threshold(5).
keep_last_n_kernels(2).   % safety: always keep the running kernel + this many previous ones

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

% Standard root-equivalent users (add any you deliberately created)
standard_root_user(root).
standard_root_user(toor).

