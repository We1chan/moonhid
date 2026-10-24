// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "We1chan/moonhid"

source = "src"

version = "0.6.1"

readme = "README.md"

repository = "https://github.com/We1chan/moonhid"

license = "Apache-2.0"

keywords = [ "hid", "usb", "descriptor", "keyboard", "gamepad", "moonbit" ]

preferred_target = "wasm"

description = "Pure MoonBit HID descriptor generation and parsing, report encoding/decoding, and field access."

import {
  "moonbitlang/x@0.5.5",
}
