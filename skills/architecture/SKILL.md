---
name: architecture
description: Lock system architecture for a capability or epic — modules, schemas, public contracts, and proposed slices.
disable-model-invocation: true
---

# Architecture

Lock how services, modules, endpoints, schemas, and stores talk to each other. Concrete at system boundaries, schematic inside. Types, call stacks, and file layout belong to `/program-design`.

## Core contract

- One **capability or epic** — work that will become multiple tickets, or one ticket that still needs new seams.
- The spec (if any) is the behavioural source of truth. This document is the recommended **system shape**.
- Inspect the repository. Prefer evidence over generic best practices.
- Read-only: inspect code, docs, tests, and history; do not modify production code.
- Stop after the architecture unless the user asks to continue.

Do **not** include: per-function signatures, call stacks, file-change maps, implementation sequences, or pattern dumps with existing/proposed bodies. Those are `/program-design`.

Do **not** restate the spec. Link or summarise; `/to-spec` owns product narrative.

## When to use / skip

```text
wayfinder → grill-with-docs → /to-spec
                 ↓
           /architecture     # this skill — new seams / multi-ticket
                 ↓
           /program-design   # code shape, when taste matters
                 ↓
           /to-tickets → /implement
```

| Situation | Skill |
|---|---|
| Idea or trade-offs still open | `/grilling` or `/grill-with-docs` first |
| External API/vendor semantics unclear | `/research` first |
| Module interface is the unknown | `/design-an-interface`, fold the result in |
| State model or UI feel uncertain | `/prototype` first |
| New seams, naming, or multi-ticket shape | **`/architecture`** |
| Architecture is obvious; code taste is not | Skip to `/program-design` |
| Obvious single-ticket, existing patterns | Skip to `/implement` |

## Steps

### 1. Establish the capability

Read the spec, conversation, ADRs, domain glossary (`CONTEXT.md`), and project instructions.

Ready when `/to-tickets` could slice this into tracer bullets. If the input is already a small ticket on an established pattern, recommend skipping this skill.

Record outcome, in-scope behaviour, non-goals, and constraints. Recommend defaults for non-blocking ambiguity. Stop for the user only when a decision changes behaviour, public APIs, data ownership, security, persistence, compatibility, system boundaries, dependencies, or scope.

This step is complete when outcome, non-goals, and blocking ambiguity are explicit.

### 2. Inspect the repository

Trace the current path through entry, domain logic, persistence, integrations, and tests. Note existing modules and conventions to reuse. Conflicting patterns: pick one, with evidence.

This step is complete when every proposed seam has an existing counterpart or is named as new and justified.

### 3. Design the end state

Show **before/after** at module and system boundaries (`mermaid` flowchart or sequence). Not class-level.

Define coarse structure only:

- Packages, modules, or top-level folders — not every file.
- Public contracts: endpoints, schemas, events, provider ids.
- Runtime flow from entry to observable result, at those boundaries.

When integrating external systems, add a short **Verified basis** citing official docs. Use `/research` for the long form; distill here.

Prefer, in order:

1. Existing code over new code.
2. Local code over a shared abstraction.
3. Established repository patterns over new patterns.
4. Explicit code over generic frameworks.
5. Narrow MVP surface over speculative API roadmaps.
6. One clear execution path over interchangeable layers.

New interfaces, factories, adapters, registries, or shared utilities require a current problem with multiple immediate call sites.

This step is complete when a reviewer can see the proposed system shape and how work flows through it.

### 4. Propose tracer-bullet slices

Recommend how `/to-tickets` should break the capability. For each slice:

- **Title**
- **Delivers** — end-to-end behaviour when this slice merges
- **Blocked by** — other slices, or `None`
- **Architecture anchor** — sections or contracts this slice implements

Each slice must be independently demoable or verifiable. Merge slices that only make sense together. Do not attach file lists or test commands.

This step is complete when the breakdown covers the capability and follows tracer-bullet rules.

### 5. Resolve architecture questions

Record material decisions:

- **Question**
- **Chosen:** recommendation and rationale
- **Options not chosen:** and why

Grill before writing when decisions are still unsettled. Include migration, security, performance, observability, and rollback only when the change creates them.

This step is complete when no blocking decision remains implicit.

### 6. Write the document

Capture git metadata for the frontmatter (`branch`, `sha`).

Write to the repository's established work-artifact location. If none exists, use `docs/agents/architecture/<short-slug>.md`.

Follow `references/architecture-template.md`. Before handing off, verify:

- One capability or epic, not a file tweak.
- Before/after architecture is visible at module boundaries.
- Proposed slices are tracer bullets with blocking edges.
- Public contracts only — no call stacks, function bodies, or file maps.
- No blocking decision remains implicit.

## Shortened form

For a bounded capability that is one tracer-bullet ticket but still needs architectural approval:

- Frontmatter, summary, current / desired state, not doing
- One architecture diagram
- Public contracts
- Resolved decisions (if any)
- Approval gate

## Handoff

Report:

1. Path to the architecture document.
2. Concise summary of the recommended system shape.
3. Proposed slice count and frontier slice.
4. Blocking decisions, or `None`.
5. Confirmation that production code was not modified.
6. Next step:

```text
/program-design using <architecture-path>
```

If code shape is obvious and the user will slice next:

```text
/to-tickets using <architecture-path>
```
