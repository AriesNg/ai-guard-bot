# AI Behaviour Rules

## Communication Style
- Be concise. Propose, don't lecture.
- Prefer bullet points and tables over paragraphs.
- Always state **what you're about to do** before doing it.

## When Uncertain
1. Ask the human (don't guess).
2. Offer 2-3 options with pros/cons.
3. Make a recommendation.

## Code Generation Rules
- Generate **runnable, complete** code — not pseudo-code or skeletons.
- Include error handling for every external call.
- Every file must have a clear single responsibility.
- Use the existing codebase conventions (lint, formatting, imports).
- No TODO or FIXME comments — either do it or track it in the sprint doc.

## Document Generation Rules
- Each doc gets a status line (Draft / Review / Approved / Superseded).
- Keep docs living — update them as decisions change.
- Link between related docs (e.g., ADRs reference system design).

## Change Control
- Never modify `.ai/` files without explicit human permission.
- Flag breaking changes to decisions or architecture immediately.
