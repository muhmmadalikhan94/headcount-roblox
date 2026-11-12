"""Build HEADCOUNT.rbxlx from default.project.json without needing Rojo.

    python tools/build_place.py

Double-click the resulting HEADCOUNT.rbxlx to open it in Roblox Studio.
Supports the subset of Rojo's project format this repo uses: $className, $path,
$properties (bool / number / string / known enum names), and the file naming
rules *.server.luau -> Script, *.client.luau -> LocalScript, *.luau -> ModuleScript.
"""

import json
import os
import sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENUMS = {"Technology": {"Legacy": 0, "Voxel": 1, "Compatibility": 2, "ShadowMap": 3, "Future": 4}}

_ref = 0


def next_ref():
    global _ref
    _ref += 1
    return f"RBX{_ref:08X}"


def prop_xml(name, value):
    if isinstance(value, bool):
        return f'<bool name="{name}">{"true" if value else "false"}</bool>'
    if name in ENUMS:
        return f'<token name="{name}">{ENUMS[name][value]}</token>'
    if isinstance(value, int):
        return f'<int name="{name}">{value}</int>'
    if isinstance(value, float):
        return f'<float name="{name}">{value}</float>'
    return f'<string name="{name}">{escape(str(value))}</string>'


def source_xml(source):
    return "<ProtectedString name=\"Source\"><![CDATA[" + source.replace("]]>", "]]]]><![CDATA[>") + "]]></ProtectedString>"


def item(class_name, name, props, children, source=None):
    lines = [f'<Item class="{class_name}" referent="{next_ref()}">', "<Properties>", f'<string name="Name">{escape(name)}</string>']
    for key, value in props.items():
        lines.append(prop_xml(key, value))
    if source is not None:
        lines.append(source_xml(source))
    lines.append("</Properties>")
    lines.extend(children)
    lines.append("</Item>")
    return "\n".join(lines)


def script_for(filename):
    for suffix, cls in ((".server.luau", "Script"), (".client.luau", "LocalScript"), (".luau", "ModuleScript")):
        if filename.endswith(suffix):
            return filename[: -len(suffix)], cls
    return None, None


def from_path(name, path):
    full = os.path.join(ROOT, path)
    if os.path.isfile(full):
        script_name, cls = script_for(os.path.basename(full))
        with open(full, encoding="utf-8") as f:
            return item(cls, name, {}, [], f.read())
    children = []
    for entry in sorted(os.listdir(full)):
        child = os.path.join(full, entry)
        if os.path.isdir(child):
            children.append(from_path(entry, os.path.join(path, entry)))
        else:
            script_name, cls = script_for(entry)
            if cls:
                with open(child, encoding="utf-8") as f:
                    children.append(item(cls, script_name, {}, [], f.read()))
    return item("Folder", name, {}, children)


def from_node(name, node):
    if "$path" in node:
        return from_path(name, node["$path"])
    children = [from_node(k, v) for k, v in node.items() if not k.startswith("$")]
    return item(node.get("$className", "Folder"), name, node.get("$properties", {}), children)


def main():
    with open(os.path.join(ROOT, "default.project.json"), encoding="utf-8") as f:
        project = json.load(f)
    tree = project["tree"]
    services = [from_node(k, v) for k, v in tree.items() if not k.startswith("$")]
    xml = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        "<External>null</External>\n<External>nil</External>\n" + "\n".join(services) + "\n</roblox>\n"
    )
    out = os.path.join(ROOT, project["name"] + ".rbxlx")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(xml)
    print(f"Built {os.path.relpath(out, ROOT)} ({len(xml) // 1024} KB)")


if __name__ == "__main__":
    sys.exit(main())
