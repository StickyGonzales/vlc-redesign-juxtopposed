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

## Done (PC session, 2026-10-25)

Deleted from GitHub after a recheck (merged ones still ancestors of `wip/next-test`, none with commits after 2026-10-20, none the head of an open PR): sections 1, 2 (their PRs #20 #22 #23 #25 #28 #26 / #43 are merged), 3 (all but the two below) and 4, plus `wip/web-fixes-2`, `wip/next-batch` and `wip/fix-quit-deadlock` (StickyGonzales, 2026-10-25). Kept: `wip/fix-visualizer-linux` (#36 open) and `wip/motion-polish-linux` (#37 open). To restore one: `git push origin <sha>:refs/heads/<branch>`.

| Branch | Tip |
|---|---|
| wip/web-fixes-1 | 2576443dd7d2a5983c3d23d439a7b3117358a0a4 |
| wip/sidebar-musthaves | 9aa8eb6db1f7d8f696a98b4f42cbffeb5a788692 |
| wip/readme-cone | 1cba15855043698239ce3b67b9c8dec4382a9899 |
| wip/fix-subtitle-lift | 86ed06221297cbeba326569bb211cf5cb3a5d08b |
| wip/fix-subsdelay | 868f0069f174ef4ec9d6df48736651a38546e82b |
| wip/fix-library-escape | b5db1d244e3e882056f0587d93f4bcd370902c64 |
| wip/quit-watchdog | 6ed2a9050fd92469010c6d8f44450d2ee670b99e |
| wip/fix-audio-icon | d5dfd20726ed8fb8cb5fef0ea5c852385c5c365f |
| wip/fix-chapter-title | f8b86c661a920ca2365680a84007c8b7aa9ebe60 |
| wip/fix-playlist-favorite | b56d1e0ba720842fc830e4b90d082e6209522136 |
| wip/fix-window-class | f4ff2b2a385f47f3d3490234fcae37895ab40bef |
| wip/cone-window-title | 863a7b2ce9a3e9c6d9caf591bfc1b1fd72c35873 |
| wip/decision-67 | 91560f33858af4c6807f544fc1bcb6871055d522 |
| wip/eq-curves | 5cdfdf3e86e7990af7f95c79e89c9477f60a1a45 |
| wip/web-fixes-3 | b1e5a5a3d9a179311773e64d5b5da1883ffabc08 |
| wip/web-fixes-4 | 640cba52c04c2b0ab09d214e8b4ba17daa04be28 |
| wip/musthaves-2 | c968f2332428c753a213dd28e7c0b1dbf4e2d4e7 |
| claude/zen-mendel-p1anpd | e1032d5ff1e9539a7565f9f75e3181b2388e9bae |
| wip/fix-subs-linux | e42622a1ea2b6fb93fda1866466e550cb183d42f |
| wip/fix-library-escape-linux | 4e9d55abfdd19186a9e2014ef0dacdb785e4d63a |
| wip/fix-quit-linux | bd4f6c7e0b4dd450ed93a961f428f78fd6e7115b |
| wip/fix-audio-icon-linux | eb28e5afce6e6b647a026a31b455f06de7276129 |
| wip/fix-chapter-title-linux | 8a520e7ea897883214f2083649feeca0db1a05c8 |
| wip/fix-playlist-favorite-linux | f26e913739e314c0e379483f0e3ef13d7494d720 |
| wip/fix-window-class-linux | c3c7077b76ff9085702f5cbcae50e87c5486e67b |
| wip/eq-icons-linux | 880a813597d799aed5f5ede99a55fc3570af63c5 |
| wip/web-fixes-3-linux | dce52191a5e83332c0ba648d5dd50f773779ff03 |
| wip/web-fixes-4-linux | de7f0b4193baffef360b06f5fa694850c0220418 |
| wip/fix-library | 424609380b3f5640137a43c4a774b61710747014 |
| wip/fix-panels | 6a9eba7fbc16662f3b6381361267dc369d556957 |
| wip/linux-recheck | a356b7aa93296eb6a357eb7c85a19c83e6c0e58a |
| wip/web-fixes-2 | bedec2f0d61fdeab276c29ad394183178014a7b1 |
| wip/next-batch | 332c42836e0d911786153c3d66b86646eff35fcb |
| wip/fix-quit-deadlock | 76f8ab7b1752179ee535f419c23f8674280c41f0 |

## Done (PC session, 2026-10-26, after the 1.0.0 release)

StickyGonzales's post-release cleanup: deleted every branch fully merged into `redesign` (tip an ancestor of `origin/redesign`) with no open PR, the test-only branches (`wip/test-*`, `*-linux`) whose PR is merged or closed, and the leftover `wip/test-installer-1.0`. Kept: `redesign`, `wip/next-test`, `master`, `wip/linux-build`, `wip/ci-release`, every head of an open PR (#29, #44, #47, #50, #53, #57), every branch pushed in the 24 hours before (GitHub activity: e.g. `wip/test-installer-1.0-ownkeys`, `wip/test-pr48-49`, the merged fix branches of 2026-10-25, the 1.0.1 seek fix branches), and unmerged branches that are not test branches (`wip/beta-gate`, `wip/verify-*`, `wip/code-audit`, `wip/diag-hevc-stall`, `wip/fix-pause-rate-clock`, `wip/fix-visualizer`, `wip/quit-hang-cause`, `wip/a839e9d9ddb97595a`). Each delete used a lease on the tip below, so a branch with newer commits would not have been deleted. To restore one: `git push origin <sha>:refs/heads/<branch>`.

PRs closed: #36 (title part merged as `wip/cone-window-title`; the visualizer crash fixed by the mmdevice change on `wip/fix-visualizer-pc`; its ICC timer part did not fix the white window), #38 (analysis notes only; the fix they led to, `wip/fix-hevc-surfaces-2n`, is merged; the remaining quit stall is a known issue in STATUS). Kept open: #29 (WINDOWS_CHECKLIST.md is not in `redesign` or `wip/next-test` and CLAUDE.md still points to it), #44 (the plan of #47).

| Branch | Why | Tip |
|---|---|---|
| claude/zen-mendel-p1anpd | merged into redesign | c3604b875554a38df37f8c4f50a0fe7412941769 |
| wip/fix-hevc-surfaces | merged into redesign | 9323061a32806f05ae4d626a9765e87c9241657a |
| wip/fix-hevc-surfaces-2n | merged into redesign | 883156a0ad5960cfb3ea3d21719dea0d431a7615 |
| wip/fix-network-playlist-name | merged into redesign | 1eadd46c99efd04f4cd4ac8c4eb6b57691d14826 |
| wip/fix-new-playlist-names | merged into redesign | f4c52f154b61b518e6a26bf79f9d13de5a786e7f |
| wip/fix-visualizer-pc | merged into redesign | f5a1fc15cc6db09b9c10714024d96d2bc5e2ffe7 |
| wip/motion-polish | merged into redesign | 91e51c3f0906d4e2f023f2b3f3e2ac4673f17353 |
| wip/subsdelay-bitmap | merged into redesign | 7c1a1ea7b2734a354c92a139d78a4067a8daf2f4 |
| wip/test-pr10 | merged into redesign | b04efc4af965d15e95eca86154ae7bb1bc64ee01 |
| wip/test-pr20 | merged into redesign | 554ac7e1c65812013188a73e89a7cdad78c45314 |
| wip/test-pr22 | merged into redesign | bd5d66d9d335abcf12b037939f95cddb4052cfd5 |
| wip/test-pr22b | merged into redesign | 6cf348ab0c8efda0b56c1ec5ab2992d42326d764 |
| wip/test-pr37 | merged into redesign | dcf4606b8284177fee42f57479a38dd89d1b54ed |
| wip/test-pr23-26 | test only, #23, #26 merged | eef6c172eccf1ba810c9ee680ddaec306249c2a6 |
| wip/test-pr2326b | test only, #23, #26 merged | 2e5872c468e8461bfa995d036b4f11e1e1ccc73e |
| wip/test-pr25 | test only, #25 merged | 742392bdcb4fd28a963a5234641495c4e1fa2bd6 |
| wip/test-pr25b | test only, #25 merged | 0b7b636637abfbe356be07e30e4cef5460524ab3 |
| wip/test-pr25c | test only, #25 merged | 54972104702aec643118cb26cb06d199e1e28f83 |
| wip/test-pr32 | test only, #32 closed | cbaf986c46c70a4843ca87a92b6da4fc59f02a4b |
| wip/test-pr32-dbg | test only, #32 closed | 1c94fd80cc68a32f755f1b28051370c1e61e1dab |
| wip/test-pr35 | test only, #35 merged | 92d5d4dd6e6688615da450564ba9e8d3730987b3 |
| wip/test-pr39-41-42 | test only, #39, #41, #42 merged | 63d6e1d0c5a9b84e39738189a3f9fa70e9f0ea25 |
| wip/test-pr40 | test only, #40 merged | ed65a4fe0491ffbad04a254f786e5f699a9136de |
| wip/motion-polish-linux | test only, #37 merged | cfff8e0e1bce215485dbeb2deebbb2b5fd10bb6c |
| wip/test-installer-1.0 | test only, #33 merged (leftover installer test) | 07fba89b8d89bd59c3390b7a466e17a3abc9a557 |
| wip/test-pr36 | test only, #36 closed (replaced) | 59f0e12427c64938cacfc23de809ceafd7f1dd15 |
| wip/fix-visualizer-linux | test only, #36 closed (replaced) | e77572d44ad09f30cb85af65544e683da59a4afe |
