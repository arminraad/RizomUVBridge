"""
RizomUVBridge for Autodesk 3ds Max 2027
Version 0.3.0-alpha

Direct, fileless bridge using Rizom-Lab's installed RizomUVLink module.

Design invariants:
- no FBX/OBJ geometry transport;
- no snapshot()/TriMesh transport;
- source nodes are never collapsed or replaced;
- evaluated temporary copies are used only to read topology and stage returned UVs;
- polygon sizes and XYZ polygon indices are validated before UVs are accepted;
- only the requested map channel is pasted back to source nodes.
"""

from __future__ import annotations

import os
import re
import sys
import winreg
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Sequence, Tuple

from PySide6 import QtCore, QtWidgets
from pymxs import runtime as rt
from qtmax import GetQMaxMainWindow


VERSION = "0.3.0-alpha"
MODULE_NAME = "ar_rizomuv_bridge"


@dataclass
class ObjectSession:
    handle: int
    name: str
    face_start: int
    face_count: int
    corner_start: int
    corner_count: int
    face_sizes: List[int]
    local_poly_xyz_ids: List[int]


@dataclass
class BridgeSession:
    uv_channel: int
    poly_sizes: List[int]
    poly_xyz_ids: List[int]
    objects: List[ObjectSession]


_link = None
_session: Optional[BridgeSession] = None
_dialog = None


def _find_rizom_install_dir() -> Path:
    """Find the newest installed RizomUV using Rizom-Lab's Windows registry keys."""
    try:
        root = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Rizom Lab")
    except FileNotFoundError as exc:
        raise RuntimeError("RizomUV installation was not found in the Windows registry.") from exc

    versions = []
    with root:
        index = 0
        while True:
            try:
                name = winreg.EnumKey(root, index)
            except OSError:
                break
            index += 1
            match = re.fullmatch(r"RizomUV VS RS ([0-9]+)\.([0-9]+)", name)
            if match:
                versions.append(((int(match.group(1)), int(match.group(2))), name))

        for _, name in sorted(versions, reverse=True):
            try:
                with winreg.OpenKey(root, name) as key:
                    exe_path = winreg.QueryValue(key, "rizomuv.exe")
                install_dir = Path(exe_path).parent
                if (install_dir / "RizomUVLink" / "RizomUVLink.py").is_file():
                    return install_dir
            except (FileNotFoundError, OSError):
                continue

    raise RuntimeError(
        "RizomUV was found, but its RizomUVLink module was not found. "
        "RizomUV 2026.0 or newer is required for this bridge."
    )


def _import_rizomuv_link():
    install_dir = _find_rizom_install_dir()
    link_dir = install_dir / "RizomUVLink"
    link_dir_str = str(link_dir)

    if link_dir_str not in sys.path:
        sys.path.insert(0, link_dir_str)

    try:
        import RizomUVLink
    except Exception as exc:
        raise RuntimeError(
            f"Could not import RizomUVLink from {link_dir}. "
            f"3ds Max Python is {sys.version.split()[0]}. Error: {exc}"
        ) from exc

    return RizomUVLink


def _ensure_link():
    global _link

    if _link is not None:
        return _link

    module = _import_rizomuv_link()
    link = module.CRizomUVLink()

    try:
        port = link.RunRizomUV()
    except Exception as exc:
        raise RuntimeError(f"RizomUVLink could not launch/connect to RizomUV: {exc}") from exc

    _link = link
    print(
        f"RizomUVBridge {VERSION}: direct link connected on port {port}; "
        f"RizomUVLink {link.Version()}; RizomUV {link.RizomUVVersion()}"
    )
    return _link


def _selected_geometry():
    result = []
    for node in list(rt.getCurrentSelection()):
        try:
            if rt.superClassOf(node) == rt.GeometryClass:
                result.append(node)
        except Exception:
            continue
    return result


def _make_evaluated_poly_copy(source):
    temp = None
    try:
        temp = rt.copy(source)
        rt.convertToPoly(temp)
        return temp
    except Exception:
        if temp is not None:
            try:
                rt.delete(temp)
            except Exception:
                pass
        raise


def _delete_node(node):
    if node is None:
        return
    try:
        if rt.isValidNode(node):
            rt.delete(node)
    except Exception:
        pass


def _point_world(node, poly, vertex_index: int):
    local = rt.polyop.getVert(poly, vertex_index)
    return local * node.objectTransform


def _max_zup_to_rizom_yup(point) -> Tuple[float, float, float]:
    # 3ds Max: Z-up. RizomUV viewport: Y-up.
    # Rotate -90 degrees around X: (x, y, z) -> (x, z, -y).
    return float(point.x), float(point.z), float(-point.y)


