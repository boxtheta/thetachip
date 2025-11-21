import csv

import tomlkit


def main(def_file: str, out_file: str) -> None:
    defs = None
    with open(def_file, "r", encoding="utf-8") as f:
        defs = tomlkit.load(f)

    items = []
    prefix_bits = defs["Prefix_Bits"]
    entry_bit_len = defs["Entry_Bit_Len"]
    prefix_shift = entry_bit_len - prefix_bits
    for name, data in defs["Groups"].items():
        prefix = data["Prefix"]
        base_mask = prefix << prefix_shift
        for i, error in enumerate(data["Items"]):
            e_code = base_mask | i
            items.append(("0x{:04X}".format(e_code), f"{name}_{error}"))
    with open(out_file, "w+", encoding="utf-8") as f:
        cw = csv.writer(f, dialect="excel")
        cw.writerows(items)
    print(items)


if __name__ == "__main__":
    import sys

    main(sys.argv[1], sys.argv[2])
