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

# Prolog Style Checklist

This project uses SWI-Prolog, so the style below follows common Prolog conventions used in the community and in SWI-Prolog itself.

## Naming
- Use lowercase predicate names.
- Use underscores to separate words when needed.
- Prefer descriptive names over short abbreviations.
- Examples:
  - `collect_remote_kernels/3`
  - `sync_remote_kernels/2`
  - `running_kernel/1`

## Predicate structure
- Keep predicates small and focused on one job.
- Prefer a few simple clauses over one very complex clause.
- Split helper logic into separate predicates when it improves clarity.

## Modes and arguments
- Document argument roles with comments when helpful.
- Common conventions:
  - `+` for input
  - `-` for output
  - `?` for either input or output
- Example comment:
  - `%% collect_remote_kernels(+Host, +User, -Kernels)`

## Formatting
- Keep clauses aligned and consistently indented.
- Put each clause on its own line.
- Use blank lines between related predicates.
- Avoid overly dense one-liners when a clearer structure is available.

## Control flow
- Prefer explicit success/failure behavior.
- Use `true` for success and `fail` when a predicate should fail.
- Keep `->` / `;` structures readable and avoid deeply nested conditionals.
- When logic becomes hard to follow, split it into helper predicates.

## Comments and documentation
- Add short comments above predicates to explain intent.
- Document non-obvious behavior, especially around external commands, JSON parsing, and dynamic facts.
- Keep comments helpful and concise.

## Facts and dynamic predicates
- Use facts for simple static knowledge.
- Use dynamic predicates when state changes during execution.
- Clear the relevant dynamic facts when refreshing state.

## Error handling
- Report errors clearly with `format/2` or similar output.
- Prefer failing explicitly rather than silently succeeding after an error.
- When parsing external data, handle parse failures cleanly.

## General rule of thumb
- Write code that is easy for a reader to follow, even if it is slightly longer.
- In Prolog, clarity is usually more important than cleverness.
