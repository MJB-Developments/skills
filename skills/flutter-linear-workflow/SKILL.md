---
name: flutter-linear-workflow
description: >
  Use when starting any feature, milestone, bug fix, or task in a Flutter project (especially
  jax_flutter), or when transitioning between planning and building. This is the source of truth
  for the end-to-end SOP: Linear project setup, 4-phase milestone breakdown
  (Data → Bloc → UI components → Screens), branch strategy, subagent dispatch, review gates,
  and conversation compaction. Always invoke when the user says "plan X", "let's build X",
  "add a feature", "start working on Y", or asks to move from planning to coding. Defers to the
  `flutter-arch` skill for all Flutter/Dart code-level standards.
---

# Flutter + Linear Workflow

End-to-end SOP for shipping features in Flutter projects (e.g., `jax_flutter`). Two modes:

- **Planning** — read-only. Output is Linear projects, milestones, and issues. No branches, no commits.
- **Building** — writes code. Branches, commits, PRs, reviews, Linear updates.

This skill orchestrates *when* and *how* code happens. It does not define how the code looks.
For Flutter/Dart code-level standards — file organization, BLoC patterns, naming, widget
composition, testing — defer to **`flutter-arch`**. Whenever this skill calls for a final plan
check or a code review, route the substance through `flutter-arch`.

## Hard rules (both modes)

- **Linear → `linear-cli` only.** The Linear MCP is removed. Use `JX_LINEAR_API_KEY`; never echo it.
- **No human-level actions in plans.** Plans contain only agent-executable work — no "smoke test",
  "QA on device", "run the app". A plan with human steps stalls when the human isn't watching,
  and the agent ends up guessing whether the step happened. Surface human asks; don't own them.
- **Update Linear in real time, not in batches.** Move tickets through their states (Backlog →
  In Progress → In Review → Done) the moment the state changes. Batched updates lie about
  what's happening, so Linear stops being trustworthy as a status source.
- **Attach Linear identifiers** to every commit message and PR description, so any commit can
  be walked back to its rationale.
- **Implementation runs in subagents.** Coordinate from the main context; implement in subagents
  via `superpowers:dispatching-parallel-agents` or `superpowers:subagent-driven-development`.
  Keeps the orchestrator's context clean across many tickets.
- **Compact the conversation:**
  1. After the plan is approved, before building starts. (Planning research bloats context.)
  2. After every milestone is merged. (File diffs and review chatter pile up fast.)

---

## Mode 1 — Planning (read-only)

Repo state must not change. Don't create a branch, commit, or run code-modifying commands.

### Step 1 — Capture intent
- Open-ended request: `superpowers:brainstorming`
- Multi-step work with a clear spec: `superpowers:writing-plans`

### Step 2 — Create a Linear project
- **Team:** Engineering · **Label:** `frontend`
- **Description:** concise summary
- **Project overview:** post the full plan output

### Step 3 — Decompose into milestones

For frontend work, milestones map to the four phases below. **Skip phases that genuinely don't
apply** — empty milestones are noise.

| Phase | Milestone branch | Scope |
|-------|-----------------|-------|
| 1. Data Integration | `feature-data/<slug>` | Entities, freezed classes, API endpoints, repositories, helpers, models |
| 2. Business Logic | `feature-bloc/<slug>` | Blocs/Cubits, state classes, business logic, error handling |
| 3. UI Components | `feature-ui/<slug>` | Standalone widgets. **Audit existing components first; reuse aggressively.** |
| 4. Screens | `feature-screens/<slug>` | Top-level screens, navigation wiring, end-to-end integration |

For non-feature work (refactors, infra, bug sweeps), use whatever breakdown actually fits — or none.

### Step 4 — Create Linear issues
- One issue per agent-executable task, under the right milestone
- Apply the `frontend` label
- Use Linear's full toolkit where it adds value: priorities, estimates, parent/sub-issues,
  blocking relationships, assignees, cycles
