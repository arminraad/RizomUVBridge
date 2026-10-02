# Runtime validation checklist

The current transport is designed around a strict rule: UV exchange must not change polygon topology.

## Primary target

- Autodesk 3ds Max 2027
- Current installed RizomUV build

## Installation

- Build/download the MZP.
- Install it in 3ds Max 2027.
- Confirm the window reports `0.2.0-alpha`.
- Confirm no MAXScript load error occurs.

## Topology test — required before UV tests

Use a disposable Editable Poly containing obvious quads and n-gons.

- Record the visible polygon layout in 3ds Max.
- Run **Send New UV**.
- In RizomUV, inspect the model before doing any UV operation.
- Confirm the same quads/n-gons are present.
- Confirm no diagonal triangulation edges were introduced.

If this test fails, stop. Do not proceed to UV return tests.

## New UV round-trip

- Create UVs in RizomUV.
- Save.
- Confirm the bridge imports only UV data.
- Confirm the original object name, transform, material, geometry, and modifier stack are unchanged.

## Edit UV round-trip

- Start from an existing UV channel.
- Run **Send Edit UV**.
- Move a recognizable UV island.
- Save.
- Confirm the same UV change returns to the same source node.

## Topology guard

- Start an exchange.
- Modify geometry topology before saving from RizomUV.
- Save.
- Confirm the bridge refuses to apply UVs and reports a topology mismatch.

## Multiple objects

- Send at least three polygon objects together.
- Confirm their object identities stay separate in RizomUV.
- Confirm each UV result maps back to the correct source node.

## Acceptance threshold

Do not merge the draft PR until the topology test and UV round-trip tests pass on the user's real 3ds Max 2027 + RizomUV installation.