def _face_vertices(poly, face_index: int) -> List[int]:
    return [int(v) for v in rt.polyop.getFaceVerts(poly, face_index)]


def _extract_local_topology(poly) -> Tuple[List[int], List[int]]:
    face_sizes: List[int] = []
    flattened_ids: List[int] = []

    face_count = int(rt.polyop.getNumFaces(poly))
    for face_index in range(1, face_count + 1):
        verts = _face_vertices(poly, face_index)
        face_sizes.append(len(verts))
        flattened_ids.extend(v - 1 for v in verts)

    return face_sizes, flattened_ids


def _map_supported(poly, channel: int) -> bool:
    try:
        return bool(rt.polyop.getMapSupport(poly, channel)) and int(
            rt.polyop.getNumMapVerts(poly, channel)
        ) > 0
    except Exception:
        return False


def _extract_payload(nodes, channel: int, existing_uvs: bool):
    poly_sizes: List[int] = []
    poly_xyz_ids: List[int] = []
    coords_xyz: List[float] = []
    poly_uvw_ids: List[int] = []
    coords_uvw: List[float] = []
    object_sessions: List[ObjectSession] = []

    vertex_offset = 0
    uv_offset = 0
    face_offset = 0
    corner_offset = 0

    for source in nodes:
        temp = _make_evaluated_poly_copy(source)
        try:
            poly = temp.baseObject
            vertex_count = int(rt.polyop.getNumVerts(poly))
            face_count = int(rt.polyop.getNumFaces(poly))
            local_face_sizes, local_xyz_ids = _extract_local_topology(poly)

            object_face_start = face_offset
            object_corner_start = corner_offset

            for vertex_index in range(1, vertex_count + 1):
                world_point = _point_world(temp, poly, vertex_index)
                coords_xyz.extend(_max_zup_to_rizom_yup(world_point))

            for face_index in range(1, face_count + 1):
                verts = _face_vertices(poly, face_index)
                poly_sizes.append(len(verts))
                poly_xyz_ids.extend(vertex_offset + (v - 1) for v in verts)

            if existing_uvs:
                if not _map_supported(poly, channel):
                    raise RuntimeError(
                        f"Object '{source.name}' does not have UV channel {channel}."
                    )

                map_vert_count = int(rt.polyop.getNumMapVerts(poly, channel))
                for map_index in range(1, map_vert_count + 1):
                    uvw = rt.polyop.getMapVert(poly, channel, map_index)
                    coords_uvw.extend((float(uvw.x), float(uvw.y), float(uvw.z)))

                for face_index in range(1, face_count + 1):
                    face_verts = _face_vertices(poly, face_index)
                    map_face = [
                        int(v)
                        for v in rt.polyop.getMapFace(poly, channel, face_index)
                    ]
                    if len(map_face) != len(face_verts):
                        raise RuntimeError(
                            f"UV topology mismatch on '{source.name}', face {face_index}."
                        )
                    poly_uvw_ids.extend(uv_offset + (v - 1) for v in map_face)

                uv_offset += map_vert_count
            else:
                # Rizom-Lab's fileless example recommends non-zero seed UVWs.
                # Use the 3D coordinates as the initial UVW topology.
                object_uv_offset = uv_offset
                for vertex_index in range(1, vertex_count + 1):
                    world_point = _point_world(temp, poly, vertex_index)
                    coords_uvw.extend(_max_zup_to_rizom_yup(world_point))

                for face_index in range(1, face_count + 1):
                    verts = _face_vertices(poly, face_index)
                    poly_uvw_ids.extend(
                        object_uv_offset + (v - 1) for v in verts
                    )

                uv_offset += vertex_count

            corner_count = sum(local_face_sizes)
            object_sessions.append(
                ObjectSession(
                    handle=int(rt.getHandleByAnim(source)),
                    name=str(source.name),
                    face_start=object_face_start,
                    face_count=face_count,
                    corner_start=object_corner_start,
                    corner_count=corner_count,
                    face_sizes=local_face_sizes,
                    local_poly_xyz_ids=local_xyz_ids,
                )
            )

            vertex_offset += vertex_count
            face_offset += face_count
            corner_offset += corner_count
        finally:
            _delete_node(temp)

    session = BridgeSession(
        uv_channel=channel,
        poly_sizes=list(poly_sizes),
        poly_xyz_ids=list(poly_xyz_ids),
        objects=object_sessions,
    )

    params = {
        "Data.PolySizes": poly_sizes,
        "Data.PolyXYZIDs": poly_xyz_ids,
        "Data.CoordsXYZ": coords_xyz,
        "Data.PolyUVWIDs": poly_uvw_ids,
        "Data.CoordsUVW": coords_uvw,
        "__Focus": True,
    }
    return session, params


