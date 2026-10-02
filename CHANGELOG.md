# Changelog

## 0.1.3-alpha - 2026-10-02

- Fixed FBX handoff settings that could triangulate Editable Poly topology.
- Explicitly disabled `Triangulate`.
- Explicitly disabled `PreserveEdgeOrientation`, which Autodesk documents as capable of converting Editable Poly objects to triangulated Editable Mesh when hidden edge turns are present.
- Disabled `SmoothMeshExport` for topology-preserving UV exchange.
- Added FBX exporter settings push/pop so user FBX settings are restored after bridge export.
- Expanded static validation for topology-preservation export settings.


## 0.1.2-alpha - 2026-10-02

- Fixed the remaining struct-member forward reference: `exchangeDir -> ensureConfig`.
- Reordered configuration initialization before all exchange-path functions.
- Added a generalized static check that rejects any future call from a struct member to a member declared later in the same structure.
- Audited the full current `RUVB2027Core` call graph; no other forward member references remain.


## 0.1.1-alpha - 2026-10-02

- Fixed MAXScript rollout label declaration for 3ds Max 2027.
- Fixed MacroScript scope shadowing of the global dialog entry point.
- Switched installer and macro loading to `executeScriptFile` with captured error messages.
- Added explicit global declarations for the dialog entry point.
- Switched source-node lookup to `GetAnimByHandle`.
- Replaced obsolete/incorrect FBX tangent parameter with `TangentSpaceExport`.
- Removed integer reparsing of animation handles during result mapping.
- Hardened result-file polling against transient file-size read failures.
- Expanded static compatibility validation to cover the discovered 2027 failure classes.

## 0.1.0-alpha - 2026-10-02

- Added clean 3ds Max 2027 bridge implementation.
- Added non-destructive snapshot export path.
- Added source-node mapping using 3ds Max animation handles.
- Added topology validation before UV transfer.
- Added configurable UV channel.
- Added New UV and Edit UV modes.
- Added automatic detection of the RizomUV `_out.fbx` result.
- Added source-readable MZP installer.
- Added PowerShell package builder and static validation.
- Added runtime validation checklist.
