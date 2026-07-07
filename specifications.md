
<head>
<style>
/* -------------------------------------------------
   Set the printable page margins
   ------------------------------------------------- */
@page {
    size: A4;                     /* or letter, legal, … */
    margin-top:    1cm;           /* top margin */
    margin-bottom: 1cm;           /* bottom margin */
    margin-left:   0.1cm;         /* left margin */
    margin-right:  0.1cm;         /* right margin */
}
  /* Base font size for screen and print */
  body { font-size: 14pt; }
  @media print {
    body { font-size: 14pt; }   /* ensures the same size when printed */
  }
</style>
</head>

# CS 520: Introduction to Logic Programming
## Programming Assignment 1: Debian System Maintenance & Security Auditor (Prolog + Python Hybrid)

**Version:** 1.0  
**Date:** June 21, 2026  
**Instructor:** Grok (Prolog Programming Instructor)  
**Format:** Individual project (pair programming allowed with prior approval)  
**Estimated Effort:** 15–25 hours (spread over 2–3 weeks)

---

### 1. Purpose and Context

This assignment gives you hands-on experience applying **declarative logic programming** to a realistic, practical problem: automated maintenance and basic security auditing of a remote Debian Linux server.

You are an expert Python programmer but new to Prolog. Therefore, this project is deliberately designed as a **scaffolded learning experience**. You will start with the simplest Prolog concepts (facts and queries) and progressively incorporate more powerful features (rules, recursion, list processing, negation, external process control, and meta-level reasoning) while building a complete, usable tool.

The hybrid architecture (Prolog for policy/logic + Python for systems plumbing) mirrors real-world use of logic programming: Prolog excels at *what* should happen and *why*; Python (or shell) handles *how* to talk to SSH, parse raw output, and perform side-effecting operations safely.

### 2. Learning Objectives

By the end of this assignment you will be able to:

- Write, test, and debug SWI-Prolog programs using facts, rules, variables, unification, and backtracking.
- Use recursion and list processing to traverse and transform collections of system objects (files, kernels, log entries, processes).
- Encode domain policies declaratively (e.g., “a kernel package is safe to remove if …”) as Prolog rules.
- Interface Prolog with external processes and Python scripts using `library(process)` and structured data exchange (JSON or Prolog terms).
- Apply the concept of **negation as failure** and the **cut** (!) appropriately for safety-critical decisions.
- Design modular, readable Prolog code with clear separation of concerns and excellent documentation that explains the Prolog concepts being used.
- Evaluate when a task is better expressed declaratively versus imperatively.

### 3. Problem Statement (What the Tool Must Do)

You will build a command-line tool, invoked locally on your Debian development machine, that connects via SSH to a remote Debian target and performs the following five major functions in sequence:

1. **Temporary File Cleanup**  
   Walk common temporary locations (`/tmp`, `/var/tmp`, user caches, `/var/cache/apt/archives` when safe) and remove files and directories that meet age or size criteria. Safely handle permissions and report space reclaimed.

2. This requirement deleted as it was impractical.

3. **Old Kernel Package Removal**  
   Determine the currently running kernel (`uname -r`). Identify all other installed `linux-image-*` packages. Remove only those that are provably safe to remove (never the running kernel; optionally keep the immediately previous kernel for boot safety). Update the bootloader if necessary.

4. **APT Maintenance**  
   Detect whether `autoremove` or `autoclean` would remove packages or free space. When appropriate, execute `apt autoremove --purge` and `apt autoclean` (or their dry-run equivalents). Report packages removed and space freed.

5. **Basic Compromise / Intrusion Detection Scan**  
   Perform a lightweight host-based scan looking for common indicators of compromise. At minimum implement five distinct checks using declarative Prolog rules:
   - Unusual or unexpected listening network ports/services.
   - brute-force login attempts visible in `/var/log/auth.log` or `journalctl`.
   - Recently modified critical system binaries or configuration files (`/bin`, `/sbin`, `/etc/passwd`, `/etc/shadow`, `/etc/sudoers`, etc.).
   - Suspicious processes (unknown binaries, root-owned processes in unusual locations, hidden processes detectable via `/proc` vs `ps`).
   - Unauthorized changes to user accounts or SSH authorized_keys.

   Each finding must be classified by severity (Low / Medium / High) with evidence and a recommended manual follow-up action. The tool must **never** attempt automatic remediation of high-severity findings.