- Acceptance criteria must be **agent-verifiable** — no manual QA bullets

### Step 5 — Final plan review against `flutter-arch`
Walk the plan against `flutter-arch`. Confirm feature-based organization, BLoC patterns,
file-size limits, naming, and testing approach all line up. Catching architecture mismatches
now saves an entire milestone of rework later.

### Step 6 — Approve, then compact
Surface the project + milestone + issue tree. **Do not begin coding until approval is confirmed.**
After approval, compact before switching modes.

---

## Mode 2 — Building

Each project gets a feature branch; each milestone gets a sub-branch; each issue gets its
Linear-provided branch. Hierarchy:

```
master
└── feature/<slug>
    ├── feature-data/<slug>
    │   ├── <linear-issue-branch-1>   → /gsd-code-review → PR → feature-data/<slug>
    │   └── <linear-issue-branch-2>   → /gsd-code-review → PR → feature-data/<slug>
    │   ↓ /gsd-code-review at milestone close → PR → feature/<slug>
    ├── feature-bloc/<slug>           same pattern
    ├── feature-ui/<slug>             same pattern
    └── feature-screens/<slug>        same pattern
    ↓ PR → master
```

### Step 1 — Compile context
Read the Linear project, milestones, and issues with `linear-cli`. Re-load `flutter-arch`.
Confirm the plan in conversation before cutting any branch.

### Step 2 — Cut the project feature branch
**On the first ticket of a project, regardless of the current branch**, cut a fresh branch off
`master`:

```
feature/<project-slug>
```

Use the project slug from Linear. Do not continue on whatever branch you happen to be on —
that's the most common way work ends up in the wrong place.

### Step 3 — Cut the milestone branch
For each milestone, branch off the project feature branch using `feature-<phase>/<slug>` from
the table above. **Work one milestone at a time.** Concurrent milestone branches couple their
diffs and break clean revert if one needs to back out.

### Step 4 — For each issue in the milestone
1. Cut the issue branch off the milestone branch using the **Linear-provided branch name** —
   copy verbatim. Do not invent names.
2. Move the ticket to **In Progress**.
3. Dispatch a subagent (`superpowers:dispatching-parallel-agents` or
   `superpowers:subagent-driven-development`) to implement, following `flutter-arch`.
   Independent tickets in the same milestone can run in parallel if they don't touch the same files.
4. Run `/gsd-code-review` on the ticket's diff.
5. Address findings (or dispatch a follow-up subagent).
6. Open a PR from the issue branch into the milestone branch; reference the Linear issue.
7. Merge after review passes; move the ticket to **Done**.

### Step 5 — Close out the milestone
1. Run `/gsd-code-review` on the full milestone diff (milestone branch vs project feature branch).
2. Address findings.
3. Open a PR from the milestone branch into the project feature branch.
4. Merge.
5. **Compact the conversation** before the next milestone.

### Step 6 — Close out the project
Once all milestones are merged into the project feature branch, open a PR from `feature/<slug>`
into `master`. Run `/gsd-code-review` if anything cross-milestone needs another look. Merge
after approval.

### Run autonomously
After plan approval and project branch creation, run per `superpowers:executing-plans`. Stop
and surface only when:

1. A ticket's acceptance criteria are ambiguous or contradict the plan.
2. `/gsd-code-review` flags a non-trivial issue you can't auto-resolve.
3. You hit a true blocker (failing build the agent can't fix, missing credential, etc.).

Don't pause for confirmation between routine steps — next ticket, next milestone, opening a
PR. Keep moving.

---

## When this skill does **not** apply

- Trivial one-shot edits (typo fixes, dependency bumps) — handle directly without Linear ceremony
- Backend / non-Flutter work — the 4-phase breakdown assumes a Flutter frontend
- Pure investigative or exploratory questions — no code is shipping

For everything else, this is the workflow.
