# ASHEN REALM — IMPLEMENTATION PROMPT RULES

## PURPOSE

Defines how an approved design
becomes a technical prompt
for Claude Code / Codex.

---

## FLOW

IDEA
→ DESIGN
→ APPROVED
→ TECHNICAL PROMPT
→ AUDIT
→ IMPLEMENT
→ TEST
→ PLAYTEST
→ REPORT.

---

## AUDIT FIRST

Every major implementation prompt
must begin by auditing:

- current scripts;
- Resources;
- scenes;
- tests;
- save;
- dependencies;
- runtime flow.

Repository is source of truth.

---

## REQUIRED PROMPT STRUCTURE

TITLE

PROJECT

CURRENT CONFIRMED STATE

APPROVED DESIGN

OBJECTIVE

NON-GOALS

AUDIT FIRST

ARCHITECTURAL RULES

PHASES

SAVE IMPACT

UI/UX

MOBILE

PERFORMANCE

TESTS

REGRESSION

PASS CRITERIA

FINAL REPORT

DO NOT.

---

## DO NOT INVENT

Never invent:

file paths
classes
functions
Resources
tests
SAVE_VERSION
renderer.

Unknown:
AUDIT.

---

## NO REWRITE DEFAULT

Prefer:

extend/refactor incrementally.

Do not create:

CombatV2
SaveManager2
InventoryNew
Board3DLogic

without strong evidence.

---

## SAVE

If feature is not persistent:

do not bump SAVE_VERSION.

If persistent:

define:

- fields;
- defaults;
- migration;
- backwards compatibility;
- tests.

---

## TEST SAFETY

Runtime tests must use:

SaveManager.use_isolated_test_profile()

or the current centralized equivalent.

Never use real player save
during automated tests.

---

## ART

Build hooks and fallbacks
before mass final-art production.

Mark:

FINAL ART PENDING

when appropriate.

---

## 3D

Use technical prototypes first.

Placeholder geometry is acceptable
for architecture validation.

Validate mobile performance early.

---

## BUGS

REPRODUCE
→ ROOT CAUSE
→ MINIMAL FIX
→ REGRESSION TEST.

---

## BALANCE

Numbers must be:

INITIAL TUNING

until simulation + human playtest
support them.

---

## FINAL REPORT

Require:

STATUS

FEATURE PASS/PARTIAL/FAIL

SAVE_VERSION

DEBUG STATUS

FILES MODIFIED

FILES CREATED

TESTS

REGRESSIONS

WARNINGS

RISKS

HUMAN PLAYTEST STATUS

NEXT RECOMMENDED STAGE.

---

## GIT

Use branches and small commits
when source control is operational.

Never push secrets.

Do not commit/push
unless the user explicitly requests
or the implementation prompt permits it.