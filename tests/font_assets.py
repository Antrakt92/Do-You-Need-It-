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
    manifest = json.loads((ROOT / "fonts/manifest.json").read_text(encoding="utf-8-sig"))
    assert len(manifest["fonts"]) == 46
    russian = set(map(ord, "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя"))
    western = set(map(ord, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåæçèéêëìíîïñòóôõöùúûüýÿŒœß"))
    # Asian coverage promises the actual translated interface, not every Han glyph.
    samples = {"hans": "设置语言字体大小延迟低高自动密语简体中文", "hant": "設定語言字型大小延遲低高自動密語繁體中文", "hangul": "설정언어글꼴크기지연낮음높자동귓속말한국어"}
    core = (ROOT / "DoYouNeedIt_Core.lua").read_text(encoding="utf-8-sig")
    visible = core.split("local visibleLocaleLabels = {", 1)[1].split("\n}", 1)[0]
    for locale, script in [("zhCN", "hans"), ("zhTW", "hant"), ("koKR", "hangul")]:
        match = re.search(r"^    " + locale + r" = \{ (.*?) \},$", visible, re.M)
        values = json.loads("[" + match.group(1) + "]")
        samples[script] += "".join(values)
    statuses = core.split("local statusLocaleLabels = {", 1)[1].split("\n}", 1)[0]
    for locale, script in [("zhCN", "hans"), ("zhTW", "hant"), ("koKR", "hangul")]:
        match = re.search(r"^    " + locale + r" = \{ (.*?) \},$", statuses, re.M)
        samples[script] += "".join(json.loads("[" + match.group(1) + "]"))
    helps = core.split("local helpLocaleLabels = {", 1)[1].split("\n}", 1)[0]
    for locale, script in [("zhCN", "hans"), ("zhTW", "hant"), ("koKR", "hangul")]:
        match = re.search(r"^    " + locale + r" = \{ (.*?) \},$", helps, re.M)
        samples[script] += "".join(json.loads("[" + match.group(1) + "]"))
    favorites = core.split("local favoriteLocaleLabels = {", 1)[1].split("\n}", 1)[0]
    for locale, script in [("zhCN", "hans"), ("zhTW", "hant"), ("koKR", "hangul")]:
        match = re.search(r"^    " + locale + r" = \{ (.*?) \},$", favorites, re.M)
        samples[script] += "".join(json.loads("[" + match.group(1) + "]"))
    developer_links = core.split("local developerLinkLocaleLabels = {", 1)[1].split("\n}", 1)[0]
    for locale, script in [("zhCN", "hans"), ("zhTW", "hant"), ("koKR", "hangul")]:
        match = re.search(r"^    " + locale + r" = \{ (.*?) \},$", developer_links, re.M)
        samples[script] += "".join(json.loads("[" + match.group(1) + "]"))
    accents = {"enUS": "", "deDE": "äöüß", "esES": "áéíóúüñ", "esMX": "áéíóúüñ", "frFR": "àâçéèêëîïôùûüÿœæ", "itIT": "àèéìòù", "ptBR": "áàâãçéêíóôõú"}
    demos = core.split("local demoLocaleLabels = {", 1)[1].split("\n}", 1)[0]
    for locale, script in [("zhCN", "hans"), ("zhTW", "hant"), ("koKR", "hangul")]:
        match = re.search(r"^    " + locale + r" = \{ (.*?) \},$", demos, re.M)
        samples[script] += "".join(json.loads("[" + match.group(1) + "]"))
    western_labels = {locale: "" for locale in accents}
    for table_name in ("visibleLocaleLabels", "statusLocaleLabels", "helpLocaleLabels", "favoriteLocaleLabels", "developerLinkLocaleLabels", "demoLocaleLabels"):
        table = core.split("local " + table_name + " = {", 1)[1].split("\n}", 1)[0]
        for locale in western_labels:
            match = re.search(r"^    " + locale + r" = \{ (.*?) \},$", table, re.M)
            if match:
                western_labels[locale] += "".join(json.loads("[" + match.group(1) + "]"))
    checked = 0
    for font in manifest["fonts"]:
        data = (ROOT / font["path"]).read_bytes()
        assert hashlib.sha256(data).hexdigest().upper() == font["sha256"], font["path"]
        license_text = (ROOT / font["licenseFile"]).read_text(encoding="utf-8-sig")
        assert hashlib.sha256(license_text.encode()).hexdigest().upper() == font["licenseSha256"], font["licenseFile"]
        characters = character_map(data)
        if font["cyrillic"]:
            assert russian <= characters, (font["name"], "Cyrillic")
        if font.get("latin", True):
            # Only the accents used by supported European languages are promised.
            required = western - set(map(ord, "ÅåÆæØøÝýÿ"))
            assert required <= characters, (font["name"], "western", sorted(required - characters))
        for locale, text in western_labels.items():
            if font.get("latin", True) or locale in font.get("latinLocales", []):
                assert set(map(ord, text)) <= characters, (font["name"], locale, sorted(set(map(ord, text)) - characters))
        for locale in font.get("latinLocales", []):
            sample = accents[locale] + accents[locale].upper()
            assert set(map(ord, sample)) <= characters, (font["name"], locale, sorted(set(map(ord, sample)) - characters))
        for script, text in samples.items():
            if font.get(script):
                assert set(map(ord, text)) <= characters, (font["name"], script, sorted(set(map(ord, text)) - characters))
        checked += 1
    print(f"font assets: {checked} hashes, license hashes and character maps verified")


if __name__ == "__main__":
    main()
