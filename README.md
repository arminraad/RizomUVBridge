# RizomUVBridge

A clean 3ds Max 2027 bridge for exchanging UV data with RizomUV.

## Status

Initial implementation for 3ds Max 2027 is under active development.

## Design goals

- Preserve the original scene and modifier stack whenever possible.
- Export only temporary snapshot geometry to RizomUV.
- Bring UV channels back to the original nodes without replacing the source objects.
- Avoid direct editing of 3ds Max CUI configuration files.
- Use editable MAXScript source instead of encrypted MSE files.
- Keep the exchange format and RizomUV launch settings explicit and configurable.

## Upstream reference

The workflow is inspired by the public TitusLVR/RizomuvBridge project. This repository is maintained separately for the 3ds Max 2027 implementation.

No upstream license file was present when this repository was initialized, so no upstream source license is asserted here.
