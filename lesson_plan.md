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

# Lesson Plan: Building a Debian System Maintenance & Security Tool in Prolog (Hybrid Architecture)

**Course:** CS 520 – Introduction to Logic Programming  
**Project:** Debian Maintenance & Basic IDS Tool (Prolog + Python over SSH)  
**Total Estimated Time:** 15–25 hours across 7 lessons  
**Instructor:** Grok (your Prolog programming instructor)  
**Version:** 1.0 – June 21, 2026

---

## How to Use This Lesson Plan (Especially Across Multiple Chats)

Because long conversations can lose context, we will treat this lesson plan as our **shared contract and roadmap**.

**When you start a new chat:**
1. Paste the **Restart Marker** from the lesson you want to resume.
2. Optionally attach or quote the relevant section of this lesson plan.
3. I will immediately know exactly where we are, what Prolog concepts we have covered, and what code should already exist.

**Progress Tracking (recommended):**
- Keep a simple `progress.md` in your project root.
- At the end of each lesson, add one line: `Lesson 3 completed on 2026-06-22 – kernel_cleaner.pl has safe_to_remove_kernel/2 working with tests`.

**Our Contract:**
- We will **never** jump ahead of the current lesson’s Prolog concepts.
- Every lesson ends with a concrete, testable checkpoint (you can run `swipl` queries and see correct results).
- If something feels too fast or too slow, tell me and we adjust the plan together.

---

## Lesson Overview

| Lesson | Phase(s)                  | Main Prolog Concepts Introduced                  | Primary Deliverable                          | Est. Time |
|--------|---------------------------|--------------------------------------------------|----------------------------------------------|-----------|
| 1      | 0–1                       | Facts, queries, variables, unification, basic rules, `\=` | `facts.pl` + simple `removable_kernel/1` rule | 1.5–2 h  |
| 2      | 2                         | Recursion, lists, `member/2`, `append/3`, list processing | `temp_cleanup.pl` – decide which temp files to delete | 2–2.5 h  |
| 3      | 3                         | External processes (`process_create/3`, `shell/2`), capturing output, error handling | Python helper that runs local commands + Prolog calling it | 2 h      |
| 4      | 4                         | Structured data exchange (JSON ↔ Prolog), parsing, `library(http/json)` | SSH bridge: Python runs `uname -r` + `dpkg` over SSH, returns data Prolog can use | 3 h      |
| 5      | 5                         | Modularity (`:- use_module/1`), dynamic predicates or `assertz/1` for collected facts, separation of concerns | All five core modules exist (even if some are stubs) + working kernel + temp modules | 3–4 h    |
| 6      | 6                         | Negation as failure, cuts (`!`), aggregation, severity classification | `security_scanner.pl` with ≥5 declarative checks + risk scoring | 3–4 h    |
| 7      | 7                         | Report generation, configuration via facts, dry-run mode, user interaction (`read/1`) | Complete working tool with `--dry-run`, nice report, and `reflection.md` started | 3–4 h    |

**Total:** ~15–22 hours of focused work (plus thinking/reading time).

---

## Lesson 1: Project Setup & Modeling System State with Facts and Rules

**Prolog Concepts:** Facts, queries, variables, unification, rules, conjunction, negation (`\=`), basic debugging with `trace/0`.

**Learning Objectives:**
- Create a clean, modular SWI-Prolog project in VSCode.
- Represent real-world entities (kernels, temp files) as Prolog facts.
- Write your first decision rule that answers “Which kernels are safe to remove?”
- Understand how Prolog’s search/backtracking works on a tiny example.

**Pre-requisites:**
- SWI-Prolog installed and runnable from terminal.
- VSCode + recommended Prolog extension (or just use the REPL for now).
- Read sections 1–4 and the roadmap in the Functional Specification.

**Teaching Outline (what I will explain step-by-step):**
1. Why declarative modeling beats imperative data structures for policy decisions.
2. The difference between **facts** and **rules**.
3. Unification and how `running_kernel(R), K \= R` works.
4. How to load multiple files with `:- [facts, rules].` or `use_module`.
5. Using `trace.` to watch Prolog’s reasoning (invaluable for learning).

