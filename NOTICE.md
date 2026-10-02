# Notice

This repository contains a separately maintained 3ds Max 2027 bridge implementation.

The historical workflow was informed by the public `TitusLVR/RizomuvBridge` project. At project initialization, that upstream repository did not expose a license file, so its MAXScript source is not redistributed here.

## RizomUVLink

Version 0.3.0-alpha uses the public integration API provided by **RizomUVLink**, authored by Rizom-Lab / Remi Arquier and released under the MIT License.

The distributed MZP bundles the unmodified Windows Python 3.13 runtime files from official Rizom-Lab RizomUVLink commit `b3be77f8777aea4c192d893d01380b4c989ccd6c`, together with its MIT license. The files are fetched from the official repository at package-build time and installed beside the bridge module.

RizomUV is a product of Rizom-Lab. 3ds Max is an Autodesk product. Product names are used only to describe interoperability.
