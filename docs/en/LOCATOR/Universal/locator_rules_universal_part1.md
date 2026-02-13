# LOCATOR_RULES_UNIVERSAL_FULL_part1.md

## 0. Purpose of This Document
The success of E2E testing with Playwright depends on Locator design quality.
Locators are the core element that determines maintainability, execution stability, and compatibility with AI auto-generation across the entire test suite.

This document systematizes universal Locator design principles that are "applicable to any product."

---

## 1. Fundamental Understanding of Locators: Conditional Expressions for Future UI

Playwright's Locator is not merely "element retrieval" but behaves as a "condition set that will be satisfied by UI appearing in the future."

### 1.1 Lazy Evaluation
Locators do not search the DOM at generation time but search during operation execution, waiting until conditions are satisfied.

### 1.2 Auto-Wait
During operations like clicks and inputs, automatically waits for visibility, enablement, and stabilization.

### 1.3 Auto-Retry
Even with unstable UI, Playwright internally repeats searches, making E2E tests resilient.

---

## 2. Locator Design Philosophy: Capture "Meaning" Not Structure
HTML structure changes, but UI meaning (role, name, label, text) changes less frequently.

Playwright's recommended strategy is to design Locators based on meaning rather than traversing the DOM.

---

**Last Updated**: 2026-02-02
**Maintainer**: Ray Ishida
