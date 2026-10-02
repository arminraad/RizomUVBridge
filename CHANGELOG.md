# Changelog

## 0.3.0-alpha - 2026-10-02

- Replaced FBX/OBJ geometry transport with Rizom-Lab's official RizomUVLink direct API.
- Added Python/PySide6 bridge core for 3ds Max 2027.
- Added automatic discovery of the RizomUVLink module installed with RizomUV.
- Added fileless polygon transfer using PolySizes, PolyXYZIDs, CoordsXYZ, PolyUVWIDs and CoordsUVW.
- Added explicit 3ds Max Z-up to RizomUV Y-up coordinate conversion.
- Added direct UV retrieval with `Save({"Data": True})`.
- Added topology guards against changed polygon sizes and polygon XYZ IDs.
- Added source-topology revalidation before UV paste.
- Retained ChannelInfo only for the final UV-channel paste to the untouched source node.
- Retired the MAXScript geometry core and file-based exchange path.
- Added Python syntax compilation to CI.

## 0.2.0-alpha - 2026-10-02

- Experimental custom OBJ transport. Runtime validation exposed axis/orientation and mesh interpretation problems; retired.

## 0.1.3-alpha - 2026-10-02

- Experimental FBX topology-preservation settings. Runtime validation still showed unacceptable geometry behavior; retired.

## 0.1.2-alpha - 2026-10-02

- Fixed struct-member dependency order and added forward-reference validation.

## 0.1.1-alpha - 2026-10-02

- Fixed rollout label declaration and MacroScript scope loading.

## 0.1.0-alpha - 2026-10-02

- Initial 3ds Max 2027 bridge alpha.
