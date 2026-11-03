"""Verify bundled font provenance and advertised glyphs without external libraries."""
from pathlib import Path
import hashlib
import json
import struct
import re

ROOT = Path(__file__).resolve().parents[1]


def character_map(data):
    u16 = lambda pos: struct.unpack_from(">H", data, pos)[0]
    u32 = lambda pos: struct.unpack_from(">I", data, pos)[0]
    table = None
    for index in range(u16(4)):
        record = 12 + index * 16
        if data[record:record + 4] == b"cmap":
            table = u32(record + 8)
            break
    assert table is not None, "missing cmap"
    result = set()
    for index in range(u16(table + 2)):
        record = table + 4 + index * 8
        platform, encoding = u16(record), u16(record + 2)
        if platform != 0 and not (platform == 3 and encoding in (1, 10)):
            continue
        start = table + u32(record + 4)
        kind = u16(start)
        if kind == 12:
            for group in range(u32(start + 12)):
                first, last, glyph = struct.unpack_from(">III", data, start + 16 + group * 12)
                result.update(range(first + (glyph == 0), last + 1))
        elif kind == 4:
            count = u16(start + 6) // 2
            end_base = start + 14
            start_base = end_base + count * 2 + 2
            delta_base = start_base + count * 2
            range_base = delta_base + count * 2
            for segment in range(count):
                first, last = u16(start_base + segment * 2), u16(end_base + segment * 2)
                delta = u16(delta_base + segment * 2)
                offset = u16(range_base + segment * 2)
                for codepoint in range(first, min(last, 65534) + 1):
                    if offset:
                        glyph = u16(range_base + segment * 2 + offset + (codepoint - first) * 2)
                        if glyph:
                            glyph = (glyph + delta) & 65535
                    else:
                        glyph = (codepoint + delta) & 65535
                    if glyph:
                        result.add(codepoint)
    return result


def main():
    import subprocess
    import shutil
    export = json.loads((ROOT / "scripts/shared-font-export.json").read_text(encoding="utf-8"))
    for name, expected in export["modules"].items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == expected, name
    inventory = json.loads((ROOT / "scripts/baseline-files.json").read_text(encoding="utf-8"))
    for name, expected in inventory["files"].items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == expected, name
    binaries = sorted(str(path.relative_to(ROOT)).replace("\\", "/") for path in (ROOT / "fonts").glob("*.[to]tf"))
    assert binaries == ["fonts/AntraktUISans.ttf"], binaries
    data = (ROOT / "fonts/AntraktUISans.ttf").read_bytes()
    assert hashlib.sha256(data).hexdigest() == export["baseline"]["sha256"]
    characters = character_map(data)
    script = r'''dofile("DoYouNeedIt_Core.lua")
local labels
for index = 1, 20 do
    local name, value = debug.getupvalue(DoYouNeedItCore.GetLocaleLabel, index)
    if name == "LABELS_BY_LOCALE" then labels = value end
end
assert(type(labels) == "table")
local count = 0
for _, values in pairs(labels) do
    count = count + 1
    for _, text in pairs(values) do if type(text) == "string" then io.write(text, "\n") end end
end
assert(count == 11)
for _, option in ipairs(DoYouNeedItCore.GetLanguageOptions()) do
    if option.label then io.write(option.label, "\n") end
end
local catalog = assert(loadfile("AntraktFontCatalog.lua"))()
for _, values in pairs(catalog.messages) do
    for _, text in pairs(values) do io.write(text, "\n") end
end
'''
    corpus = subprocess.check_output([shutil.which("lua5.1"), "-e", script], cwd=ROOT).decode("utf-8")
    required = {ord(char) for char in corpus if ord(char) >= 32}
    for name in ("DoYouNeedIt.lua", "DoYouNeedIt_Core.lua", "DoYouNeedIt_Forever.lua", "DoYouNeedIt_FontPackUI.lua"):
        required.update(ord(char) for char in (ROOT / name).read_text(encoding="utf-8-sig") if ord(char) > 127)
    assert required <= characters, [f"U+{code:04X}" for code in sorted(required - characters)]
    print(f"Baseline: exact module/material hashes, one font, {len(required)} live UI codepoints verified")


if __name__ == "__main__":
    main()