def _current_source_node(handle: int):
    try:
        node = rt.getAnimByHandle(handle)
        if node is not None and rt.isValidNode(node):
            return node
    except Exception:
        pass
    return None


def _validate_source_topology(source, item: ObjectSession):
    temp = _make_evaluated_poly_copy(source)
    try:
        face_sizes, local_ids = _extract_local_topology(temp.baseObject)
        return face_sizes == item.face_sizes and local_ids == item.local_poly_xyz_ids
    finally:
        _delete_node(temp)


def _apply_uv_data_to_temp(temp, channel: int, uvw_ids: Sequence[int], coords_uvw: Sequence[float]):
    poly = temp.baseObject
    face_count = int(rt.polyop.getNumFaces(poly))

    used_global_ids: List[int] = []
    global_to_local = {}
    local_uvs: List[Tuple[float, float, float]] = []
    local_face_ids: List[List[int]] = []

    cursor = 0
    for face_index in range(1, face_count + 1):
        degree = len(_face_vertices(poly, face_index))
        face_global_ids = [int(v) for v in uvw_ids[cursor : cursor + degree]]
        cursor += degree

        local_face = []
        for global_id in face_global_ids:
            if global_id < 0:
                raise RuntimeError("RizomUV returned a negative UV vertex id.")
            if global_id not in global_to_local:
                coord_index = global_id * 3
                if coord_index + 2 >= len(coords_uvw):
                    raise RuntimeError("RizomUV returned an out-of-range UV vertex id.")
                global_to_local[global_id] = len(used_global_ids) + 1
                used_global_ids.append(global_id)
                local_uvs.append(
                    (
                        float(coords_uvw[coord_index]),
                        float(coords_uvw[coord_index + 1]),
                        float(coords_uvw[coord_index + 2]),
                    )
                )
            local_face.append(global_to_local[global_id])

        local_face_ids.append(local_face)

    if cursor != len(uvw_ids):
        raise RuntimeError("Returned UV corner count does not match evaluated topology.")

    rt.polyop.setMapSupport(poly, channel, True)
    rt.polyop.setNumMapVerts(poly, channel, len(local_uvs), keep=False)

    for map_index, uvw in enumerate(local_uvs, start=1):
        rt.polyop.setMapVert(poly, channel, map_index, rt.Point3(*uvw))

    for face_index, face_map_ids in enumerate(local_face_ids, start=1):
        rt.polyop.setMapFace(poly, channel, face_index, rt.Array(*face_map_ids))


def _paste_channel_from_temp(temp, source, channel: int):
    rt.ChannelInfo.CopyChannel(temp, 3, channel)
    rt.ChannelInfo.PasteChannel(source, 3, channel)


def send_to_rizom(existing_uvs: bool, channel: int):
    global _session

    nodes = _selected_geometry()
    if not nodes:
        raise RuntimeError("Select at least one geometry object in 3ds Max.")

    session, params = _extract_payload(nodes, channel, existing_uvs)
    link = _ensure_link()

    try:
        link.Load(params)
    except Exception as exc:
        raise RuntimeError(f"RizomUVLink Load failed: {exc}") from exc

    _session = session
    rt.redrawViews()

    mode = "Edit UV" if existing_uvs else "New UV"
    return (
        f"{mode}: sent {len(nodes)} object(s) directly to RizomUV. "
        "No FBX/OBJ file was created."
    )


