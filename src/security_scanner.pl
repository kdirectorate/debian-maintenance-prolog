:- module(security_scanner, [
    run_security_scan/2,
    finding/4
]).

/* Teaching note (Lesson 5 preview of Lesson 6):
   We will implement at least 5 declarative checks:
   1. Unexpected listening ports (negation: port \in expected_whitelist)
   2. Brute-force patterns in auth.log
   3. Recently modified critical binaries (/bin, /sbin, /etc/passwd etc.)
   4. UID 0 accounts that are not in the known list
   5. World-writable files in /etc or suspicious SSH authorized_keys changes

   Each finding will be returned as:
   finding(Description, Severity, Evidence, RecommendedAction)

   Severity will be decided with cuts (!) once a strong indicator is found
   (green cut for efficiency, red cut avoided for safety).
*/
run_security_scan(_DataFromBridge, []).
% TODO Lesson 6: fill with the five+ rules using \+ and !