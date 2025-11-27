import csv
from enum import StrEnum
from typing import Any, Literal, Type

import tomlkit
import tomlkit.items as ttypes


class DefTypes(StrEnum):
    Consts = "consts"
    Opcodes = "opcodes"


def get_checked(
    data: tomlkit.TOMLDocument | ttypes.Table, key: str, t: Type
) -> ttypes.ItemT:
    v = data.get(key)
    if isinstance(v, t):
        return v  # pyright: ignore[reportReturnType]
    elif not v:
        raise ValueError(f"Key '{key}' is missing or empty")
    else:
        raise ValueError(f"Key '{key}' has an invalid value")


def handle_consts(defs: tomlkit.TOMLDocument, meta: ttypes.Table, out_file: str):
    items = []
    prefix_bits = get_checked(meta, "Prefix_Bits", int)
    entry_bit_len = get_checked(meta, "Entry_Bit_Len", int)
    groups = get_checked(defs, "Groups", ttypes.Table)
    prefix_shift = entry_bit_len - prefix_bits
    for name, data in groups.items():
        prefix = data["Prefix"]
        base_mask = prefix << prefix_shift
        for i, error in enumerate(data["Items"]):
            e_code = base_mask | i
            items.append(("0x{:04X}".format(e_code), f"{name}_{error}"))
    with open(out_file, "w+", encoding="utf-8") as f:
        cw = csv.writer(f, dialect="excel")
        cw.writerows(items)
    print(items)


def main(def_file: str, out_file: str) -> None:
    defs = None
    try:
        with open(def_file, "r", encoding="utf-8") as f:
            defs = tomlkit.load(f)
    except Exception as e:
        print(e)
        exit(1)

    meta = get_checked(defs, "Meta", ttypes.Table)
    type = get_checked(meta, "Type", ttypes.String)

    if type == DefTypes.Consts.value:
        handle_consts(defs, meta, out_file)
    elif type == DefTypes.Opcodes.value:
        pass
    else:
        raise ValueError(f"Invalid type '{type}'")


if __name__ == "__main__":
    import sys

    main(sys.argv[1], sys.argv[2])