**Hands-on Exercises / Milestones:**
1. Create the full directory skeleton from the spec.
2. Write `facts.pl` containing at least:
   - One `running_kernel/1` fact.
   - Several `installed_kernel/1` facts (including the running one and older ones).
   - A few `temp_file(Path, SizeBytes, AgeSeconds)` facts.
3. Write `kernel_cleaner.pl` with the rule:
   ```prolog
   removable_kernel(K) :-
       installed_kernel(K),
       running_kernel(Running),
       K \= Running.
   ```
4. In `main.pl`, load the modules and demonstrate queries that succeed and fail.
5. Use `trace.` and step through a query so you see backtracking in action.

**Checkpoint (you must be able to do this before moving on):**
```prolog
?- removable_kernel(K).
K = '6.1.0-17-amd64' ;
K = '5.10.0-8-amd64' ;
...
```
You can explain in plain English why a particular kernel is or is not removable.

**Restart Marker (copy-paste this into a new chat):**
> "Resume Lesson 1: We have the project skeleton created. facts.pl has running_kernel/1 and installed_kernel/1 facts. We just wrote the first removable_kernel/1 rule and are learning to use trace/0."

**Estimated Time:** 90–120 minutes  
**Exit Ticket:** Add one line to your `progress.md`: `Lesson 1 complete – first declarative kernel policy working`.

---

## Lesson 2: Recursion, Lists, and Processing Collections (Temp File Cleanup)

**Prolog Concepts:** Lists, recursion (base case + recursive case), `member/2`, `append/3`, `findall/3`, `maplist/2-3`, cuts for efficiency if needed.

**Learning Objectives:**
- Walk a list of temp files and decide which ones to delete using policy rules.
- Understand the classic “head + tail” recursion pattern that Prolog programmers use constantly.
- See how `findall/3` collects solutions (very useful later for reports).

**Key Exercise:**
Implement `files_to_delete/2` (or similar) that takes a list of `temp_file/3` facts and returns only those meeting your cleanup policy (e.g., older than 1 day **AND** larger than 1 MiB, or whatever policy you choose).

You will also write a simple `reclaimed_space/2` predicate that sums the sizes.

**Checkpoint:**
You can query:
```prolog
?- files_to_delete(Files), reclaimed_space(Files, Bytes).
```
and get a list of files + total bytes that would be freed.

**Restart Marker:**
> "Resume Lesson 2: Lesson 1 facts and kernel rule are working. Now implementing list recursion for temp file policy decisions in temp_cleanup.pl."

---

## Lesson 3: Talking to the Outside World – External Processes

**Prolog Concepts:** `library(process)`, `process_create/3`, `process_wait/2`, `shell/2`, capturing stdout/stderr, handling exit codes, error handling with `catch/3`.

**Learning Objectives:**
- Stop treating Prolog as a pure logic island.
- Learn the standard, safe way to run external commands from SWI-Prolog.
- Practice turning raw text output into something Prolog can reason about.

**Exercise:**
Write a small Python or shell helper that your Prolog code calls to run `uname -r` and `echo "hello from shell"`. Capture the output inside Prolog and print it.

Then move the same pattern to a local (non-SSH) command that lists kernels with `dpkg`.

**Checkpoint:**
Prolog can run an external command, capture its output as a string or codes, and succeed or fail based on the exit status.

**Restart Marker:**
> "Resume Lesson 3: We understand recursion from Lesson 2. Now learning process_create/3 and how Prolog calls out to Python/shell safely."

---

## Lesson 4: The SSH Bridge – Structured Data Exchange

**Prolog Concepts:** Parsing (simple DCGs or split_string), `library(http/json)`, asserting dynamic facts with `assertz/1`, or passing data via arguments.

**Learning Objectives:**
- Build the critical “Python does SSH and returns JSON → Prolog turns JSON into facts or terms” pattern.
- See why this hybrid approach is powerful: Python handles networking/crypto, Prolog handles policy logic.
- Learn to keep the SSH layer thin and testable.

**Major Milestone:**
You can run a query like:
```prolog
?- collect_remote_kernels(Kernels).
```
and `Kernels` contains the real list from your actual Debian target (or a test VM).

**Restart Marker:**
> "Resume Lesson 4: Lesson 3 external process calls are working locally. Now building the SSH + JSON bridge so Prolog can see real remote system state."

---

## Lesson 5: Modularity and Scaling to All Five Core Functions

