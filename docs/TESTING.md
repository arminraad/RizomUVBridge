# Runtime validation checklist

Version under test: `0.3.2-alpha`

The direct-link architecture has one non-negotiable rule: only UV data may return to the source object.

## Phase 1 — installation and runtime compatibility

- Install the MZP in 3ds Max 2027.
- Confirm the bridge window reports `0.3.2-alpha — Direct RizomUVLink`.
- Click **Set RizomUV EXE** and select the installed `rizomuv.exe`.
- Close and reopen the bridge; confirm the path is retained.
- Click **Connection Info**.
- Confirm Max Python is 3.13.x.
- Confirm an installed RizomUVLink path is reported.
- Confirm there is no MAXScript or Python traceback.

## Phase 2 — direct topology transfer

Use a disposable Editable Poly containing obvious quads and one controlled n-gon.

- Select only that object.
- Click **Send New UV**.
- Confirm RizomUV opens through the direct link.
- Confirm the object is upright, not rotated 90 degrees.
- Do not unwrap yet.
- Compare the visible object silhouette and polygon structure with Max.

Important: a DCC/GPU may visually tessellate an n-gon internally for drawing. The acceptance criterion is not merely the absence of every diagonal line in the Rizom viewport; the bridge's returned `PolySizes` and `PolyXYZIDs` must remain identical. The Get guard enforces this.

## Phase 3 — new UV return

- Create a simple unwrap in RizomUV.
- Click **Get UVs** in Max.
- Confirm UV channel 1 appears on the original object.
- Confirm source geometry, transform, material and modifier stack are unchanged.

## Phase 4 — edit existing UV

- Start with a recognizable UV channel.
- Click **Send Edit UV**.
- Move one UV island in RizomUV.
- Click **Get UVs**.
- Confirm only the UV change returns.

## Phase 5 — topology rejection

- Send the object.
- Change source topology in Max before Get.
- Click **Get UVs**.
- Confirm the bridge refuses to apply UVs.

If RizomUV geometry topology itself is modified, Get must also refuse the result.

## Phase 6 — multiple objects

After all single-object tests pass:

- Send three separate polygon objects.
- Confirm their combined direct payload is stable.
- Confirm the returned UV corner ranges map back to the correct source objects.

## Acceptance threshold

Do not merge PR #1 until Phases 1–5 pass on the user's actual 3ds Max 2027 + RizomUV installation.
