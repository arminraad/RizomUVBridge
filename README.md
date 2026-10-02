# RizomUVBridge

A clean, editable bridge for exchanging UV data between Autodesk 3ds Max 2027 and RizomUV.

## Current status

Version `0.2.0-alpha` is the first topology-preserving transport implementation.

Runtime validation still has to be performed inside a real 3ds Max 2027 + RizomUV installation before this should be considered production-ready.

## Critical topology rule

The bridge must not alter model topology merely to transport UV data.

The original FBX alpha was retired after runtime testing showed triangulated geometry inside RizomUV. The root cause was broader than an FBX checkbox: MAXScript `snapshot()` returns a world-state mesh, so polygon topology could already be triangulated before export.

The current transport therefore:

- does not use `snapshot()` or `snapshotAsMesh()`;
- does not use FBX;
- does not call the built-in OBJ exporter or importer;
- clones the selected node, converts only the temporary clone to Editable Poly, and reads its polygon faces through `polyOp`;
- writes Wavefront OBJ directly, preserving each face's original polygon degree;
- parses the RizomUV OBJ result directly;
- rejects the result if the face topology signature changed;
- transfers only the UV channel back to the original node.

## Installation

From PowerShell:

```powershell
./build/package.ps1
```

The package is written to:

```text
dist/RizomUVBridge-3dsMax2027.mzp
```

Drag the MZP into a 3ds Max 2027 viewport or use **Scripting > Run Script**.

## Workflow

1. Select one or more geometry nodes.
2. Choose the UV channel.
3. Use **Send New UV** or **Send Edit UV**.
4. RizomUV loads a polygonal OBJ written by the bridge.
5. Edit UVs only; do not modify geometry.
6. Save in RizomUV.
7. The bridge parses the returned OBJ.
8. If topology is unchanged, only the UV channel is pasted back.

## Safety

The source node is never collapsed by the bridge.

A temporary copy is used for exchange and deleted immediately after the OBJ is written.

Returned topology is checked before UV transfer. A changed face count, polygon degree, or topology signature blocks the UV paste.

## Upstream reference

The workflow concept was inspired by the public `TitusLVR/RizomuvBridge` project. This implementation is maintained separately.

See `NOTICE.md` and `docs/TESTING.md`.