**Prolog Concepts:** Modules (`:- module/2`, `:- use_module/1`), encapsulation, when to use dynamic predicates vs. passing data, code organization for larger programs.

**Learning Objectives:**
- Refactor the growing codebase into the five modules listed in the spec (`temp_cleanup.pl`, `log_manager.pl`, `kernel_cleaner.pl`, `apt_maintainer.pl`, `security_scanner.pl`).
- Keep `main.pl` as a thin orchestrator.
- Understand the difference between **collecting data** and **making decisions**.

**Checkpoint:**
All five module files exist. At least `kernel_cleaner.pl` and `temp_cleanup.pl` have working predicates that can be called from `main.pl`. The other three can still be stubs with comments describing what they will do.

**Restart Marker:**
> "Resume Lesson 5: SSH bridge from Lesson 4 works. Now organizing code into proper modules and implementing the remaining core functions (logs, apt, security)."

---

## Lesson 6: Encoding Security Policy – Negation, Cuts, and Classification

**Prolog Concepts:** Negation as failure (`\+`), the cut (`!`) and its dangers, green vs. red cuts, aggregation (`findall` + `length` or custom folds), defining “severity levels” declaratively.

**Learning Objectives:**
- Write rules that say “this situation is suspicious **because** these conditions are **not** met”.
- Use cuts responsibly to commit to a severity once a strong indicator is found.
- Build a small “expert system” style security scanner.

**Exercise:**
Implement at least these five checks (you may add more):
1. Unexpected high ports listening.
2. Brute-force login patterns in auth.log.
3. Recently modified critical binaries (`/bin/login`, `/usr/sbin/sshd`, etc.).
4. Non-root UID 0 accounts or new users.
5. World-writable files in `/etc` or suspicious cron entries.

Each check returns a finding with severity.

**Checkpoint:**
```prolog
?- run_security_scan(Findings), member(F, Findings), F = finding(..., high, ...).
```
You can explain in English why a particular finding was classified as high/medium/low.

**Restart Marker:**
> "Resume Lesson 6: Core modules from Lesson 5 are in place. Now adding the security_scanner.pl with declarative rules using negation and severity classification."

---

## Lesson 7: Reporting, Dry-Run Mode, Polish & Reflection

**Prolog Concepts:** String formatting (`format/2`, `with_output_to/2`), configuration via facts, interactive input (`read/1`, `get_single_char/1`), generating structured output (Markdown or HTML), meta-programming if desired (`listing/1` for debugging).

**Learning Objectives:**
- Turn all the decisions the Prolog engine made into a human-readable, timestamped report.
- Implement the mandatory `--dry-run` behavior cleanly (usually by threading a `DryRun` flag or using a separate predicate).
- Add safe confirmation prompts for destructive actions.
- Write the required `reflection.md` while the experience is fresh.

**Final Deliverables for the Whole Project:**
- Working tool on a real (or VM) Debian target.
- Clean `README.md` with setup + example run.
- `reflection.md` discussing which Prolog concepts felt most natural for this domain.
- All code well-commented with teaching notes (“This recursion demonstrates head/tail pattern...”).

**Restart Marker:**
> "Resume Lesson 7 (final lesson): Security scanner is working. Now implementing reporting, dry-run mode, user confirmation, and writing the reflection."

---

## Overall Teaching Philosophy for This Project

- **Declarative first.** We only add Python when Prolog genuinely cannot (or should not) do the job.
- **Visible reasoning.** We will use `trace/0`, `listing/1`, and good `format/2` output so you can *see* why Prolog made a decision.
- **Safety above all.** The kernel removal rule and dry-run mode are non-negotiable and will be tested early.
- **Iterative refinement.** Many predicates will be rewritten in later lessons as you learn better patterns — that is normal and encouraged.

---

**Next Action**

Please read this entire lesson plan (especially the “How to Use” section and Lesson 1).

When you are ready to begin, reply with the **Restart Marker for Lesson 1** (or tell me if you want to adjust the order, pacing, or add/remove any concepts).

I have deliberately made Lesson 1 small and extremely concrete so you get a quick win and see Prolog’s declarative style in action within the first hour.

We are going to do this properly, one solid concept at a time.

Ready when you are. Just say the word and we’ll start Lesson 1.