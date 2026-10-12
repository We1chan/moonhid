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
    ("consumer", "input", 0, "consumer-values.json"),
    ("vendor", "input", 0, "vendor-values.json"),
    ("vendor", "output", 0, "vendor-values.json"),
)
# Usage-form edits; hid-tools places them with its own Usage lists and bit offsets.
USAGE_CASES = (
    ("keyboard", "input", 0, "keyboard-usages.json"),
    ("keyboard", "output", 0, {"active": [{"page": 8, "id": 1}, {"page": 8, "id": 2}]}),
    ("mouse", "input", 0, {
        "values": [{"page": 1, "id": 0x30, "value": -1}, {"page": 1, "id": 0x31, "value": 2},
                   {"page": 1, "id": 0x38, "value": -2}],
        "active": [{"page": 9, "id": 1}, {"page": 9, "id": 3}],
    }),
    ("gamepad", "input", 7, "gamepad-usages.json"),
    ("consumer", "input", 0, {"active": [{"page": 0x0C, "id": 0xCD}]}),
    ("vendor", "output", 0, {}),
)


def full_usage(entry):
    return entry["page"] << 16 | entry["id"]


def independent_usage_report(report, report_id, edits):
    """Fill a report from Usage edits with hid-tools fields; empty slots are 0."""
    values = {full_usage(entry): entry["value"] for entry in edits.get("values", [])}
    active = [full_usage(entry) for entry in edits.get("active", [])]
    wire = [0] * report.size
    if report_id:
        wire[0] = report_id
    for field in report.fields:
        if field.is_const:
            continue
        if field.is_array:
            selected = [field.usages.index(u) + field.logical_min for u in active if u in field.usages]
            if len(selected) > field.count:
                raise AssertionError("independent Array overflow")
            for index in range(field.count):
                field._fill_value(wire, selected[index] if index < len(selected) else 0, index)
        else:
            value = values.get(field.usage, 1 if field.usage in active else 0)
            field.fill_values(wire, [value])
    return bytes(wire)


def active_from_hid_tools(report, wire):
    """Read active Usages back with hid-tools get_values."""
    active = []
    for field in report.fields:
        if field.is_const:
            continue
        for value in field.get_values(list(wire)):
            if field.is_array:
                index = value - field.logical_min
                if 0 <= index < len(field.usages) and field.usages[index] & 0xFFFF:
                    active.append(field.usages[index])
            elif field.logical_min == 0 and field.logical_max == 1 and value == 1:
                active.append(field.usage)
    return active


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

    def parsed_template(template):
        descriptor_hex = cli("generate", template)
        reference_hex = (ROOT / "examples/codec" / f"{template}.hex").read_text()
        if bytes.fromhex(descriptor_hex) != bytes.fromhex(reference_hex):
            raise AssertionError(f"{template}: generated descriptor differs from fixture")
        return descriptor_hex, ReportDescriptor.from_bytes(bytes.fromhex(descriptor_hex))

    results = []
    usage_results = []
    with TemporaryDirectory(prefix="moonhid-codec-") as directory:
        descriptor_path = Path(directory) / "descriptor.hex"
        values_path = Path(directory) / "values.json"
        for template, kind, report_id, values_file in CASES:
            descriptor_hex, parsed = parsed_template(template)
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
        for template, kind, report_id, edits in USAGE_CASES:
            descriptor_hex, parsed = parsed_template(template)
            report = getattr(parsed, kind + "_reports")[report_id or -1]
            if isinstance(edits, str):
                edits = json.loads((ROOT / "examples/codec" / edits).read_text())
            descriptor_path.write_text(descriptor_hex)
            values_path.write_text(json.dumps(edits))
            moon_wire = bytes.fromhex(cli(
                "encode", "--kind", kind, "--id", str(report_id),
                str(descriptor_path), str(values_path),
            ))
            independent = independent_usage_report(report, report_id, edits)
            expected_active = sorted(full_usage(entry) for entry in edits.get("active", []))
            if independent != moon_wire or sorted(active_from_hid_tools(report, moon_wire)) != expected_active:
                raise AssertionError(f"{template} {kind}: independent Usage-form mismatch")
            usage_results.append({"template": template, "kind": kind, "report_id": report_id, "wire_hex": moon_wire.hex(" ")})
    print(json.dumps({
        "tool": "hid-tools",
        "version": version("hid-tools"),
        "codec_cases": results,
        "usage_cases": usage_results,
    }, indent=2))


if __name__ == "__main__":
    main()
