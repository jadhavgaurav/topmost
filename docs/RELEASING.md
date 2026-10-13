# Releasing

A release is a version tag. Pushing the tag starts the `Release` workflow, which tests the code, builds the universal app, and publishes a GitHub release with the DMG, the zip and the checksums. The release notes are the changelog entry for that version, so the changelog is the only place release notes are written.

## One source of truth for the version

The version lives in `Sources/Topmost/Resources/Info.plist`:

- `CFBundleShortVersionString` is the version, for example `0.2.0`.
- `CFBundleVersion` is the build number. Increase it by one for every release.

`scripts/package.sh`, `scripts/release.sh`, the workflow and the About tab all read it from there. Nothing else hard-codes a version.

## Steps

1. **Update the changelog.** Add a section at the top of `CHANGELOG.md`:

   ```markdown
   ## [0.3.0] - 2026-11-01

   ### Added
   - ...

   ### Fixed
   - ...
   ```

   Write it for users. Say what changed for them, not which files moved. Use `### Added`, `### Changed`, `### Fixed` and `### Known issues`.

2. **Bump the version** in `Info.plist` (both keys).

3. **Commit and push** to `main`. Releases are cut only from an up-to-date `main`.

4. **Run the checks and tag**:

   ```bash
   ./scripts/release.sh --dry-run   # every check, changes nothing
   ./scripts/release.sh             # the same checks, then tags and pushes vX.Y.Z
   ```

   The script refuses to continue if the branch is not `main`, the tree is dirty, `main` is behind or ahead of `origin/main`, the tag already exists, the changelog has no entry for this version, or lint or the tests fail.

5. **Watch the workflow** at <https://github.com/jadhavgaurav/topmost/actions/workflows/release.yml>. It takes a few minutes.

6. **Check the release** on the [Releases page](https://github.com/jadhavgaurav/topmost/releases): the notes, the DMG, the zip and `SHA256SUMS` should be there. Run the installer once against it:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/jadhavgaurav/topmost/main/install.sh | bash
   ```

## What the workflow checks

- The tag matches the version in `Info.plist`, so a mistyped tag cannot publish the wrong version.
- `CHANGELOG.md` has an entry for that version.
- The test suite passes.
- The binary contains both `arm64` and `x86_64`.

If any check fails, nothing is published.

## Build without publishing

Run the `Release` workflow by hand from the **Actions** tab (the **Run workflow** button). It builds the artifacts and attaches them to the run, and skips the publish step because there is no tag.

To build locally:

```bash
TOPMOST_RELEASE=1 ./scripts/package.sh
ls dist/
```

`TOPMOST_RELEASE=1` makes the build ad-hoc signed, as in CI, even if you have set up the local signing identity.

## Re-running a release

Running the workflow again for a tag that already has a release replaces its files and notes, and does not create a second release. Use that to fix a bad asset or a typo in the changelog entry.

## Fixing a bad release

Do not move or delete a published tag. Release a new patch version with the fix, and add a note under **Known issues** in the changelog if people on the bad version need to act.

## Signing

Release builds are signed ad hoc, so macOS shows an "Open Anyway" prompt on first launch. The release notes explain this. To sign with a paid Apple Developer ID instead, set `SIGNING_IDENTITY` when running `package.sh`. Notarization is not set up.

For development builds on your own Mac, see [CONTRIBUTING.md](../CONTRIBUTING.md#signing-your-own-builds).
