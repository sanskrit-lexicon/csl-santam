#!/usr/bin/env python3
"""Re-export ganz.txt to a clean-UTF-8 file with an explicit dict-code column.

Mirrors the per-row `iconv("Windows-1252","UTF-8", $en)` workaround already
live at php/recherche.php:97, applied uniformly to both `st` and `en` so every
row is valid UTF-8 (not just `en`, which is all the PHP renderer touches).
Run from the sqlite/ directory: `python normalize_utf8.py`.
"""
import sys

SRC = "ganz.txt"
DST = "ganz_utf8.txt"
BOOKS = "../dat/books"


def load_dict_codes(path):
    codes = {}
    with open(path, "r", encoding="ascii") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            num, code, _name = line.split(" ", 2)
            codes[num] = code
    return codes


def decode_field(raw: bytes) -> str:
    # Byte 0x81 is undefined in Windows-1252 (iconv() raises/fails on it in
    # the live PHP workaround) but always represents 'ü' in this corpus
    # (e.g. "Bühler", "über", "wünschen") -- remap before decoding so those
    # 6 rows survive instead of dropping their `en` field, as they currently
    # do on the live site.
    fixed = raw.replace(b"\x81", b"\xfc")
    return fixed.decode("cp1252")


def main():
    codes = load_dict_codes(BOOKS)
    data = open(SRC, "rb").read()
    rows = data.split(b"\r\n")
    if rows and rows[-1] == b"":
        rows.pop()

    with open(DST, "w", encoding="utf-8", newline="\n") as out:
        for row in rows:
            idb, stb, enb = row.split(b"\t")
            num = idb.decode("ascii")
            code = codes[num]
            st = decode_field(stb)
            en = decode_field(enb)
            out.write(f"{num}\t{code}\t{st}\t{en}\n")

    print(f"wrote {len(rows)} rows to {DST}")


if __name__ == "__main__":
    sys.exit(main())