def get_uvs_from_rizom():
    global _session

    if _session is None:
        raise RuntimeError("No active bridge session. Use Send New UV or Send Edit UV first.")

    link = _ensure_link()

    try:
        output = link.Save({"Data": True})
    except Exception as exc:
        raise RuntimeError(f"RizomUVLink Save(Data=True) failed: {exc}") from exc

    data = output.get("Data") if isinstance(output, dict) else None
    if not isinstance(data, dict):
        raise RuntimeError("RizomUVLink did not return a Data payload.")

    returned_sizes = [int(v) for v in data.get("PolySizes", [])]
    returned_xyz_ids = [int(v) for v in data.get("PolyXYZIDs", [])]

    if returned_sizes != _session.poly_sizes:
        raise RuntimeError(
            "Geometry topology changed in RizomUV: polygon sizes differ. "
            "UV transfer was blocked."
        )

    if returned_xyz_ids and returned_xyz_ids != _session.poly_xyz_ids:
        raise RuntimeError(
            "Geometry topology changed in RizomUV: polygon vertex ids differ. "
            "UV transfer was blocked."
        )

    poly_uvw_ids = [int(v) for v in data.get("PolyUVWIDs", [])]
    coords_uvw = [float(v) for v in data.get("CoordsUVW", [])]

    if len(poly_uvw_ids) != len(_session.poly_xyz_ids):
        raise RuntimeError(
            "RizomUV returned a different UV corner count. UV transfer was blocked."
        )

    applied = 0
    blocked = []

    for item in _session.objects:
        source = _current_source_node(item.handle)
        if source is None:
            blocked.append(f"{item.name}: source object no longer exists")
            continue

        if not _validate_source_topology(source, item):
            blocked.append(f"{item.name}: source topology changed after Send")
            continue

        uv_segment = poly_uvw_ids[
            item.corner_start : item.corner_start + item.corner_count
        ]

        temp = _make_evaluated_poly_copy(source)
        try:
            _apply_uv_data_to_temp(
                temp,
                _session.uv_channel,
                uv_segment,
                coords_uvw,
            )
            _paste_channel_from_temp(temp, source, _session.uv_channel)
            applied += 1
        except Exception as exc:
            blocked.append(f"{item.name}: {exc}")
        finally:
            _delete_node(temp)

    rt.redrawViews()

    if blocked:
        raise RuntimeError(
            f"Applied UVs to {applied} object(s); blocked {len(blocked)} object(s):\n"
            + "\n".join(blocked)
        )

    return f"UV channel {_session.uv_channel} applied to {applied} object(s)."


def connection_info():
    link_dir = _find_rizom_install_dir() / "RizomUVLink"
    return (
        f"3ds Max Python: {sys.version.split()[0]}\n"
        f"RizomUVLink: {link_dir}\n"
        "Transport: direct memory/API (no FBX/OBJ)"
    )


class BridgeDialog(QtWidgets.QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("RizomUV Bridge 2027")
        self.setWindowFlags(self.windowFlags() | QtCore.Qt.WindowType.Tool)
        self.setMinimumWidth(360)

        self.version_label = QtWidgets.QLabel(
            f"Version {VERSION} — Direct RizomUVLink"
        )
        self.status_label = QtWidgets.QLabel("Ready")
        self.status_label.setWordWrap(True)

        self.channel = QtWidgets.QSpinBox()
        self.channel.setRange(1, 99)
        self.channel.setValue(1)

        form = QtWidgets.QFormLayout()
        form.addRow("UV channel:", self.channel)

        self.send_new = QtWidgets.QPushButton("Send New UV")
        self.send_edit = QtWidgets.QPushButton("Send Edit UV")
        self.get_uvs = QtWidgets.QPushButton("Get UVs")
        self.info = QtWidgets.QPushButton("Connection Info")

        send_row = QtWidgets.QHBoxLayout()
        send_row.addWidget(self.send_new)
        send_row.addWidget(self.send_edit)

        get_row = QtWidgets.QHBoxLayout()
        get_row.addWidget(self.get_uvs)
        get_row.addWidget(self.info)

        layout = QtWidgets.QVBoxLayout(self)
        layout.addWidget(self.version_label)
        layout.addWidget(self.status_label)
        layout.addLayout(form)
        layout.addLayout(send_row)
        layout.addLayout(get_row)

        self.send_new.clicked.connect(lambda: self._send(False))
        self.send_edit.clicked.connect(lambda: self._send(True))
        self.get_uvs.clicked.connect(self._get)
        self.info.clicked.connect(self._info)

    def _run(self, label, fn):
        self.status_label.setText(label)
        QtWidgets.QApplication.processEvents()
        try:
            message = fn()
            self.status_label.setText(message)
        except Exception as exc:
            self.status_label.setText(str(exc))
            QtWidgets.QMessageBox.critical(self, "RizomUVBridge", str(exc))

    def _send(self, existing_uvs):
        self._run(
            "Connecting and sending topology...",
            lambda: send_to_rizom(existing_uvs, int(self.channel.value())),
        )

    def _get(self):
        self._run("Reading UVs directly from RizomUV...", get_uvs_from_rizom)

    def _info(self):
        self._run("Checking connection...", connection_info)


def show():
    global _dialog

    if _dialog is not None:
        try:
            _dialog.show()
            _dialog.raise_()
            _dialog.activateWindow()
            return _dialog
        except RuntimeError:
            _dialog = None

    _dialog = BridgeDialog(GetQMaxMainWindow())
    _dialog.show()
    return _dialog


def shutdown():
    global _dialog, _link, _session

    if _dialog is not None:
        try:
            _dialog.close()
        except Exception:
            pass
        _dialog = None

    if _link is not None:
        try:
            _link.Quit({})
        except Exception:
            pass
        _link = None

    _session = None
