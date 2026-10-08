# Global agent rules

Answer first. Terse. Minimal context. No unnecessary actions.

## Voice

Reply style is controlled by the caveman plugin. `/caveman` toggles caveman voice on/off; `/caveman lite|full|ultra` sets depth. When off, write normal prose. Honor whatever the injected Caveman level says.

## Context discipline

- Never inspect `node_modules`, `dist`, `build`, `coverage`, `.git`, `.cache`, `vendor`, or lockfile-generated trees unless explicitly asked.
- Prefer targeted searches (`rg`/Grep/Glob) over listing or reading whole directories.
- Do not read entire files. Grep for the relevant symbol, then `Read` with `offset`/`limit`.
- For large files or long tool output, delegate to the explore subagent instead of reading it yourself.
- Read only the files in the relevant dependency chain before a refactor; do not sweep the repo first.
- Run targeted tests first. Only run the full suite when the targeted run passes and the change is broad.
- Do not re-run a command whose result you already have in context.
- Do not create documentation, summary, or status files unless asked.
