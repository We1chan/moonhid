"""Linux feasibility only: create one virtual device and enumerate only its VID/PID.

No real device is opened and no Output/Feature report is sent. hid-tools remains
an external test dependency; its GPL source is not incorporated into MoonHID.
"""
import ctypes
import ctypes.util
import json
import os
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
report = {"platform": sys.platform, "scope": "UHID creation and HIDAPI enumeration only", "status": "SKIP"}


def run():
    if sys.platform != "linux" or not Path("/dev/uhid").exists():
        report["reason"] = "Linux /dev/uhid is unavailable; run sudo modprobe uhid on a supported host."
        return
    from hidtools.uhid import UHIDDevice
    from hidtools.util import BusType

    library = ctypes.util.find_library("hidapi-hidraw")
    if not library:
        raise RuntimeError("libhidapi-hidraw is unavailable")
    hid = ctypes.CDLL(library)
    class Info(ctypes.Structure):
        pass
    Info._fields_ = [("path", ctypes.c_char_p), ("vendor_id", ctypes.c_ushort),
                    ("product_id", ctypes.c_ushort), ("serial_number", ctypes.c_void_p),
                    ("release_number", ctypes.c_ushort), ("manufacturer_string", ctypes.c_void_p),
                    ("product_string", ctypes.c_void_p), ("usage_page", ctypes.c_ushort),
                    ("usage", ctypes.c_ushort), ("interface_number", ctypes.c_int),
                    ("next", ctypes.POINTER(Info))]
    hid.hid_enumerate.argtypes = [ctypes.c_ushort, ctypes.c_ushort]
    hid.hid_enumerate.restype = ctypes.POINTER(Info)
    hid.hid_free_enumeration.argtypes = [ctypes.POINTER(Info)]
    hid.hid_version_str.restype = ctypes.c_char_p
    if hid.hid_init() != 0:
        raise RuntimeError("hid_init failed")
    try:
        with UHIDDevice() as device:
            device.name = "MoonHID feasibility virtual device"
            device.info = (BusType.USB, 0xFEDC, 0x0060)
            device.rdesc = bytes.fromhex((ROOT / "examples/codec/standard-feature.hex").read_text())
            device.create_kernel_device()
            deadline = time.monotonic() + 5
            matched = 0
            while time.monotonic() < deadline:
                UHIDDevice.dispatch(10)
                head = hid.hid_enumerate(0xFEDC, 0x0060)
                try:
                    current = head
                    while current:
                        # Compare the path with sysfs nodes owned by this virtual device.
                        path = os.fsdecode(current.contents.path)
                        if path in device.hidraw_nodes:
                            matched += 1
                        current = current.contents.next
                finally:
                    hid.hid_free_enumeration(head)
                if matched:
                    break
            if not matched:
                raise RuntimeError("Created UHID device was not enumerated by HIDAPI within 5 seconds")
            report.update(status="PASS", hidapi_version=hid.hid_version_str().decode("ascii"),
                          virtual_vid="fedc", virtual_pid="0060", matching_interfaces=matched)
    finally:
        hid.hid_exit()


try:
    run()
except Exception as error:
    report.update(status="FAIL", reason=str(error))
output = ROOT / "_build/hidapi-uhid-feasibility.json"
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report))
sys.exit(1 if report["status"] == "FAIL" or ("--require" in sys.argv and report["status"] != "PASS") else 0)
