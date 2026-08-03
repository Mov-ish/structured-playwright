# Minimal Fixture Template (Canonical Source for §3)

> **Canonical source = this file** (extracted from e2e-bootstrap §3). Read when creating a new Fixture, converting to the 4-layer architecture, or registering a new Action in the Fixture.

```typescript
import { test as base } from '@playwright/test';
import { StepCounter } from '../actions/StepCounter';
import { LoginAction } from '../actions/LoginAction';

// === Action list ===
// Implemented:
//   loginAction  : Login
//
// TODO (not yet implemented):
//   xxxAction    : Description (target TCs or purpose)
type AppFixtures = { loginAction: LoginAction; };

// Worker-scoped Fixture — stepCounter auto-resets at describe boundaries, so a single
// instance is shared across the whole worker (with test scope, numbering would not continue across test() boundaries)
type WorkerFixtures = { stepCounter: StepCounter; };

export const test = base.extend<AppFixtures, WorkerFixtures>({
  stepCounter: [
    async ({}, use) => { await use(new StepCounter()); },
    { scope: 'worker' },
  ],
  loginAction: async ({ page, stepCounter }, use) => { await use(new LoginAction(page, stepCounter)); },
});
export { expect } from '@playwright/test';
```

**TODO management rule**: when a new Action is implemented, promote it from TODO → Implemented. Add unimplemented plans to TODO. See `rules/architecture.md` for details.

---


## Action Catalog Format

Maintain it immediately before the `AppFixtures` type definition in fixture.ts (the canonical source for the conventions and rules is `architecture.md`, "Action catalog conventions for fixture.ts"):

```typescript
// === Action catalog ===
//
// ■ loginAction (LoginAction)
//   - execute(url, email, password)    Login
//
// ■ logoutAction (LogoutAction)
//   - execute()                        Logout
//
// ■ navigationAction (NavigationAction)
//   - selectWorkspace(wsName)          Switch workspace
//   - switchRole(role)                 Switch role
//
// ■ resourceAction (ResourceAction)
//   - createResource(type, name)       Create a new resource
//   - editResource(name, opts)         Edit a resource
//   - publishResource()                Publish a resource
//   - isPublished() → boolean          Check "Published" status
//   ...
//
// === TODO (not yet implemented) ===
//   yyyAction  : Description (target test case numbers)
//
type AppFixtures = { ... };
```
