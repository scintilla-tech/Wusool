---
description: Run an approved implementation phase (e.g. /phase 1) end-to-end following the WASL engineering contract, including reviews and a truthful phase report.
agent: build
---

You are executing the WASL `phase` workflow. $ARGUMENTS is the phase number (e.g. `/phase 1`).

Follow these steps exactly and STOP at the end. Do NOT continue to another phase.

1. Read `AGENTS.md`.
2. Read `docs/phases/PHASE_$ARGUMENTS.md`.
3. Inspect the existing repository state (do not overwrite useful existing work blindly).
4. Write a short implementation plan.
5. Implement ONLY the approved current phase (`$ARGUMENTS`). Do not implement future-phase features beyond approved scaffolding.
6. Run the relevant formatter / typecheck / lint / tests / schema validation commands. Actually execute them; never claim they passed otherwise.
7. Invoke the `reviewer` subagent on the current changes.
8. If this phase touches database, tenant isolation, auth, authorization, sensitive data, sockets, storage, or security, invoke the `security-reviewer` subagent.
9. Review the findings from both subagents.
10. Fix all valid CRITICAL, HIGH, and MEDIUM findings.
11. Rerun validation/tests.
12. Invoke `reviewer` again for final verification.
13. If security-sensitive changes were made, perform final `security-reviewer` verification too.
14. Produce a truthful phase report with actual commands and results (see the report checklist in the phase spec).
15. STOP.

Rules:
- The command MUST NEVER automatically continue to another phase. After the report, wait for explicit user approval.
- Never claim a command/test/migration passed unless actually executed.
- Never conceal failures. Report exact blockers (e.g. missing PostgreSQL) honestly.
- Do not weaken tests to make them pass.
- Do not remove security controls to fix a test.
- Do not silently change architecture. If architecture must change, STOP and report the proposed deviation before implementing it.
