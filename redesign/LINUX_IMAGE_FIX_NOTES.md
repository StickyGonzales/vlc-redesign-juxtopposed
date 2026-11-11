# The Linux build image builds again (apt exit 100)

Branch `wip/fix-linux-jammy-image`. Draft pull request into `wip/next-test`. StickyGonzales, 2026-11-11. CI only: nothing in Cone changes.

## 1. What broke
- **Symptom:** every build-linux run since 2026-11-11 morning stopped at "Build image".
  - Runs #106-#109, including `wip/next-test`'s #108 (run 43051428950).
  - `apt-get install` exited with code 100 on all three tries.
- **Why the reason was hidden:** the image was built with `docker build -q`, which prints nothing on failure.
- **The real error** (shown once the step printed apt's own output, #110 and #111):
  - `apt-get update` could not resolve `archive.ubuntu.com` or `security.ubuntu.com`.
  - Ubuntu 22.04's apt only warns about lists it cannot fetch. So the install then found no package at all: "Unable to locate package curl", and so on for every package.
- **Not Docker's build network:** with `docker build --network host` (#112), the same names did not resolve on the runner itself ("Temporary failure resolving"). #114 logged it from the runner: `does not resolve: archive.ubuntu.com`, `does not resolve: security.ubuntu.com`.
- **The runner's own apt** uses the mirrors listed in `/etc/apt/apt-mirrors.txt` (a `mirror+file:` source), not those two names.
- **When:** the runner image in the failed runs is `ubuntu24/20261101.360`.
- **Intermittent:** in #116 the Ubuntu names resolved again on the runner, so the outage lasted for hours (#106-#114), not for good. Taking the runner's own mirror (Azure's copy, which the runner's apt uses all the time) and stopping on any list apt cannot fetch keeps the image build working through the next outage, and makes a failure name its reason.
- **Local check (Ubuntu 22.04 container with this image's full package list):** the dependencies resolve and every package downloads and installs (exit 0). So the package set itself is fine.

## 2. The fix
| File | Change |
|---|---|
| `.github/workflows/build-linux.yml`, Build image | Picks the Ubuntu archive for the image: each mirror in the runner's `apt-mirrors.txt` (Azure's copy of the archive), then any `azure.archive.ubuntu.com` source, then kernel.org's full Ubuntu mirror (security included); the first whose name resolves. It logs every name it tried and writes the choice into the run summary. `docker build --network host` (the runner's network and DNS), `--progress=plain` into `image-build.log`; a failed attempt prints apt's errors and the end of the log. |
| `.github/linux/jammy.Dockerfile` | `ARG UBUNTU_MIRROR`: when set, every pocket in `sources.list` (main, updates, backports, security) points at it, and the step prints the result. `apt-get update --error-on=any`: a list apt cannot fetch stops the build with its reason (tested: a source that does not resolve gives `E: Failed to fetch ... Could not resolve`). `Acquire::Retries "5"`. Without the argument (a local build), Ubuntu's own archive is used as before. |

## 3. Runs
| Run | Result |
|---|---|
| #110 (43054738526), 7cdb61c | diagnostic: "Unable to locate package" for every package |
| #111 (43055843057), b39dc9e | diagnostic: `Could not resolve 'archive.ubuntu.com'` / `'security.ubuntu.com'` |
| #112 (43056971404), 9e16e82 | `--network host` alone: "Temporary failure resolving", still failed |
| #114 (43059605262), 7aac592 | runner mirror from its sources: none listed there, fell back to archive.ubuntu.com, failed; logged that neither Ubuntu name resolves |
| #116 (43063041270), 15a82dc | **green**: image built from `http://azure.archive.ubuntu.com/ubuntu/` (the first mirror in the runner's apt-mirrors.txt), Cone built, tarball, AppImage and .deb made; smoke checks green (Ubuntu 24.04 and 22.04 runners, Debian 12) |
| #117 (43063926222), on `wip/fix-linux-wayland-embed` (this fix merged) | **green**, with the #116 fix and its new Wayland checks |

## 4. Retest
Nothing to test by hand: the result is a green build-linux run on this branch, with its smoke checks. After the merge, build-linux on `wip/next-test` must pass "Build image".