**Safety & Usability Requirements (Mandatory)**
- A `--dry-run` (or `-n`) flag must exist that shows exactly what *would* be done without making any changes.
- High-impact actions (kernel removal, mass temp deletion) must either prompt for confirmation or be skipped in non-interactive mode unless `--yes` / `--force` is supplied.
- All actions must be logged with timestamps to both stdout and a local report file.
- The tool must fail gracefully on SSH connection errors, permission problems, or unexpected command output.

### 4. Technical Constraints & Architecture

**Primary Implementation Language:** SWI-Prolog (your installed `swipl`).

**Allowed Supporting Technology:** Python 3 (recommended) for SSH transport, remote command execution, output parsing, and any complex string/file handling that would be painful in pure Prolog.

**Integration Pattern (Strongly Recommended):**
- Prolog remains the “brain”: it decides *what* to do, encodes all policy rules, performs reasoning, and generates the final report.
- Python helper scripts (invoked via `process_create/3` or `shell/2`) act as “hands”: they open the SSH connection (use `paramiko`, `fabric`, or the system `ssh` binary + key), run commands, capture stdout/stderr, and return structured data (JSON is easiest; Prolog terms are also acceptable).
- Data flow example:
  1. Prolog calls Python with a request: “collect kernel information”.
  2. Python runs `ssh user@host "uname -r && dpkg -l | grep linux-image"`.
  3. Python parses the output into a JSON array or Prolog fact list.
  4. Prolog receives the data, asserts it as facts, and runs its `safe_to_remove_kernel/2` rules.

**Project Structure (Expected)**
```
debian-maintenance-prolog/
├── src/
│   ├── main.pl
│   ├── temp_cleanup.pl
│   ├── log_manager.pl
│   ├── kernel_cleaner.pl
│   ├── apt_maintainer.pl
│   ├── security_scanner.pl
│   ├── report_generator.pl
│   └── ssh_bridge.pl          % or python calls here
├── python/
│   ├── remote_executor.py
│   ├── parsers.py
│   └── requirements.txt
├── config/
│   └── default_policy.pl      % thresholds, whitelists, etc.
├── tests/
│   └── ...
├── README.md
├── reflection.md              % short write-up on Prolog concepts learned
└── Makefile or just usage instructions
```

**Prohibited or Discouraged**
- Do not hard-code credentials or rely on password authentication in production runs (key-based SSH is required).
- Avoid heavy external Prolog libraries beyond the standard distribution unless you clear it with the instructor first.
- Do not perform destructive operations on the remote system without a working dry-run path.

### 5. Functional Requirements (FR)

| ID     | Requirement                                                                 | Priority |
|--------|-----------------------------------------------------------------------------|----------|
| FR-01  | Accept CLI arguments or config file: `--host`, `--user`, `--key`, `--dry-run`, `--verbose`, `--policy` | Must     |
| FR-02  | Establish SSH connection (key-based) and handle authentication / network errors with clear messages | Must     |
| FR-03  | Collect and decide on temporary files to remove using age/size/policy rules written in Prolog | Must     |
| FR-04  | Identify “out of control” logs in `/var/log`, decide truncation strategy, and execute safely | Optional     |
| FR-05  | Determine running kernel, compute safe-to-remove kernel list using declarative rules, never remove running kernel | Must     |
| FR-06  | Detect pending `autoremove` / `autoclean` actions and execute when beneficial | Must     |
| FR-07  | Implement ≥5 distinct security checks as separate Prolog predicates/rules; classify severity | Must     |
| FR-08  | Produce timestamped report (text + optional Markdown/HTML) summarizing actions, space saved, and findings | Must     |
| FR-09  | Support full dry-run mode that prints the exact plan without side effects | Must     |
| FR-10  | Code must be modular; each major function lives in its own `.pl` module with documented predicates | Must     |
| FR-11  | All Prolog code must contain teaching comments explaining the Prolog concept being demonstrated (e.g., “% This rule uses recursion over a list of kernels”) | Must     |

