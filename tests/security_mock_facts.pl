% tests/security_mock_facts.pl
listening_port(22, tcp).
listening_port(2222, tcp).          % should trigger unexpected + high
listening_port(9000, tcp).          % medium

failed_login('203.0.113.50', 'root', '2026-06-22T10:01').
failed_login('203.0.113.50', 'root', '2026-06-22T10:02').
failed_login('203.0.113.50', 'root', '2026-06-22T10:03').
failed_login('203.0.113.50', 'root', '2026-06-22T10:04').
failed_login('203.0.113.50', 'root', '2026-06-22T10:05').
failed_login('203.0.113.50', 'root', '2026-06-22T10:06').  % >= 5 → high

modified_file('/etc/passwd', 2).
modified_file('/etc/shadow', 1.5).
modified_file('/home/kdirectorate/.bashrc', 0.5).  % not critical → ignored by rule
modified_file('/etc/ssh/sshd_config', 3).  % critical → high

process(1234, root, 'python3 /tmp/backdoor.py', '/tmp/backdoor.py').
process(5678, www-data, 'nginx', '/usr/sbin/nginx').  % normal, ignored

user_account('root', 0, '/root').
user_account('toor', 0, '/root').
user_account('haxor', 0, '/home/haxor').   % should trigger high