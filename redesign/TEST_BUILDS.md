# Test builds: where to download them

GitHub Actions artifact storage for the account is small (500 MB, full until 2026-11-01). Since 2026-10-25:

- **Every artifact lives one day** (`retention-days: 1`) in `build-windows.yml`, `build-linux.yml` and the release workflows. A failed artifact upload (storage full) no longer fails a test build.
- **Test builds are also release assets** on the draft pre-release **`test-builds`**. Only collaborators can see a draft. Release assets don't count toward the artifact storage. The Actions cache (ccache) is unchanged.
- **Release workflows** (`release.yml`, `release-linux.yml`) attach nothing there. Their own artifact (`cone-release-files`) still passes the packages to the release job, so a release still needs room for one day of artifacts.

## Asset names

One asset per branch and package kind: `<branch>--<kind>`, where `/` in the branch name becomes `-`. The next build of the same branch replaces it. The asset's label (shown on the release page) names the built file and the run, e.g. `Cone-0.1.0-win64.zip, run 103 (<commit>)`.

| Workflow | Kind | File |
|---|---|---|
| build-windows | `win64-public.zip` / `win64-vlc.zip` | the portable zip of that profile |
| build-windows | `win64-installer.exe` | the NSIS installer (public profile) |
| build-linux | `linux-x86_64.tar.xz` | the portable tarball |
| build-linux | `x86_64.AppImage` | the AppImage (chmod +x after downloading) |

Example: a public build of `wip/next-test` gives `wip-next-test--win64-public.zip` and `wip-next-test--win64-installer.exe`.

## Download (PC session)

GitHub web: the repository, **Releases**, the draft **Test builds (not a release)**, then click the asset.

With the GitHub CLI (logged in as the owner), in PowerShell:

```powershell
gh release download test-builds --repo StickyGonzales/vlc-redesign-juxtopposed --pattern "wip-next-test--win64-public.zip" --dir "$env:USERPROFILE\Downloads" --clobber
```

`gh release view test-builds --repo StickyGonzales/vlc-redesign-juxtopposed` lists the assets with their labels. The release holds every branch's latest build, so delete an asset there once its branch is merged or deleted (`gh release delete-asset test-builds <asset>`).

**Never publish this draft.** It is not a release, and publishing it would create a public `test-builds` tag.

The script that attaches the assets is `.github/scripts/test-build-assets.sh`.
