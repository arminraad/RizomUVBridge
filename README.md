# RizomUVBridge

A clean, editable bridge for exchanging UV data between Autodesk 3ds Max 2027 and RizomUV.

## Current status

Version `0.1.0-alpha` is a source-complete first implementation targeted at 3ds Max 2027/2027.1.

Runtime validation still has to be performed inside an actual 3ds Max 2027 + RizomUV installation before this should be considered production-ready.

## Design

- The selected source nodes are not collapsed or replaced.
- Temporary snapshot nodes are exported to FBX.
- Snapshot names contain the original 3ds Max animation handle, which is used to map imported UV data back to the source node.
- UV data is pasted back through the 3ds Max `ChannelInfo` interface.
- The bridge never edits the main 3ds Max CUI configuration file directly.
- All MAXScript remains readable source; no MSE encryption is used.
- RizomUV is launched through a generated Lua file and the established `-cfi` command-line path.
- The installed FBX plug-in defaults are used instead of forcing an obsolete FBX file version.

## Installation

### Build an MZP package

From PowerShell:

```powershell
./build/package.ps1
```

The package will be written to:

```text
dist/RizomUVBridge-3dsMax2027.mzp
```

Drag the MZP file into a 3ds Max 2027 viewport, or use **Scripting > Run Script**.

The installer copies:

```text
src/RizomUVBridge.ms -> user scripts/RizomUVBridge/RizomUVBridge.ms
macros/AR_RizomUVBridge.mcr -> user macros
```

It then registers and opens the macro.

## Workflow

1. Select one or more geometry nodes.
2. Choose the UV channel.
3. Use **Send New UV** to ignore existing UVs, or **Send Edit UV** to load existing UVs.
4. Work in RizomUV.
5. Save from RizomUV.
6. The bridge detects the `_out.fbx` file and imports the selected UV channel automatically.
7. The temporary imported geometry is removed.

If automatic import is disabled, use **Import Result** manually.

## Safety model

The bridge snapshots evaluated geometry for export, so the source modifier stack is not collapsed during the send step.

On return, topology is checked before a UV channel is pasted. A topology mismatch is skipped rather than applied blindly.

Because `ChannelInfo.PasteChannel` behavior must still be verified on a real 3ds Max 2027 installation, test on disposable scene copies until the runtime validation checklist is complete.

## Upstream reference

The workflow concept was inspired by the public `TitusLVR/RizomuvBridge` project.

No license file was present in that upstream repository when this implementation was started, so this repository does not copy or assert a license over upstream source code. The 2027 implementation here was written separately.

See `NOTICE.md` and `docs/TESTING.md`.
