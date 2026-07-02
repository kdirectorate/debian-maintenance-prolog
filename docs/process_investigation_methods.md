**Reconstruct and inspect the process tree via ppid.**  
Build parent-child relationships. Flag these patterns immediately:  
- Any network daemon (sshd, nginx, apache, httpd, php-fpm, tomcat, etc.) that has direct children running shells (bash, sh, dash, zsh), python, perl, ruby, or nc/socat. This is the classic web shell or command injection signature.  
- Shell or interpreter processes whose parent is not a login process, sshd, or expected interactive session manager.  
- Processes with ppid=1 that are not documented system daemons for that distro/role.  
- Deep or unusual spawning chains (e.g., cron → bash → python → nc).

**Command-line IoC pattern matching on the cmd field.**  
Scan for these classes of indicators (case-insensitive, context-aware):  
- Reverse/bind shell primitives: `/dev/tcp/`, `/dev/udp/`, `bash -i >&`, `nc -e`, `socat`, `python -c` containing socket/connect/send, `perl -e` equivalents, `ruby -rsocket`.  
- Download-and-execute or pipe-to-shell: `curl`, `wget`, `fetch` followed by `| sh`, `| bash`, `| python`, or `| base64 -d`.  
- Obfuscation layers: `base64`, `eval`, `exec`, `$(`, backticks, multiple layers of quoting/encoding in a single cmd.  
- Common post-exploitation binaries/tools appearing in cmd: `chisel`, `ligolo`, `pwncat`, `meterpreter`, `sliver`, `cobaltstrike`, `empire`, `nmap` from unexpected paths or with unusual flags, `masscan`, `linpeas`, `linenum`, `pspy`, etc.  
- Paths in /tmp, /dev/shm, /var/tmp, /run/user/*, or any user-writable directory for uid=0 processes.  
- Long argument strings that look like encoded payloads.

**Privilege and path anomalies.**  
- uid=0 processes whose cmd path lives outside standard system directories (/usr/sbin, /usr/bin, /sbin, /bin, packaged locations) or points into user-controlled locations.  
- Any process running as root whose binary name mimics a legitimate service but from a non-standard location.  
- Non-root processes successfully listening on ports <1024 (should be rare post-exploit unless capabilities are involved).

**Network exposure and connection anomalies from ss data.**  
- LISTEN sockets bound to 0.0.0.0 or [::] on high, random, or non-standard ports by processes that are not supposed to be public-facing.  
- Established outbound connections (peer_address not 127.0.0.1/localhost and not expected infrastructure IPs) originating from processes that have no business making external connections.  
- High recv_q or send_q on any connection — indicates bulk data movement consistent with exfil or C2 channels.  
- UDP sockets with processes attached in unexpected ways.  
- Any process name from ss that does not reasonably match the basename of the cmd from ps.

**Resource and state anomalies.**  
- Processes in the top tier of pcpu or pmem that do not correspond to known legitimate workloads on this host (crypto miners often appear here with sustained high CPU and generic names).  
- rss/vsz values grossly disproportionate to the binary's expected footprint.  
- stat values showing zombies (Z), stopped (T), or unusual combinations for the process type.  
- TTY='?' on interactive shells or TTY attached to daemon processes that should be detached.

**User and session anomalies.**  
- Daemons or long-running services executing under unexpected user accounts.  
- Shell processes running under service accounts that should never have interactive shells.

**Whitelisting and context rules (non-negotiable).**  
Single-snapshot heuristics without a baseline produce excessive noise. You must maintain or rapidly build a host-specific whitelist of expected: listening ports + owning processes, uid=0 processes and their paths, service users, and normal parent-child relationships. Everything outside the whitelist is suspicious until manually cleared.  

For an authorized pentest you additionally need a second whitelist layer: your own authorized tools and implants vs. pre-existing unauthorized ones. Failure to separate the two wastes time and risks false reporting.

**Hard limitations of this data and approach.**  
This is static snapshot analysis only. It catches persistent backdoors, current shells, and obvious network listeners well but completely misses:  
- Fileless/memory-only implants that don't appear cleanly in ps.  
- Short-lived processes that exit between collection and analysis.  
- Injected threads or library hijacking without new processes.  
- Persistence via cron, systemd timers, rc.local, ld.so.preload, etc. (not visible here).  

If you are doing serious compromise assessment, treat ps+ss correlation as triage only. Real detection requires process creation auditing (auditd, osquery, Falco, or EDR), file integrity monitoring, and behavioral baselining over time. Relying solely on these parsed snapshots for "is this hacked?" decisions is incomplete and will produce both false negatives and false positives.

**Prioritization order for review.**  
1. Unexpected root listeners correlated to suspicious cmd/paths.  
2. Service → shell spawning chains.  
3. High-resource unknown processes with network activity.  
4. Outbound connections from non-server processes with high queue depths.  
5. Anything matching the classic reverse shell / download-execute patterns.

Apply the above rules ruthlessly and in that order. Context of the specific host (role, distro, expected services) overrides generic rules every time.

Sample Output from "ps -eo pid,ppid,uid,user,pcpu,pmem,vsz,rss,tty,stat,start_time,time,cmd"

    PID    PPID   UID USER     %CPU %MEM    VSZ   RSS TT       STAT START     TIME CMD
      1       0     0 root      0.0  0.6 102672 12664 ?        Ss   Jun25 00:00:15 /sbin/init
      2       0     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [kthreadd]
      3       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [rcu_gp]
      4       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [rcu_par_gp]
      5       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [slub_flushwq]
      6       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [netns]
      8       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [kworker/0:0H-events_highpri]
     10       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [mm_percpu_wq]
     11       2     0 root      0.0  0.0      0     0 ?        I    Jun25 00:00:00 [rcu_tasks_kthread]
     12       2     0 root      0.0  0.0      0     0 ?        I    Jun25 00:00:00 [rcu_tasks_rude_kthread]
     13       2     0 root      0.0  0.0      0     0 ?        I    Jun25 00:00:00 [rcu_tasks_trace_kthread]
     14       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:01 [ksoftirqd/0]
     15       2     0 root      0.0  0.0      0     0 ?        I    Jun25 00:00:12 [rcu_preempt]
     16       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:02 [migration/0]
     18       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [cpuhp/0]
     19       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [cpuhp/1]
     20       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:02 [migration/1]
     21       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:02 [ksoftirqd/1]
     26       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [kdevtmpfs]
     27       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [inet_frag_wq]
     28       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [kauditd]
     29       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [khungtaskd]
     31       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [oom_reaper]
     32       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [writeback]
     33       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:17 [kcompactd0]
     34       2     0 root      0.0  0.0      0     0 ?        SN   Jun25 00:00:00 [ksmd]
     36       2     0 root      0.0  0.0      0     0 ?        SN   Jun25 00:00:06 [khugepaged]
     37       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [kintegrityd]
     38       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [kblockd]
     39       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [blkcg_punt_bio]
     40       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [tpm_dev_wq]
     41       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [edac-poller]
     42       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [devfreq_wq]
     43       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [kworker/1:1H-kblockd]
     44       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [kswapd0]
     50       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [kthrotld]
     52       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [irq/24-aerdrv]
     53       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [irq/25-aerdrv]
     54       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [irq/26-aerdrv]
     55       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [irq/27-aerdrv]
     56       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [irq/28-aerdrv]
     57       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [irq/29-aerdrv]
     58       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [irq/30-aerdrv]
     59       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [irq/31-aerdrv]
     60       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [irq/32-aerdrv]
     61       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [irq/33-aerdrv]
     62       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [irq/34-aerdrv]
     63       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [irq/35-aerdrv]
     64       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [irq/36-aerdrv]
     65       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [irq/37-aerdrv]
     66       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [acpi_thermal_pm]
     68       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [mld]
     69       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [ipv6_addrconf]
     74       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [kstrp]
     79       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [zswap-shrink]
     80       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [kworker/u5:0]
    140       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:01 [kworker/0:1H-kblockd]
    146       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [ata_sff]
    148       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [scsi_eh_0]
    149       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [scsi_tmf_0]
    150       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [scsi_eh_1]
    151       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [scsi_tmf_1]
    152       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [scsi_eh_2]
    153       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [scsi_tmf_2]
    154       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [scsi_eh_3]
    155       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [scsi_tmf_3]
    156       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [scsi_eh_4]
    157       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [scsi_tmf_4]
    158       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [scsi_eh_5]
    159       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [scsi_tmf_5]
    167       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:02 [kworker/1:2H-kblockd]
    204       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:03 [jbd2/vda1-8]
    205       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [ext4-rsv-conver]
    219       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [hwrng]
    248       1     0 root      0.0  2.3  78500 47144 ?        Ss   Jun25 00:00:07 /lib/systemd/systemd-journald
    275       1     0 root      0.0  0.3  28232  7228 ?        Ss   Jun25 00:00:00 /lib/systemd/systemd-udevd
    293       1   997 systemd+  0.0  0.3  90128  6860 ?        Ssl  Jun25 00:00:02 /lib/systemd/systemd-timesyncd
    339       2     0 root      0.0  0.0      0     0 ?        S    Jun25 00:00:00 [watchdogd]
    347       2     0 root      0.0  0.0      0     0 ?        I<   Jun25 00:00:00 [cryptd]
    513       1   102 avahi     0.0  0.2   8440  4388 ?        Ss   Jun25 00:00:55 avahi-daemon: running [debian12.local]
    514       1     0 root      0.0  0.1   6616  2592 ?        Ss   Jun25 00:00:00 /usr/sbin/cron -f
    515       1   100 message+  0.0  0.2  10532  5916 ?        Ss   Jun25 00:00:12 /usr/bin/dbus-daemon --system --address=systemd: --nofork --nopidfile --systemd-activation --syslog-only
    518       1   996 polkitd   0.0  0.5 310888 11320 ?        Ssl  Jun25 00:00:52 /usr/lib/polkit-1/polkitd --no-debug
    519       1     0 root      0.0  0.1  80252  3748 ?        Ssl  Jun25 00:00:00 /usr/sbin/qemu-ga
    520       1     0 root      0.0  0.4  17296  8488 ?        Ss   Jun25 00:00:04 /lib/systemd/systemd-logind
    522       1     0 root      0.0  0.7 394844 14968 ?        Ssl  Jun25 00:00:01 /usr/libexec/udisks2/udisksd
    524     513   102 avahi     0.0  0.0   8112   360 ?        S    Jun25 00:00:00 avahi-daemon: chroot helper
    525       1     0 root      0.0  1.0 258644 22052 ?        Ssl  Jun25 00:00:34 /usr/sbin/NetworkManager --no-daemon
    528       1     0 root      0.0  0.2  16552  5868 ?        Ss   Jun25 00:00:02 /sbin/wpa_supplicant -u -s -O DIR=/run/wpa_supplicant GROUP=netdev
    537       1     0 root      0.0  0.6 317340 14036 ?        Ssl  Jun25 00:00:00 /usr/sbin/ModemManager
    555       1     0 root      0.0  0.3 308896  7604 ?        SLsl Jun25 00:00:00 /usr/sbin/lightdm
    563       1     0 root      0.0  0.4  15452  9372 ?        Ss   Jun25 00:00:01 sshd: /usr/sbin/sshd -D [listener] 0 of 10-100 startups
    590     555     0 root      0.0  4.9 629044 99412 tty7     Ssl+ Jun25 00:00:06 /usr/lib/xorg/Xorg :0 -seat seat0 -auth /var/run/lightdm/root/:0 -nolisten tcp vt7 -novtswitch
    591       1     0 root      0.0  0.0   5880  1012 tty1     Ss+  Jun25 00:00:00 /sbin/agetty -o -p -- \u --noclear - linux
    597       1     0 root      0.0  0.2   6600  5124 ?        Ss   Jun25 00:00:28 /usr/sbin/apache2 -k start
    697       1   107 rtkit     0.0  0.0  22708  1532 ?        SNsl Jun25 00:00:04 /usr/libexec/rtkit-daemon
   1046     555     0 root      0.0  0.4 162508  8252 ?        Sl   Jun25 00:00:00 lightdm --session-child 15 26
   1054       1  1000 shinhwa   0.0  0.5  19184 10964 ?        Ss   Jun25 00:00:00 /lib/systemd/systemd --user
   1055    1054  1000 shinhwa   0.0  0.1 103356  3240 ?        S    Jun25 00:00:00 (sd-pam)
   1072    1054  1000 shinhwa   0.0  1.5 654452 31432 ?        S<sl Jun25 00:00:00 /usr/bin/pulseaudio --daemonize=no --log-target=journal
   1074    1054  1000 shinhwa   0.0  0.5 239792 11892 ?        SLsl Jun25 00:00:00 /usr/bin/gnome-keyring-daemon --foreground --components=pkcs11,secrets --control-directory=/run/user/1000/keyring
   1081    1054  1000 shinhwa   0.0  0.2   9416  5272 ?        Ss   Jun25 00:01:15 /usr/bin/dbus-daemon --session --address=systemd: --nofork --nopidfile --systemd-activation --syslog-only
   1082    1046  1000 shinhwa   0.0  1.2 264228 24928 ?        Ssl  Jun25 00:00:01 xfce4-session
   1134    1082  1000 shinhwa   0.0  0.0   7704   776 ?        Ss   Jun25 00:00:02 /usr/bin/ssh-agent x-session-manager
   1144    1054  1000 shinhwa   0.0  0.6 311120 12220 ?        Ssl  Jun25 00:00:00 /usr/libexec/at-spi-bus-launcher
   1150    1144  1000 shinhwa   0.0  0.2   9132  4908 ?        S    Jun25 00:00:00 /usr/bin/dbus-daemon --config-file=/usr/share/defaults/at-spi2/accessibility.conf --nofork --print-address 11 --address=unix:path=/run/user/1000/at-spi/bus_0
   1160    1054  1000 shinhwa   0.0  0.4 164404  8896 ?        Sl   Jun25 00:00:00 /usr/libexec/at-spi2-registryd --use-gnome-session
   1170    1054  1000 shinhwa   0.0  0.2  81264  5492 ?        SLs  Jun25 00:00:00 /usr/bin/gpg-agent --supervised
   1173    1082  1000 shinhwa   0.0  5.1 937496 104012 ?       Sl   Jun25 00:00:04 xfwm4
   1176    1054  1000 shinhwa   0.0  0.4 237524  9780 ?        Ssl  Jun25 00:00:00 /usr/libexec/gvfsd
   1192    1082  1000 shinhwa   0.0  1.3 227872 27000 ?        Sl   Jun25 00:00:00 xfsettingsd
   1195       1     0 root      0.0  0.4 233772  8232 ?        Ssl  Jun25 00:00:00 /usr/libexec/upowerd
   1200    1082  1000 shinhwa   0.0  2.3 474000 46724 ?        Sl   Jun25 00:00:15 xfce4-panel
   1204    1082  1000 shinhwa   0.0  1.3 338820 26896 ?        Sl   Jun25 00:00:00 Thunar --daemon
   1209    1082  1000 shinhwa   0.0  2.9 551464 60012 ?        Sl   Jun25 00:00:06 xfdesktop
   1213    1082  1000 shinhwa   0.0  1.8  60844 36340 ?        S    Jun25 00:00:00 /usr/bin/python3 /usr/share/system-config-printer/applet.py
   1216    1082  1000 shinhwa   0.0  1.8 443328 37472 ?        Sl   Jun25 00:00:00 nm-applet
   1219    1082  1000 shinhwa   0.0  0.4 850436  8708 ?        Sl   Jun25 00:00:00 xiccd
   1220    1200  1000 shinhwa   0.0  1.2 337796 25280 ?        Sl   Jun25 00:00:00 /usr/lib/x86_64-linux-gnu/xfce4/panel/wrapper-2.0 /usr/lib/x86_64-linux-gnu/xfce4/panel/plugins/libsystray.so 6 16777228 systray Status Tray Plugin Provides status notifier items (application indicators) and legacy systray items
   1221    1082  1000 shinhwa   0.0  1.4 420792 28300 ?        Sl   Jun25 00:00:02 light-locker
   1225    1082  1000 shinhwa   0.0  1.2 190600 25644 ?        Sl   Jun25 00:00:04 xfce4-power-manager
   1226    1200  1000 shinhwa   0.0  1.7 559268 35584 ?        Sl   Jun25 00:03:23 /usr/lib/x86_64-linux-gnu/xfce4/panel/wrapper-2.0 /usr/lib/x86_64-linux-gnu/xfce4/panel/plugins/libpulseaudio-plugin.so 8 16777229 pulseaudio PulseAudio Plugin Adjust the audio volume of the PulseAudio sound system
   1228    1082  1000 shinhwa   0.0  0.9 186092 18636 ?        Sl   Jun25 00:00:00 /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1
   1230    1200  1000 shinhwa   0.0  1.6 349812 32440 ?        Sl   Jun25 00:00:00 /usr/lib/x86_64-linux-gnu/xfce4/panel/wrapper-2.0 /usr/lib/x86_64-linux-gnu/xfce4/panel/plugins/libxfce4powermanager.so 9 16777230 power-manager-plugin Power Manager Plugin Display the battery levels of your devices and control the brightness of your display
   1231       1   108 colord    0.0  0.7 242464 15272 ?        Ssl  Jun25 00:00:00 /usr/libexec/colord
   1235    1082  1000 shinhwa   0.0  1.0 260988 20600 ?        Sl   Jun25 00:00:00 /usr/lib/x86_64-linux-gnu/xfce4/notifyd/xfce4-notifyd
   1240    1200  1000 shinhwa   0.0  2.0 331560 40396 ?        Sl   Jun25 00:00:00 /usr/lib/x86_64-linux-gnu/xfce4/panel/wrapper-2.0 /usr/lib/x86_64-linux-gnu/xfce4/panel/plugins/libnotification-plugin.so 10 16777231 notification-plugin Notification Plugin Notification plugin for the Xfce panel
   1244    1054  1000 shinhwa   0.0  0.6 351380 13336 ?        Ssl  Jun25 00:00:00 /usr/libexec/gvfs-udisks2-volume-monitor
   1276    1054  1000 shinhwa   0.0  0.3 156336  6388 ?        Ssl  Jun25 00:00:00 /usr/libexec/dconf-service
   1281    1176  1000 shinhwa   0.0  0.4 311504 10060 ?        Sl   Jun25 00:00:00 /usr/libexec/gvfsd-trash --spawner :1.14 /org/gtk/gvfs/exec_spaw/0
   1291    1054  1000 shinhwa   0.0  0.4 159820  8888 ?        Ssl  Jun25 00:00:00 /usr/libexec/gvfsd-metadata
   1316    1200  1000 shinhwa   0.0  1.4 347456 28376 ?        Sl   Jun25 00:00:00 /usr/lib/x86_64-linux-gnu/xfce4/panel/wrapper-2.0 /usr/lib/x86_64-linux-gnu/xfce4/panel/plugins/libactions.so 14 16777232 actions Action Buttons Log out, lock or other system actions
   1451       1  1000 shinhwa   0.0  2.1 535540 42372 ?        Sl   Jun25 00:00:00 xfce4-terminal
   1476    1451  1000 shinhwa   0.0  0.2   9576  5720 pts/0    Ss   Jun25 00:00:00 bash
   1504    1476     0 root      0.0  0.1   9076  3872 pts/0    S    Jun25 00:00:00 su - root
   1505    1504     0 root      0.0  0.2   9576  5804 pts/0    S+   Jun25 00:00:00 -bash
   1903     555     0 root      0.0  3.9 633220 78692 tty8     Ssl+ Jun25 00:00:09 /usr/lib/xorg/Xorg :1 -seat seat0 -auth /var/run/lightdm/root/:1 -nolisten tcp vt8 -novtswitch
   1941     555     0 root      0.0  0.3 162388  7528 ?        Sl   Jun25 00:00:00 lightdm --session-child 21 26
   1946       1   106 lightdm   0.0  0.5  19128 10756 ?        Ss   Jun25 00:00:00 /lib/systemd/systemd --user
   1948    1946   106 lightdm   0.0  0.1 103784  3576 ?        S    Jun25 00:00:00 (sd-pam)
   1976    1946   106 lightdm   0.0  1.5 392004 30732 ?        S<sl Jun25 00:00:00 /usr/bin/pulseaudio --daemonize=no --log-target=journal
   1983    1941   106 lightdm   0.0  5.5 689332 112396 ?       Ssl  Jun25 00:01:32 /usr/sbin/lightdm-gtk-greeter
   1995    1946   106 lightdm   0.0  0.2   9132  4416 ?        Ss   Jun25 00:00:00 /usr/bin/dbus-daemon --session --address=systemd: --nofork --nopidfile --systemd-activation --syslog-only
   1997    1946   106 lightdm   0.0  0.4 311048  9664 ?        Ssl  Jun25 00:00:00 /usr/libexec/at-spi-bus-launcher
   2006    1997   106 lightdm   0.0  0.2   9000  4444 ?        S    Jun25 00:00:00 /usr/bin/dbus-daemon --config-file=/usr/share/defaults/at-spi2/accessibility.conf --nofork --print-address 11 --address=unix:path=/run/user/106/at-spi/bus
   2008    1946   106 lightdm   0.0  0.5 237396 11428 ?        Ssl  Jun25 00:00:00 /usr/libexec/gvfsd
   2066    1946   106 lightdm   0.0  0.5 164336 11512 ?        Sl   Jun25 00:00:00 /usr/libexec/at-spi2-registryd --use-gnome-session
   2073     555     0 root      0.0  0.2  14564  5776 ?        S    Jun25 00:00:00 lightdm --session-child 17 29
 104400     597    33 www-data  0.0  0.3 1212648 6968 ?        Sl   00:00 00:00:00 /usr/sbin/apache2 -k start
 104401     597    33 www-data  0.0  0.5 1212648 11052 ?       Sl   00:00 00:00:00 /usr/sbin/apache2 -k start
 104466       1     0 root      0.0  0.4  27404  9348 ?        Ss   00:00 00:00:00 /usr/sbin/cupsd -l
 104469       1     0 root      0.0  0.7 176676 15712 ?        Ssl  00:00 00:00:00 /usr/sbin/cups-browsed
 106061       2     0 root      0.0  0.0      0     0 ?        I    12:33 00:00:00 [kworker/0:0-events]
 107627       2     0 root      0.0  0.0      0     0 ?        I    12:39 00:00:00 [kworker/1:0-cgroup_free]
 108367       2     0 root      0.0  0.0      0     0 ?        I    12:41 00:00:00 [kworker/1:1-events]
 109799       2     0 root      0.0  0.0      0     0 ?        I    12:47 00:00:00 [kworker/u4:0-events_unbound]
 109815       2     0 root      0.0  0.0      0     0 ?        I    13:06 00:00:00 [kworker/0:1]
 109827       2     0 root      0.0  0.0      0     0 ?        I    13:17 00:00:00 [kworker/u4:2-events_unbound]
 109836     563     0 root      0.0  0.5  17896 11032 ?        Ss   13:23 00:00:00 sshd: shinhwa [priv]
 109845       2     0 root      0.0  0.0      0     0 ?        I    13:23 00:00:00 [kworker/u4:1-events_unbound]
 109846  109836  1000 shinhwa   0.0  0.3  18156  6940 ?        S    13:23 00:00:00 sshd: shinhwa@pts/1
 109856  109846  1000 shinhwa   0.0  0.2   7980  4820 pts/1    Ss   13:23 00:00:00 -bash
 109857       2     0 root      0.0  0.0      0     0 ?        I    13:23 00:00:00 [kworker/u4:3]
 109868  109856  1000 shinhwa   0.0  0.2  11220  4856 pts/1    R+   13:25 00:00:00 ps -eo pid,ppid,uid,user,pcpu,pmem,vsz,rss,tty,stat,start_time,time,cmd

The database will have these terms processed from the above data:

process(PID, PPID, UID, User, PCPU, PMEM, VSZ, RSS, TTY, Stat, StartTime, Time, Cmd)