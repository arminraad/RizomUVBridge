# RizomUVBridge

A topology-preserving bridge for Autodesk 3ds Max 2027 and RizomUV.

## Current status

Version `0.3.1-alpha` replaces the experimental file-transport implementations with Rizom-Lab's official **RizomUVLink** API.

The draft is still under runtime validation and must not be considered production-ready yet.

## Why the architecture changed

Runtime tests of the early FBX and OBJ alphas exposed exactly the class of problems a UV bridge should avoid:

- triangulation and hidden tessellation differences;
- axis conversion / 90-degree orientation problems;
- importer/exporter-specific mesh interpretation;
- risk that a returned mesh no longer matches 3ds Max's polygon representation.

Research of the current RizomUV ecosystem showed that Rizom-Lab now provides **RizomUVLink**, an MIT-licensed DCC integration library with a fileless mesh-transfer API.

Its official fileless example transfers these arrays directly:

- polygon sizes;
- polygon-to-XYZ vertex IDs;
- XYZ coordinates;
- polygon-to-UVW vertex IDs;
- UVW coordinates.

That is now the bridge architecture.

## Transport invariants

The bridge does **not** use FBX or OBJ for geometry transport.

It does **not** call `snapshot()`.

It does **not** replace or collapse the user's source object.

For each Send:

1. A temporary evaluated copy of the selected object is created.
2. Polygon arrays are read through `polyOp`.
3. Max Z-up coordinates are converted to RizomUV Y-up coordinates.
4. The arrays are sent directly through `RizomUVLink.Load()`.
5. The temporary copy is deleted.

For Get:

1. UV arrays are read directly through `RizomUVLink.Save({"Data": True})`.
2. Polygon sizes and polygon XYZ IDs are checked against the Send session.
3. The current source topology is checked again.
4. UV data is staged on a temporary copy.
5. Only the requested map channel is pasted to the source through ChannelInfo.

If geometry topology differs, the UV transfer is blocked.

## Requirements

- Autodesk 3ds Max 2027
- RizomUV 2026.0 or newer
- Windows
- The bridge first uses the pinned official RizomUVLink runtime bundled in the MZP; an installed RizomUVLink folder is only a fallback

3ds Max 2027 ships Python 3.13.x; current RizomUVLink includes Python 3.13 support.

## Installation

Build/download:

```text
RizomUVBridge-3dsMax2027.mzp
```

Drag the MZP into the 3ds Max viewport.

The installer places the Python module in the user Python scripts directory and registers the `AR Tools > RizomUV Bridge 2027` macro.

## Usage

- **Send New UV** — send current evaluated polygon topology with a fresh UVW seed.
- **Send Edit UV** — send current evaluated polygon topology plus the selected existing UV channel.
- Work in RizomUV.
- **Get UVs** — retrieve UV arrays directly from the live RizomUV session and apply only that UV channel.

No manual Save in RizomUV is required for the direct-link Get operation.

## Upstream references

The historical workflow was inspired by `TitusLVR/RizomuvBridge`.

The current transport is based on the public API design demonstrated by Rizom-Lab's MIT-licensed `RizomUVLink` project. The library itself is not bundled here; the bridge loads the copy installed with RizomUV.

See `NOTICE.md` and `docs/TESTING.md`.
