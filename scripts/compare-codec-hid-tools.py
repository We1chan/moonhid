#!/usr/bin/env python3
"""Compare generated descriptors and encoded reports with hid-tools 0.12."""
import json
from importlib.metadata import version
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory

from hidtools.hid import ReportDescriptor

ROOT = Path(__file__).resolve().parent.parent
CASES = (
    ("mouse", "input", 0, "mouse-values.json"),
    ("keyboard", "input", 0, None),
    ("keyboard", "output", 0, "keyboard-led-values.json"),
    ("gamepad", "input", 7, "gamepad-values.json"),
)


def main():
    subprocess.run(
        ["moon", "build", "src/cmd/moonhid", "--target", "native", "--release"],
        cwd=ROOT, check=True,
    )
    executables = list((ROOT / "_build/native/release/build/cmd/moonhid").glob("*.exe"))
    if len(executables) != 1:
        raise RuntimeError(f"Expected one native CLI, found {executables}")

    def cli(*args):
        return subprocess.run(
            [str(executables[0]), *args], cwd=ROOT,
            check=True, capture_output=True, text=True,
        ).stdout.strip()

    results = []
    with TemporaryDirectory(prefix="moonhid-codec-") as directory:
        descriptor_path = Path(directory) / "descriptor.hex"
        values_path = Path(directory) / "values.json"
        for template, kind, report_id, values_file in CASES:
            descriptor_hex = cli("generate", template)
            reference_hex = (ROOT / "examples/codec" / f"{template}.hex").read_text()
            if bytes.fromhex(descriptor_hex) != bytes.fromhex(reference_hex):
                raise AssertionError(f"{template}: generated descriptor differs from fixture")
            parsed = ReportDescriptor.from_bytes(bytes.fromhex(descriptor_hex))
            report = getattr(parsed, kind + "_reports")[report_id or -1]
            values = (
                json.loads((ROOT / "examples/codec" / values_file).read_text())
                if values_file else [0, 1, 0, 0, 0, 0, 0, 0, 4, 6, 0, 0, 0, 0]
            )
            descriptor_path.write_text(descriptor_hex)
            values_path.write_text(json.dumps(values))
            moon_wire = bytes.fromhex(cli(
                "encode", "--kind", kind, "--id", str(report_id),
                str(descriptor_path), str(values_path),
            ))
            independent = [0] * report.size
            if report_id:
                independent[0] = report_id
            index = 0
            decoded = []
            for field in report.fields:
                if field.is_const:
                    continue
                field.fill_values(independent, values[index:index + field.count])
                decoded.extend(field.get_values(list(moon_wire)))
                index += field.count
            if index != len(values) or bytes(independent) != moon_wire or decoded != values:
                raise AssertionError(f"{template} {kind}: independent codec mismatch")
            results.append({"template": template, "kind": kind, "report_id": report_id, "wire_hex": moon_wire.hex(" ")})
    print(json.dumps({"tool": "hid-tools", "version": version("hid-tools"), "codec_cases": results}, indent=2))


if __name__ == "__main__":
    main()
