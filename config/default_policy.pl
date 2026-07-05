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
    suspicious_process/1,
    report_file/1,
    standard_user/1
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

% standard non-root users (add any you deliberately created)
% =============================================
% standard_user/1 facts as proper Prolog ATOMS
% Converted from your reference list
% Single quotes used only where required (hyphens + leading underscore)
% =============================================

standard_user(daemon).
standard_user(bin).
standard_user(sys).
standard_user(sync).
standard_user(games).
standard_user(man).
standard_user(lp).
standard_user(mail).
standard_user(news).
standard_user(uucp).
standard_user(proxy).
standard_user('www-data').
standard_user(backup).
standard_user(list).
standard_user(irc).
standard_user(gnats).
standard_user(nobody).
standard_user('_apt').
standard_user('systemd-network').
standard_user('systemd-resolve').
standard_user(messagebus).
standard_user('systemd-timesync').
standard_user('avahi-autoipd').
standard_user(sshd).
standard_user('systemd-coredump').
standard_user(lightdm).
standard_user(saned).
standard_user('pulse').
standard_user('colord').
standard_user('geoclue').
standard_user(polkitd).
standard_user(speech-dispatcher).
standard_user(rtkit).
standard_user(dnsmasq).
standard_user(avahi).
standard_user(speech-dispatcher).

% Process basenames that are rarely legitimate on a production server
% (matched against ps output; extend as your environment requires)

% Network reconnaissance and raw socket tooling
suspicious_process('netcat').
suspicious_process('nc').
suspicious_process('ncat').
suspicious_process('nmap').
suspicious_process('masscan').
suspicious_process('hping3').
suspicious_process('nikto').
suspicious_process('pwncat').

% Reverse shells, tunneling, and C2 plumbing
suspicious_process('socat').
suspicious_process('cryptcat').
suspicious_process('ngrok').
suspicious_process('iodine').
suspicious_process('chisel').
suspicious_process('frpc').
suspicious_process('frps').
suspicious_process('ligolo').
suspicious_process('cobaltstrike').

% Brute-force and credential attacks
suspicious_process('hydra').
suspicious_process('medusa').
suspicious_process('john').
suspicious_process('hashcat').

% Cryptominers and known miner malware names
suspicious_process('xmrig').
suspicious_process('minerd').
suspicious_process('cpuminer').
suspicious_process('kdevtmpfsi').
suspicious_process('kinsing').

% Exploitation frameworks and injection tooling
suspicious_process('msfvenom').
suspicious_process('sqlmap').

% Post-exploitation enumeration (often dropped into /tmp)
suspicious_process('linpeas').
suspicious_process('linenum').
suspicious_process('pspy').