### 6. Non-Functional Requirements (NFR)

- **NFR-01 Safety:** The tool must never delete the running kernel or render the remote system unbootable. This is non-negotiable.
- **NFR-02 Correctness:** Decisions (what is safe to delete, what is suspicious) must be encoded as verifiable Prolog rules, not hidden inside Python string manipulation.
- **NFR-03 Readability & Learnability:** Another student (or future you) should be able to read any predicate and understand both *what* it does and *which Prolog features* it employs.
- **NFR-04 Performance:** A complete run on a typical server should finish in under 5 minutes.
- **NFR-05 Documentation:** Excellent `README.md` + inline comments + a short `reflection.md` describing the Prolog concepts that were most/least intuitive.

### 7. Assumptions

- You have (or can create) an SSH key pair and the public key is already installed on the target Debian server.
- The SSH user can run `sudo` without a password for the required maintenance commands (or the tool will use `sudo` explicitly where needed).
- The target runs a recent Debian release (Debian 11/12 or derivative) with standard tools (`dpkg`, `apt`, `uname`, `journalctl` or `logrotate`, etc.).
- You may first prototype many components locally on your own machine (bypassing SSH) and later add the remote layer.
- Python 3 is available on your development machine; a minimal Python installation on the target is acceptable but not required if you drive everything through shell commands over SSH.

### 8. Deliverables

1. A private git repository (or a single `.zip` / `.tar.gz`) containing all source, Python helpers, configuration, and documentation.
2. A `README.md` that includes:
   - Exact commands to set up the environment (`pip install -r …`, `swipl` version, etc.).
   - Example invocation and expected sample output (both normal and dry-run).
   - A short architecture diagram (ASCII art or image) showing data flow between Prolog and Python.
3. A `reflection.md` (1–2 pages) answering:
   - Which Prolog concepts felt most natural for encoding maintenance policies?
   - Where did you find yourself fighting the language, and how did you resolve it?
   - How did the hybrid Prolog + Python approach compare to writing everything in Python?
4. The code itself must run on the instructor’s machine with only the documented setup steps.

### 9. Development Roadmap (How We Will Build It Together)

We will develop the project iteratively. Each phase introduces new Prolog concepts:

- **Phase 0 (Setup)**: Project skeleton, VSCode + SWI-Prolog configuration, first `main.pl` that prints “Hello, Debian!”.
- **Phase 1 (Facts & Queries)**: Model a fake system state with facts (`kernel('5.10.0-8-amd64').`, `temp_file('/tmp/foo', 1048576, 86400).`). Write simple queries and rules.
- **Phase 2 (Rules & Recursion)**: Implement `safe_to_remove_kernel/2`, list processing to walk temp files or log directories.
- **Phase 3 (External Processes)**: Learn `process_create/3`, `shell/2`, capture output. First local dry-run commands.
- **Phase 4 (Python Bridge)**: Build the SSH + data collection layer. Python returns JSON → Prolog parses it into facts.
- **Phase 5 (Full Modules)**: Implement all five functional areas as separate, well-documented modules.
- **Phase 6 (Security Rules & Reporting)**: Encode the five+ security checks declaratively. Build the report generator.
- **Phase 7 (Polish & Safety)**: Dry-run mode, confirmation prompts, error handling, extensive testing on a real (or VM) target.

At each phase I will provide targeted explanations, small exercises, and code reviews focused on the Prolog concepts you are using.

### 10. Getting Started – Your First Steps

1. Create the directory structure above.
2. Install any needed Python packages locally (`paramiko` or `fabric` are good choices).
3. Write a trivial `main.pl` that consults the other modules and prints a banner.
4. Test that you can run `swipl -s main.pl` successfully.

**Stop here and message me** when you have the skeleton and have read this entire specification. We will then begin Phase 1 together: representing system state as Prolog facts and writing your first decision rules.

You now have a complete, college-level functional specification. Everything we do from this point forward will be traceable back to one or more requirements in this document.

Questions about any requirement? Ambiguities you want clarified? Ready to create the first file? Let’s go!

---
*End of Specification*