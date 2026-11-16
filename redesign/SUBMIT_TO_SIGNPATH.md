# Free code signing through SignPath Foundation: StickyGonzales's steps

Prepared on branch `wip/signpath-signing` (PC session, 2026-11-13). Nothing has been submitted. This file lists
what StickyGonzales does, in order. SignPath's rules were read on 2026-11-13 from
[signpath.org/terms](https://signpath.org/terms) and
[docs.signpath.io](https://docs.signpath.io/trusted-build-systems/github); read the terms page again before applying,
it changes.

## 0. Read this first

- **Who Windows shows as the publisher.** The certificate belongs to SignPath Foundation, so the installer's
  "Do you want to allow..." prompt says **Verified publisher: SignPath Foundation** instead of "Unknown publisher".
  It never shows "StickyGonzales" or "Cone Player" as the publisher.
- **SmartScreen does not stop at once.** A signed file still gets the blue "Windows protected your PC" screen for
  a while, until enough people have downloaded it. Signing takes away "Unknown publisher"; the warning fades with
  downloads.
- **The biggest risk: Cone is a fork of VLC's development branch.** SignPath signs forks only if all of these hold:
  1. the upstream project publishes signed builds: yes, VideoLAN signs its VLC releases;
  2. the project visibly uses a fork: yes, this repository is a GitHub fork of `videolan/vlc`;
  3. "the release branches you use for signing are based on upstream branches that are usually signed": this is
     the weak point. Cone's `redesign` branch is based on VLC's `master` (VLC 4.0 development). VideoLAN's signed
     releases come from the 3.0 branch, and as far as we know its VLC 4 nightly builds are not signed. Say this
     openly in the application (the answer below does), so SignPath decides with the facts. They may say no;
     their decision is final.
  4. code review of all changes to the upstream code: the answer below describes how changes are checked.
- **What gets signed:** `Cone.exe` and the installer. VLC's own DLLs and plugins stay unsigned, which the terms
  allow ("unsigned binaries of upstream OSS projects"). The uninstaller the installer writes on the PC is not
  signed, so removing Cone in Settings > Apps still shows "Unknown publisher".
- **Each release needs your approval in SignPath twice** (first `Cone.exe`, then the installer, which contains
  the signed `Cone.exe`). The release workflow waits up to 1 hour for each approval, then fails.
- **Every team member needs two-factor authentication** on GitHub and on SignPath (step 2).

## 1. Merge the policy page before applying

SignPath checks the project's pages when it reviews the application. The code signing policy has to be on the
home page (the README on `redesign`) and on the release pages first.

1. Review and merge the draft PR of `wip/signpath-signing` into `wip/next-test`, then into `redesign` with the next
   round (it changes the release workflow, so it goes through the normal test build).
2. Check on GitHub that the README shows "Code signing policy" under Download and Credits, and that
   [CODE_SIGNING_POLICY.md](../CODE_SIGNING_POLICY.md) opens.
3. Optional but good: add the same two lines to the description of the newest release (1.4.0), since every
   release made before this change lacks them: GitHub > Releases > Cone Player 1.4.0 > the pencil (Edit) > add
   at the end:
   `[Code signing policy](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/blob/redesign/CODE_SIGNING_POLICY.md): free code signing provided by [SignPath.io](https://about.signpath.io), certificate by [SignPath Foundation](https://signpath.org).`
   > Update release.

## 2. Two-factor authentication

**GitHub** (required now, for the application):
1. github.com > your picture (top right) > Settings > Password and authentication.
2. Under "Two-factor authentication": if it says "Enabled", nothing to do. Otherwise click **Enable two-factor
   authentication**, choose an authenticator app (Microsoft Authenticator, Google Authenticator, 1Password...),
   scan the QR code, type the 6-digit code.
3. Download the recovery codes and keep them somewhere safe (not in the repository, not on the Desktop).

**SignPath** (later, when SignPath invites you, step 4): set up two-factor authentication on the first login,
when SignPath asks for it.

## 3. The application form

Open [signpath.org/apply](https://signpath.org/apply). The form could not be read automatically (it is an
embedded HubSpot form), so its exact fields are not known here; published guides list these questions. Answer
each one with the matching text below; skip what the form does not ask.

| Question | Answer |
|---|---|
| Your name / contact | Your public name **StickyGonzales**, and an e-mail address where you can answer SignPath's follow-up questions. |
| Project name | `Cone Player` |
| Project / repository URL | `https://github.com/StickyGonzales/vlc-redesign-juxtopposed` |
| Project website / download page | `https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/latest` |
| Code signing policy URL | `https://github.com/StickyGonzales/vlc-redesign-juxtopposed/blob/redesign/CODE_SIGNING_POLICY.md` |
| License | `GPL-2.0-or-later` (like VLC media player; libVLC is LGPL-2.1-or-later). The design artwork is CC BY 4.0 and the fonts SIL OFL; there is no proprietary component and no dual licensing. |
| Build system / CI | GitHub Actions on GitHub-hosted runners (`.github/workflows/release.yml` calling `build-windows.yml`), in VideoLAN's own Windows build image. |
| What should be signed | The Windows release files: `Cone.exe` and the NSIS installer `coneplayer-<version>-win64.exe`. Product name "Cone Player" on both. VLC's DLLs and plugins stay unsigned. |
| Project description | See below. |

**Project description** (copy as it is):

> Cone Player is a free, open source media player for Windows (with Linux and macOS previews). It is VLC media
> player's engine with a new interface built from Juxtopposed's "VLC Redesign" (CC BY 4.0). It is a visible
> GitHub fork of videolan/vlc, based on VLC's master branch (VLC 4.0 development), because the new interface
> needs VLC 4's QML interface. VLC's core is kept as it is, apart from a few small fixes. Releases are built only
> from version tags on the `redesign` branch by GitHub Actions on GitHub-hosted runners; that branch receives only
> code that passed automated checks and a test on Windows. The project is maintained by one person
> (StickyGonzales, GitHub with two-factor authentication), with the AI coding assistant Claude; outside
> contributions come as pull requests. Current release: 1.4.0 (Windows installer and portable zip). About the
> fork rule: VideoLAN signs its VLC releases (3.0 branch); Cone follows VLC's master branch, whose development
> builds VideoLAN does not sign, as far as we know. We sign only Cone.exe and the installer, which we build from
> our own source; VLC's DLLs and plugins stay unsigned.

Then send the form. SignPath answers by e-mail, sometimes with questions first; answer them yourself.

## 4. After SignPath says yes

SignPath creates the organization and the project, or asks you to. Set it up like this (the release workflow
uses these names by default):

1. **Account:** accept the invitation, log in, set up two-factor authentication when asked.
2. **Organization ID:** in SignPath, your organization's settings show the **Organization ID** (a GUID). Copy it.
3. **Project:** slug `cone-player`, linked to the predefined trusted build system **GitHub.com**
   (Project > Trusted build systems > Add > GitHub.com). If SignPath asks for repository access, install the
   SignPath GitHub App for this repository only.
4. **Signing policy:** slug `release-signing` (SignPath may call theirs something else: then see step 5). You are
   the **approver**: every signing request waits for your approval.
5. **Artifact configurations:** two, so each file is checked for the right product name. Paste each XML in
   Project > Artifact configurations > Add:

   `cone-exe`:
   ```xml
   <artifact-configuration xmlns="http://signpath.io/artifact-configuration/v1">
     <pe-file product-name="Cone Player">
       <authenticode-sign/>
     </pe-file>
   </artifact-configuration>
   ```

   `cone-installer`:
   ```xml
   <artifact-configuration xmlns="http://signpath.io/artifact-configuration/v1">
     <pe-file product-name="Cone Player">
       <authenticode-sign/>
     </pe-file>
   </artifact-configuration>
   ```

   Both files are uploaded as single files (not zipped), so the root element is `<pe-file>`. If SignPath also
   wants the product version checked, both files write it the same way: `1,4,0,0` for 1.4.0 (ProductVersion).
6. **API token:** Users > Add **CI user** (for example `github-actions`), give it the **Submitter** role on the
   project's `release-signing` policy, then create its **API token** and copy it (it is shown once).

## 5. The GitHub secret and variables

github.com > the repository > Settings > Secrets and variables > Actions:

1. Tab **Secrets** > New repository secret: name `SIGNPATH_API_TOKEN`, value: the CI user's API token.
2. Tab **Variables** > New repository variable: name `SIGNPATH_ORGANIZATION_ID`, value: the Organization ID.
3. Only if SignPath's names differ from the defaults, add these variables too:

| Variable | Default when not set |
|---|---|
| `SIGNPATH_PROJECT_SLUG` | `cone-player` |
| `SIGNPATH_SIGNING_POLICY_SLUG` | `release-signing` |
| `SIGNPATH_EXE_CONFIGURATION_SLUG` | `cone-exe` |
| `SIGNPATH_INSTALLER_CONFIGURATION_SLUG` | `cone-installer` |

Signing switches on by itself once the secret and `SIGNPATH_ORGANIZATION_ID` both exist, and only for releases
(`release.yml`). Test builds are never signed. To switch it off again, delete the `SIGNPATH_ORGANIZATION_ID`
variable.

## 6. The first signed release

1. Release as usual (a version tag on `redesign`). The run summary says "Code signing: Cone.exe and the installer
   are signed through SignPath".
2. SignPath e-mails you twice during the run: open each signing request and **Approve** it. The first is
   `Cone.exe`, the second (a few minutes later) the installer. Each waits up to 1 hour.
3. When the release is out, download the installer, right-click it > Properties > **Digital Signatures**: it
   lists "SignPath Foundation". Or in PowerShell:
   `Get-AuthenticodeSignature "$env:USERPROFILE\Downloads\coneplayer-<version>-win64.exe" | Format-List Status, SignerCertificate`
   (Status must be `Valid`).
4. The release notes then say the files are signed instead of the SmartScreen tip.

## 7. How the workflow signs (for reference)

`build-windows.yml`, release builds only (`CODE_SIGNING_POLICY.md` describes it for users):

1. the normal build and portable zip;
2. `win64-build.sh stage-for-signing`: the package folder staged and stripped as the installer takes it,
   `Cone.exe` copied out;
3. `Cone.exe` uploaded as a workflow artifact and sent to SignPath (`signpath/github-action-submit-signing-request`
   v3.0, pinned), which waits for the approval and downloads the signed file;
4. `win64-build.sh package-signed`: the signed `Cone.exe` back into the folder, then the installer and the zip made
   from it with `package-win32-exe-staged` / `package-win32-zip-staged` (no new staging or stripping, which would
   undo the signature); the workflow checks the zip holds the signed file;
5. the installer sent to SignPath the same way, and the signed installer put in its place;
6. `release.yml` publishes them and writes the signing note into the release notes.

The installer now has version information (product name "Cone Player", the release's version), which SignPath
checks on every signed file. A manual run of build-windows with **signing-dry-run** goes through steps 2 and 4
with the unsigned `Cone.exe`, to check the packaging without SignPath.
