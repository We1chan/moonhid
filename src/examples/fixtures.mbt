///|
/// Synthetic fixtures written for MoonHID; no hardware capture is required.
pub(all) struct Fixture {
  name : String
  descriptor_hex : String
  input_hex : String
  expected_values : Array[Int64]
}

///|
pub fn mouse() -> Fixture {
  {
    name: "mouse",
    descriptor_hex: "05 01 09 02 a1 01 05 09 19 01 29 03 15 00 25 01 75 01 95 03 81 02 75 05 95 01 81 01 05 01 09 30 09 31 09 38 15 81 25 7f 75 08 95 03 81 06 c0",
    input_hex: "05 ff 02 fe",
    expected_values: [1, 0, 1, -1, 2, -2],
  }
}

///|
pub fn keyboard() -> Fixture {
  {
    name: "keyboard",
    descriptor_hex: "05 01 09 06 a1 01 05 07 19 e0 29 e7 15 00 25 01 75 01 95 08 81 02 75 08 95 01 81 01 19 00 29 65 15 00 25 65 75 08 95 06 81 00 05 08 19 01 29 05 15 00 25 01 75 01 95 05 91 02 75 03 95 01 91 01 c0",
    input_hex: "02 00 04 06 00 00 00 00",
    expected_values: [0, 1, 0, 0, 0, 0, 0, 0, 4, 6, 0, 0, 0, 0],
  }
}

///|
pub fn gamepad() -> Fixture {
  {
    name: "gamepad",
    descriptor_hex: "05 01 09 05 a1 01 85 07 05 09 19 01 29 0c 15 00 25 01 75 01 95 0c 81 02 75 04 95 01 81 01 05 01 09 30 09 31 16 00 80 26 ff 7f 75 10 95 02 81 02 c0",
    input_hex: "07 01 08 00 80 ff 7f",
    expected_values: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, -32768, 32767],
  }
}

///|
pub fn all() -> Array[Fixture] {
  [mouse(), keyboard(), gamepad()]
}
