# CLAUDE.md - E2E Test Project (4-Layer Architecture)

**Playwright + TypeScript / 4-Layer Architecture**

## Phase Identification (Required)

Before starting work, identify the phase and read the corresponding Skill first.
The rules in `.claude/rules/` are always in effect. Skills live in `.claude/skills/`.

### Test Creation
Adding tests / Implementing Actions and Page Objects / Generating tests from test procedures, checklists, or user stories
→ `/e2e-test-create` + `/e2e-locator` as needed

### Review
Code review / PR checks / Quality checks
→ `/e2e-review` + `/e2e-locator` as needed

### Environment Setup
New setup / Converting an existing project to the 4-layer architecture / Introducing Playwright
→ `/e2e-bootstrap`

**If the phase is unclear → ask the human for confirmation.**

## Project-Specific Information (please edit)

```
Target product: (fill in here)
UI library: (e.g., Ant Design / MUI / in-house)
Authentication method: (e.g., Auth0 external auth / custom login / SSO)
HTML characteristics: (e.g., no data-testid / missing aria-label / well maintained)
```

## Development Commands

```bash
npm test                    # Run all tests
npm run test:headed         # Browser display mode
npm run test:debug          # Debug mode
```
