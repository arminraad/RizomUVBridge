# Runtime validation checklist

The repository can statically validate and package the bridge, but a real 3ds Max + RizomUV session is required to prove the round-trip.

## Primary target

- Autodesk 3ds Max 2027
- Autodesk 3ds Max 2027.1
- Current installed RizomUV build

## Required tests

### Installation

- Build the MZP with `build/package.ps1`.
- Drag the MZP into 3ds Max 2027.
- Confirm the macro registers under the `AR Tools` category.
- Confirm the installer validates the core script, registers the macro, and opens the bridge without modifying or resetting the user's CUI configuration.
- Close the bridge and run `RizomUV Bridge 2027` once from the `AR Tools` category to verify the macro entry point independently.

### First-run configuration

- Click **Set RizomUV EXE**.
- Select the installed `rizomuv.exe`.
- Close and reopen 3ds Max.
- Confirm the executable path persists.

### Single object / New UV

- Use a disposable Editable Poly with known topology.
- Add a visible modifier above the base object.
- Record the modifier stack.
- Send with **New UV**.
- Create UVs in RizomUV and save.
- Confirm UV channel 1 returns.
- Confirm object transform, name, materials and modifier stack remain unchanged.

### Single object / Edit UV

- Start with an existing UV channel.
- Send with **Edit UV**.
- Move a recognizable island.
- Save and confirm the changed UV returns to the same source node.

### Multiple objects

- Select at least three differently named geometry objects.
- Round-trip all objects together.
- Confirm each imported UV channel maps back to the correct original object.

### Topology guard

- Start a round-trip.
- Change source topology in 3ds Max before saving from RizomUV.
- Confirm the bridge refuses to paste UVs to the changed object and reports a topology mismatch.

### UV channels

- Test channel 1.
- Test a non-default channel such as channel 2.
- Confirm only the selected channel is updated.

### Paths

- Test a normal local path.
- Test a Windows user profile containing spaces.
- Test an exchange folder containing non-ASCII characters if practical.

### Failure handling

- Invalid RizomUV executable.
- RizomUV closed without saving.
- FBX plug-in unavailable or disabled.
- Output FBX still being written while the polling timer is active.
- Imported FBX missing the requested UV channel.

## Acceptance threshold

Do not label a release production-ready until all primary tests pass on 3ds Max 2027 and at least one current RizomUV build.

If `ChannelInfo.PasteChannel` causes destructive stack behavior on 2027, stop and replace the return path before release.
