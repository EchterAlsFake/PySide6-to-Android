#!/usr/bin/env python3
"""Check Android wheel archives for target ELF architecture and 16 KiB alignment."""

import argparse
import struct
import sys
import zipfile
from pathlib import Path


MACHINES = {"aarch64": 183, "armv7a": 40, "i686": 3, "x86_64": 62}


def check_elf(data: bytes, expected_machine: int, label: str) -> None:
    if data[:4] != b"\x7fELF" or data[5] != 1:
        raise ValueError(f"{label}: missing little-endian ELF header")
    elf_class = data[4]
    if elf_class == 2:
        header = struct.unpack_from("<HHIQQQIHHHHHH", data, 16)
        machine, phoff, phentsize, phnum = header[1], header[4], header[8], header[9]
        alignment_offset = 48
    elif elf_class == 1:
        header = struct.unpack_from("<HHIIIIIHHHHHH", data, 16)
        machine, phoff, phentsize, phnum = header[1], header[4], header[8], header[9]
        alignment_offset = 28
    else:
        raise ValueError(f"{label}: unsupported ELF class {elf_class}")
    if machine != expected_machine:
        raise ValueError(f"{label}: ELF machine {machine}, expected {expected_machine}")
    if phoff + phnum * phentsize > len(data):
        raise ValueError(f"{label}: truncated program headers")
    loads = 0
    for index in range(phnum):
        offset = phoff + index * phentsize
        if struct.unpack_from("<I", data, offset)[0] == 1:
            loads += 1
            alignment = struct.unpack_from("<I" if elf_class == 1 else "<Q", data,
                                           offset + alignment_offset)[0]
            if alignment < 0x4000:
                raise ValueError(f"{label}: PT_LOAD alignment {alignment:#x} < 0x4000")
    if not loads:
        raise ValueError(f"{label}: no PT_LOAD segments")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--python-version", required=True)
    parser.add_argument("--abi", choices=MACHINES, required=True)
    parser.add_argument("wheels", nargs="+", type=Path)
    args = parser.parse_args()
    tag = f"cp{args.python_version.replace('.', '')}-cp{args.python_version.replace('.', '')}"
    projects = {wheel.name.split("-", 1)[0].lower() for wheel in args.wheels}
    if projects != {"pyside6", "shiboken6"} or len(args.wheels) != 2:
        parser.error("expected exactly one PySide6 and one Shiboken6 wheel")
    count = 0
    for wheel in args.wheels:
        if tag not in wheel.name or f"android_{args.abi}" not in wheel.name:
            parser.error(f"wrong Python or ABI wheel tag: {wheel.name}")
        with zipfile.ZipFile(wheel) as archive:
            if archive.testzip() is not None:
                raise ValueError(f"corrupt archive: {wheel}")
            for name in archive.namelist():
                if name.endswith(".so") or ".so." in name:
                    check_elf(archive.read(name), MACHINES[args.abi], f"{wheel.name}:{name}")
                    count += 1
    if not count:
        raise ValueError("no shared libraries found in wheels")
    print(f"Validated {len(args.wheels)} wheels and {count} Android ELF files ({tag}, {args.abi}).")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, zipfile.BadZipFile) as error:
        sys.exit(str(error))
