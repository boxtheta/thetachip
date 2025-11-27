# SPDX-License-Identifier: GPL-3

import csv
from enum import StrEnum
from typing import Type

import tomlkit
import tomlkit.items as toml_types


class DefTypes(StrEnum):
    Consts = "consts"
    Opcodes = "opcodes"


def get_checked(
    data: tomlkit.TOMLDocument | toml_types.Table, key: str, t: Type
) -> toml_types.ItemT:  # pyright: ignore[reportInvalidTypeVarUse]
    v = data.get(key)
    if isinstance(v, t):
        return v  # pyright: ignore[reportReturnType]
    elif not v:
        raise ValueError(f"Key '{key}' is missing or empty")
    else:
        raise ValueError(f"Key '{key}' has an invalid value")


def pad_hex(n: int, pad: int, add_prefix: bool = True, upper: bool = True) -> str:
    s = hex(n)[2:].zfill(pad)
    s = s.upper() if upper else s
    if add_prefix:
        return "0x" + s
    else:
        return s


def handle_consts(defs: tomlkit.TOMLDocument, meta: toml_types.Table, out_file: str):
    items = []
    prefix_bits = get_checked(meta, "Prefix_Bits", int)
    entry_bit_len = get_checked(meta, "Entry_Bit_Len", int)
    groups = get_checked(defs, "Groups", toml_types.Table)
    prefix_shift = entry_bit_len - prefix_bits
    for name, data in groups.items():
        prefix = data["Prefix"]
        base_mask = prefix << prefix_shift
        for i, error in enumerate(data["Items"]):
            e_code = base_mask | i
            items.append((pad_hex(e_code, 4), f"{name}_{error}"))
    with open(out_file, "w+", encoding="utf-8") as f:
        cw = csv.writer(f, dialect="excel")
        cw.writerows(items)
    print("Made table with", len(items))


def handle_opcodes(defs: tomlkit.TOMLDocument, meta: toml_types.Table, out_file: str):
    items = []
    prefix_bits = get_checked(meta, "Prefix_Bits", int)
    entry_bit_len = get_checked(meta, "Entry_Bit_Len", int)
    var_bit_len = get_checked(meta, "Variable", int)
    groups = get_checked(defs, "Groups", toml_types.Table)
    prefix_shift = entry_bit_len - prefix_bits

    i = 0
    for group, data in groups.items():
        prefix = data["Prefix"]
        base_mask = prefix << prefix_shift
        for t in get_checked(data, "Items", toml_types.Array):
            name = t["Name"]
            desc = t["Desc"]
            op_code = base_mask | (i << var_bit_len)
            items.append((pad_hex(op_code, 8), group, name, desc))
            i += 1
    with open(out_file, "w+", encoding="utf-8") as f:
        cw = csv.writer(f, dialect="excel")
        cw.writerows(items)
    print("Made table with", len(items), "lines")


def main(def_file: str, out_file: str) -> None:
    defs = None
    try:
        with open(def_file, "r", encoding="utf-8") as f:
            defs = tomlkit.load(f)
    except Exception as e:
        print(e)
        exit(1)

    meta = get_checked(defs, "Meta", toml_types.Table)
    type = get_checked(meta, "Type", toml_types.String)

    if type == DefTypes.Consts.value:
        handle_consts(defs, meta, out_file)
    elif type == DefTypes.Opcodes.value:
        handle_opcodes(defs, meta, out_file)
    else:
        raise ValueError(f"Invalid type '{type}'")


if __name__ == "__main__":
    import sys

    main(sys.argv[1], sys.argv[2])
