#!/usr/bin/env python3
"""Compare MoonHID with external hid-tools; no third-party implementation is copied."""
import json
from importlib.metadata import version
from pathlib import Path
import subprocess
import sys

from hidtools.hid import ReportDescriptor

ROOT = Path(__file__).resolve().parent.parent


def usage_sequence(field):
    return [(s["page"] << 16) | i for s in field["usage_spans"] for i in range(s["min"], s["max"] + 1)]


def compare(fixture):
    layout = fixture["layout"]
    parsed = ReportDescriptor.from_bytes(bytes.fromhex(fixture["hex"]))
    actual = {}
    for kind in ("input", "output", "feature"):
        for report_id, report in getattr(parsed, kind + "_reports").items():
            actual[(kind, max(0, report_id))] = report
    expected = {(r["kind"], r["report_id"]): r for r in layout["reports"]}
    errors = []
    if actual.keys() != expected.keys():
        errors.append("report kinds/IDs differ")
    prefix = 8 if layout["has_report_ids"] else 0
    for key, report in actual.items():
        if key in expected and report.bitsize - prefix != expected[key]["payload_bits"]:
            errors.append(f"{key}: payload size differs")
    normalized = 0
    for index, field in enumerate(layout["fields"]):
        key = (field["kind"], field["report_id"])
        if key not in actual:
            continue
        start = field["bit_offset"]
        end = start + field["bit_size"] * field["count"]
        segments = [f for f in actual[key].fields if f.start - prefix < end and f.start - prefix + f.size * f.count > start]
        cursor = start
        for segment in segments:
            if segment.start - prefix != cursor:
                errors.append(f"field {index}: offset/coverage differs")
            cursor = segment.start - prefix + segment.size * segment.count
            if (segment.type, segment.logical_min, segment.logical_max) != (field["flags"], field["logical_min"], field["logical_max"]):
                errors.append(f"field {index}: flags/logical range differs")
        if cursor != end:
            errors.append(f"field {index}: extent differs")
        usages = usage_sequence(field)
        if field["flags"] & 3:
            # hid-tools splits Variable/Constant elements; fields without Usage
            # may instead be represented by a single combined padding segment.
            combined = len(segments) == 1 and not usages and segments[0].size == end - start and segments[0].count == 1
            if not combined:
                if len(segments) != field["count"] or any((f.size, f.count) != (field["bit_size"], 1) for f in segments):
                    errors.append(f"field {index}: normalized size/count differs")
                for element, segment in enumerate(segments):
                    expected_usage = usages[min(element, len(usages) - 1)] if usages else 0
                    if segment.usage != expected_usage:
                        errors.append(f"field {index} element {element}: usage differs")
        elif len(segments) != 1 or (segments[0].size, segments[0].count, segments[0].usages) != (field["bit_size"], field["count"], usages):
            errors.append(f"field {index}: Array size/count/usages differ")
        normalized += 1
    return {"device": fixture["label"], "reports": len(expected), "main_fields": normalized, "hid_tools_fields": sum(len(r.fields) for r in actual.values()), "differences": errors}


def main():
    exported = subprocess.run(["node", str(ROOT / "scripts/export-real-layouts.mjs")], cwd=ROOT, check=True, capture_output=True, text=True)
    results = [compare(fixture) for fixture in json.loads(exported.stdout)]
    print(json.dumps({"tool": "hid-tools", "version": version("hid-tools"), "devices": results}, indent=2))
    return 1 if any(r["differences"] for r in results) else 0


if __name__ == "__main__":
    sys.exit(main())
