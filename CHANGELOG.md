# Changelog

## 0.2.0-alpha - 2026-10-02

- Replaced the FBX transport with a custom topology-preserving OBJ transport.
- Removed `snapshot()`; Autodesk documents it as producing a world-state mesh, which can triangulate polygon topology before export.
- Removed dependency on 3ds Max FBX and OBJ importer/exporter plug-ins for geometry transport.
- Added direct polygon OBJ writer using Editable Poly face arrays.
- Added direct OBJ result parser.
- Added topology-signature validation before any UV data is applied.
- Added direct UV reconstruction on a temporary Editable Poly clone.
- Kept `ChannelInfo` only for the final UV-channel paste back to the untouched source node.
- Added static checks that forbid snapshot, FBX, built-in OBJ import/export, and generic import/export calls from the core.

## 0.1.3-alpha - 2026-10-02

- Attempted FBX topology-preservation settings. Runtime validation showed triangulation still occurred.

## 0.1.2-alpha - 2026-10-02

- Fixed struct-member dependency order and added forward-reference validation.

## 0.1.1-alpha - 2026-10-02

- Fixed rollout label declaration and MacroScript scope loading.

## 0.1.0-alpha - 2026-10-02

- Initial 3ds Max 2027 bridge alpha.
