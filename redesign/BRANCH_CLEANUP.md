# Branch cleanup (2026-10-20)

Branches that can be deleted from GitHub. Nothing here holds work that exists nowhere else.

The web session cannot delete branches: GitHub refuses with HTTP 403. Delete them from the PC session (`git push origin --delete <branch>`), or on GitHub: **Branches**, **All**, search the name, then click the trash icon.

State checked at 17:23 UTC. "Merged" means the branch tip is an ancestor of `redesign` or `wip/next-test`. Before each delete, check it again: `git fetch origin; git merge-base --is-ancestor origin/<branch> origin/wip/next-test` must exit 0, and the branch must have no new commits.

## 1. Merged, no open PR: can go now

| Branch | Merged into | Its PR | Last commit |
|---|---|---|---|
| wip/web-fixes-1 | wip/next-test | #17 closed | 2026-10-18 |
| wip/sidebar-musthaves | wip/next-test | #10 closed | 2026-10-16 |
| wip/readme-cone | redesign | #11 merged | 2026-10-19 |
| wip/fix-subtitle-lift | wip/next-test | #31 merged | 2026-10-19 |
| wip/fix-subsdelay | wip/next-test | #30 merged | 2026-10-19 |
| wip/fix-library-escape | wip/next-test | #35 merged | 2026-10-20 |
| wip/quit-watchdog | wip/next-test | #34 merged | 2026-10-20 |
| wip/fix-audio-icon | wip/next-test | #42 merged | 2026-10-20 |
| wip/fix-chapter-title | wip/next-test | #39 merged | 2026-10-20 |
| wip/fix-playlist-favorite | wip/next-test | #41 merged | 2026-10-20 |
| wip/fix-window-class | wip/next-test | #40 merged | 2026-10-20 |
| wip/cone-window-title | wip/next-test | none (title part of #36) | 2026-10-20 |

## 2. Merged, PR still open: only after its PR closes

These PRs point at `redesign`. GitHub marks them merged when `wip/next-test` goes into `redesign`; then the branch can go.

| Branch | Merged into | Its PR |
|---|---|---|
| wip/decision-67 | wip/next-test | #28 open |
| wip/eq-curves | wip/next-test | #25 open |
| wip/web-fixes-3 | wip/next-test | #20 open |
| wip/web-fixes-4 | wip/next-test | #23 open |
| wip/musthaves-2 | wip/next-test | #22 open |
| claude/zen-mendel-p1anpd | wip/next-test | #26 merged; this file's PR (into wip/next-test) is open, so the branch goes after that one is merged |

## 3. "-linux" test branches (Linux CI builds of a PR, never merged)

| Branch | Built for | When |
|---|---|---|
| wip/fix-subs-linux | #30 (merged) | now |
| wip/fix-library-escape-linux | #35 (merged) | now |
| wip/fix-quit-linux | #32 (closed) | now |
| wip/fix-audio-icon-linux | #42 (merged) | now |
| wip/fix-chapter-title-linux | #39 (merged) | now |
| wip/fix-playlist-favorite-linux | #41 (merged) | now |
| wip/fix-window-class-linux | #40 (merged) | now |
| wip/fix-visualizer-linux | #36 (open) | after #36 closes |
| wip/motion-polish-linux | #37 (open) | after #37 closes |
| wip/eq-icons-linux | #25 (open) | after #25 closes |
| wip/web-fixes-3-linux | #20 (open) | after #20 closes |
| wip/web-fixes-4-linux | #23 (open) | after #23 closes |

## 4. Not merged, not needed: can go now

| Branch | Why it is not needed |
|---|---|
| wip/fix-library | One "WIP: partial fixes" commit from an agent cut off by the session limit; never reviewed or built |
| wip/fix-panels | The same, for the Settings audio page and panels |
| wip/linux-recheck | Linux re-check build of earlier PRs (test only, no PR) |

## Not on this list

- **Protected, kept:** `redesign`, `wip/next-test`, `wip/linux-build`, `wip/ci-release`, `wip/windows-checklist`, `master`, every `wip/test-*` branch (the PC session's test branches; some are merged too), and every branch with an open PR not named above.
- **Work that exists nowhere else, kept:** `wip/verify-linux`, `wip/verify-sheets`, `wip/code-audit`, `wip/verify-harness`, `wip/beta-gate`, `wip/a839e9d9ddb97595a`.
- **Closed PRs that are not merged by ancestry, kept until StickyGonzales decides:**
  - `wip/web-fixes-2` (#19): its code is in `wip/next-test` as equivalent commits.
  - `wip/next-batch` (old base of #10): its 2 commits are in `wip/next-test` as equivalent commits.
  - `wip/fix-quit-deadlock` (#32): failed fix, see #38.
