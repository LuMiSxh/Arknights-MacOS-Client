# Experimental custom runtime and CN compatibility

Status: Proposed
Related issues:
[#11 — CN and JP versions](https://github.com/LuMiSxh/Arknights-MacOS-Client/issues/11),
[#34 — In-game mouse lag](https://github.com/LuMiSxh/Arknights-MacOS-Client/issues/34)

## Summary

Arknights Client may eventually allow advanced users to select a compatible custom runtime instead of
the bundled default. This would create an isolated path for experiments that require patched Wine or
DXMT builds, including investigation of the official CN client and optional graphics latency changes.
The Bilibili channel would require its own later validation because its launcher, package, and account
path differ even if game executables prove equivalent.

The project should not become a rolling Wine distribution. Any project-provided runtime remains pinned
as one tested Wine, DXMT, media, and compatibility unit. Automation may build immutable candidates and
report patch failures, but it must never promote an untested build or silently replace the launcher's
runtime pin.

CN support remains an experiment until the current CN client is demonstrated to complete launcher,
login, anti-cheat initialization, gameplay, and clean shutdown on supported macOS versions. Evidence
that another Tencent ACE title works with patched Wine makes a proof of concept reasonable, but does
not establish that Arknights CN uses the same ACE version or compatible execution path.

## Goals

- Keep the reviewed Global, Japan, and Korea runtime unchanged by default.
- Permit a deliberately selected custom runtime that satisfies the launcher's documented runtime
  interface.
- Build reproducible, immutable runtime candidates from pinned source commits and patch sets.
- Isolate CN launcher, account, anti-cheat, registry, and prefix state from supported regions.
- Detect patch conflicts and build failures automatically without requiring routine maintainer tests.
- Allow interested community members to test and maintain experimental CN candidates.
- Provide a suitable build path for narrowly scoped Wine or DXMT experiments, such as configurable
  frame latency, without committing the launcher to those changes.

## Non-goals

- Promising official CN or Bilibili support before an end-to-end compatibility result exists.
- Automatically following Wine, WineCX, CrossOver, DXMT, or dependency development branches.
- Rebuilding or manually testing Wine every week.
- Automatically publishing or selecting the newest successful CI artifact.
- Sharing a CN prefix with Global, Japan, or Korea during the experimental phase.
- Bundling CrossOver, Apple's Game Porting Toolkit, game files, or proprietary anti-cheat files.
- Guaranteeing that an unsupported anti-cheat environment is safe from account restrictions.
- Accepting responsibility for community runtimes that stop working after game or ACE updates.

## Technical basis

The existing `dappermint/winecx-gptk` recipe is the preferred base because it already produces the
complete relocatable archive expected by Arknights Client: WineCX, DXMT, Wine Gecko, GStreamer, FFmpeg,
MoltenVK, and their runtime dependencies. Its build workflow already supports applying an external
Wine patch directory.

`Endfield_FineWine` demonstrates one working macOS approach for a Tencent ACE title. Its patch set
contains Rosetta exception handling changes, `ntoskrnl.exe` implementations and stubs, a constrained
`KiUser*Dispatcher` compatibility workaround, and a timing-sensitive wait implementation. Most of the
patch series applies to the currently pinned WineCX source; several remaining patches are already
represented by newer WineCX implementations or stubs. The macOS Rosetta signal changes still require
a reviewed port.

This mechanical compatibility does not prove Arknights CN compatibility. A first canary must capture
the real CN failure path and determine which patches are necessary. Game-specific behavior must be
enabled only for the CN launch environment rather than inferred from a process name shared by other
regions.

The custom runtime must preserve the archive interface declared by `runtime.json`, including the Wine
executables, macOS driver, launcher alias, and both DXMT payload architectures. A candidate that changes
that interface requires a reviewed launcher and migration change rather than custom-runtime selection
alone.

## Repository and artifact model

A separate public repository should own:

- immutable upstream source pins;
- Wine and DXMT patch files with their original authorship and licenses;
- the runtime build and validation workflow;
- component versions, checksums, and source provenance;
- complete corresponding-source and third-party notice artifacts required for distributed binaries;
- candidate release notes describing whether the build is experimental, tested, or promoted.

Each candidate record must identify the exact WineCX, DXMT, recipe, and patch commits. A CN canary must
also record the official launcher, game, and observed ACE versions so that a passing result is not
treated as evidence for a later, materially different client.

The repository should publish distinct channels:

- **Standard candidate:** the normal runtime recipe plus optional changes whose default behavior is
  unchanged.
- **CN experimental candidate:** the ACE-oriented patch set and a runtime intended only for an isolated
  CN prefix.

The launcher repository remains the authority for its bundled runtime. Selecting a new default still
requires an explicit reviewed `runtime.json` change.

Promotion authority remains with the launcher maintainer or designated runtime maintainers. Community
testers may supply canary results, but a successful report does not promote an artifact automatically.

## Automation and maintenance policy

Routine automation should be inexpensive and should not create a testing obligation:

1. A scheduled metadata job notices a new reviewed upstream runtime or source pin.
2. It checks whether the maintained patch series still applies.
3. A conflict opens or updates one issue; it does not force an upgrade.
4. Full macOS builds run only on explicit dispatch, for a required compatibility fix, or before a
   planned runtime release.
5. Successful builds produce immutable candidate artifacts with checksums and provenance.
6. No candidate is promoted without a manual end-to-end canary result.

The project may retain a working Wine and DXMT pin for months. A newer upstream version alone is not a
reason to rebuild or migrate. Relevant security fixes, supported-macOS compatibility, a game or ACE
breakage, or a measured improvement are valid reasons to evaluate a candidate.

Manual testing is required only when somebody chooses to promote a candidate. Merely detecting a new
upstream revision or a patch conflict does not require a maintainer to build or test anything.

## Testing expectations

The maintainer's M4 is sufficient for development and the primary canary. An M2 may be borrowed for a
major runtime transition, but is not required for every candidate. Other chip coverage depends on
voluntary community testers.

A promoted runtime requires at least:

- archive, architecture, dynamic-library, export, and prefix-initialization checks in CI;
- one supported-region launch, representative login or embedded-browser path, and clean exit;
- for CN, launcher startup, login, ACE initialization, gameplay, and clean exit in an isolated prefix;
- a clear record of the tested Mac, macOS version, runtime revision, and prefix history.

Fresh- and existing-prefix scenarios may alternate between routine updates. Both are required for a
major Wine, storage, or migration transition. CI cannot replace the real CN and ACE canary because it
does not possess the client, account session, or meaningful gameplay environment.

Experimental testers must be told that the configuration is unsupported, may stop working after an
update, and may carry account-enforcement risk. No result should be described as account-safe.

## Optional DXMT latency experiment

DXMT currently permits up to three frames in its command queue. A narrowly scoped environment option
could allow an experimental maximum of one while preserving the upstream default. This may reduce the
latency of the cursor rendered inside the game frame, but the behavior also occurs on Windows and is
not proven to be caused solely by DXMT.

The relevant queue setting is isolated in current DXMT source, but a safe configuration patch still
requires implementation review. The actual cost is building both DXMT architectures and checking frame
rate, pacing, stutter, cursor latency, and regressions across representative Macs. It should therefore
remain independent from CN support and disabled unless explicitly selected.

## Launcher integration

Custom-runtime selection should be an advanced, reversible setting rather than another supported
runtime channel. Before accepting a runtime, the launcher must validate its declared schema, required
paths, architectures, and checksum. It must not execute a runtime directly from a download or arbitrary
mutable directory.

The default runtime remains bundled and recoverable. Resetting the setting returns to that runtime
without deleting game installations. Experimental CN support additionally requires a separate prefix
and region-specific launcher or backend integration; custom-runtime selection by itself does not add
CN download, account, or update behavior.

## Decision gate

Implementation should proceed only when all of the following are available:

- access to the current official CN client and a suitable test account;
- at least one interested CN player willing to test experimental builds and report sanitized results;
- agreement that candidates receive no guaranteed maintenance or response time;
- a reproducible runtime build that includes the necessary sources, licenses, and provenance;
- a successful M4 canary through login and gameplay without modifying official game binaries.

Until those conditions are met, the proposal remains research material. The current supported scope of
Global, Japan, and Korea does not change.
