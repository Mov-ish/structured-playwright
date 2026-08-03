# for-claude-code — Claude Code Operations Kit

An operations kit for using Claude Code to build — and keep maintaining — **highly maintainable Playwright tests on the 4-layer architecture** from test procedures, checklists, and user stories.

- **rules** (always-loaded standards) — 4-layer responsibility boundaries, prohibited patterns, and Locator design philosophy
- **skills** (phase-specific work procedures) — environment setup / test creation / review / Locator implementation
- **gate** (machine gate) — mechanically detects prohibited patterns and structural degradation (bloat and duplication of the rules documents themselves) via exit codes

Rather than "preaching the standards in prose," `npm run gate` enforces them mechanically wherever possible. AI-generated code and human-written code pass through the same gate.

## Quick Start

1. **Copy exactly 3 things**: copy `.claude/`, `scripts/`, and `CLAUDE.md` from this directory to the root of your project (this README and the other files in the parent repository do not need to be copied)
2. Register the gate in `package.json` and install dependencies:

   ```json
   { "scripts": { "gate": "bash scripts/gate.sh" } }
   ```

   Use TypeScript **5.x** in devDependencies (the gate's AST checks assume the 5.x compiler API; see the setup guide for details). After registering, run `npm install` (without it, the gate's AST checks and tsc will falsely fail)
3. Fill in the "Project-Specific Information" section of `CLAUDE.md` (target product, UI library, authentication method, HTML characteristics)
4. Run `/e2e-bootstrap` in Claude Code to generate the 4-layer skeleton (Fixture / BaseAction / constants / uniqueId / tsconfig). The same skill also handles converting an existing Playwright project to the 4-layer architecture. Because the gate assumes `src/` exists, **this step comes before the first gate run** (the bootstrap's Definition of Done includes "gate exits 0" — bringing the project to a state where the gate passes is the bootstrap's responsibility)
5. Run `npm run gate` — on the first run you will be guided to "freeze the Rules total-volume baseline"; **a human** creates `.claude/rules-baseline` as instructed (do not let an AI agent create it — see the guide for why)

From then on, when creating tests, hand over the **source material** (test procedure / checklist / acceptance criteria / user story) and run `/e2e-test-create`; for reviews use `/e2e-review`; when unsure about Locators use `/e2e-locator`.

## Structure

| Path | Role |
|------|------|
| `.claude/rules/` | 4 always-loaded standards (architecture / prohibited patterns / Locator philosophy / constants & security) |
| `.claude/skills/` | 4 phase-specific skills + conditional sub-files (details read only when the situation calls for them) |
| `.claude/settings.json` | Stop hook (automatically runs the gate at the end of a turn and has the AI self-correct any violations) |
| `scripts/gate.sh` | The machine gate itself (❌ = exit 1 / ⚠️ = requires visual inspection) |
| `scripts/check-verify-wait.js` | AST detection of fixed waits inside verify methods (called by the gate) |
| `CLAUDE.md` | Entry point for phase identification + fill-in section for project-specific information |

## Detailed Guide

For prerequisites, how the Stop hook works, what each gate check protects, baseline operations, a **walkthrough from a sample test procedure to a finished test**, and customization guidance, see the setup guide:

**→ [docs/en/claude-code-guide.md](../docs/en/claude-code-guide.md)**
