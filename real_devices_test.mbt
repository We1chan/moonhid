// Raw descriptor bytes supplied by the contestant; macOS ioreg, 2026-10-01.
// These fixtures contain descriptor definitions only, without live reports.

///|
fn real_device_a() -> String {
  "06 00 ff 0a 04 00 a1 01 15 00 26 ff 00 75 08 95 20 81 00 c0"
}

///|
fn real_device_b() -> String {
  "05 01 09 02 a1 01 09 01 a1 00 05 09 19 01 29 03 15 00 25 01 85 02 95 03 75 01 81 02 95 01 75 05 81 01 05 01 09 30 09 31 15 81 25 7f 75 08 95 02 81 06 95 04 75 08 81 01 76 00 40 95 02 b1 01 c0 c0 05 0d 09 05 a1 01 06 00 ff 09 0c 15 00 26 ff 00 75 08 95 10 85 3f 81 22 c0 06 00 ff 09 0c a1 01 06 00 ff 09 0c 15 00 26 ff 00 85 44 75 08 96 d7 06 81 00 c0 06 16 ff 09 06 a1 01 85 5b 95 08 75 08 81 03 06 16 ff 09 07 95 01 75 10 81 02 06 16 ff 09 08 95 01 75 08 81 02 95 04 75 08 81 03 06 16 ff 09 10 95 01 75 08 81 02 95 20 75 08 81 03 06 16 ff 09 09 95 20 75 08 81 02 95 10 75 08 81 03 c0"
}

///|
fn real_device_c() -> String {
  "06 00 ff 0a 5f 00 a1 01 06 00 ff 0a 5f 00 15 00 26 ff 00 75 08 96 04 00 85 e0 81 22 76 00 40 95 02 b1 01 c0"
}

///|
fn real_device_d() -> String {
  "05 01 09 06 a1 01 85 01 05 07 19 e0 29 e7 15 00 25 01 75 01 95 08 81 02 95 01 75 08 81 01 95 05 75 01 05 08 19 01 29 05 91 02 95 01 75 03 91 01 95 06 75 08 15 00 26 ff 00 05 07 19 00 29 ff 81 00 05 0c 75 01 95 01 09 b8 15 00 25 01 81 02 05 ff 09 03 75 07 95 01 81 02 c0 05 0c 09 01 a1 01 85 52 15 00 25 01 75 01 95 01 09 cd 81 02 09 b3 81 02 09 b4 81 02 09 b5 81 02 09 b6 81 02 81 01 81 01 81 01 85 09 15 00 25 01 75 08 95 01 06 01 ff 09 0b b1 02 75 08 95 02 b1 01 c0 06 00 ff 09 06 a1 01 06 00 ff 09 06 15 00 26 ff 00 75 08 95 40 85 3f 81 22 76 00 40 95 02 b1 01 c0"
}

///|
fn real_device_e() -> String {
  "05 0c 09 01 a1 01 05 0c 09 cd 09 ea 09 e9 15 00 25 01 95 03 75 01 81 02 95 05 81 05 c0"
}

///|
fn real_device_f() -> String {
  "06 00 ff 0a 48 00 a1 01 06 29 ff 85 01 25 7f 95 01 75 08 09 01 b1 02 09 02 b1 02 09 25 a1 03 85 02 24 76 98 3e 09 03 81 22 09 04 76 78 04 b1 02 c0 c0"
}

///|
fn real_device_g() -> String {
  "05 01 09 06 a1 01 85 01 05 07 19 e0 29 e7 15 00 25 01 75 01 95 08 81 02 95 01 75 08 81 03 95 05 75 01 05 08 19 01 29 05 91 02 95 01 75 03 91 03 95 06 75 08 15 00 26 ff 00 05 07 19 00 2a ff 00 81 00 c0 05 0c 09 01 a1 01 85 02 15 00 26 80 03 19 00 2a 80 03 75 10 95 01 81 00 c0 05 01 09 80 a1 01 85 03 19 00 2a ff 7f 15 00 26 ff 7f 75 10 95 01 81 00 c0 05 01 09 06 a1 01 85 07 05 07 19 00 29 77 15 00 25 01 75 01 95 78 81 02 c0 05 01 09 02 a1 01 85 05 09 01 a1 00 05 09 15 00 25 01 19 01 29 05 75 01 95 05 81 02 95 03 81 01 05 01 16 01 80 26 ff 7f 09 30 09 31 75 10 95 02 81 06 15 81 25 7f 09 38 75 08 95 01 81 06 05 0c 0a 38 02 95 01 81 06 c0 c0 06 55 ff 0a 02 02 a1 01 85 06 75 08 95 41 15 00 26 ff 00 09 02 81 00 09 02 91 00 c0"
}

///|
test "real device A: report structure" {
  let layout = compile(real_device_a())
  assert_eq(layout.fields.length(), 1)
  assert_false(layout.has_report_ids)
  assert_eq(layout.collections.length(), 1)
  assert_eq(@moonhid.report_length(layout, @moonhid.Input, 0), Ok(32))

  assert_eq(
    (layout.fields[0].bit_size, layout.fields[0].count, layout.fields[0].flags),
    (8, 32, 0),
  )
}

///|
test "real device E: report structure" {
  let layout = compile(real_device_e())
  assert_eq(layout.fields.length(), 2)
  assert_false(layout.has_report_ids)
  assert_eq(layout.collections.length(), 1)
  assert_eq(@moonhid.report_length(layout, @moonhid.Input, 0), Ok(1))

  assert_eq(layout.fields.map(f => (f.bit_size, f.count, f.flags)), [
    (1, 3, 2),
    (1, 5, 5),
  ])
}

///|
test "real device B: known compatibility diagnostic" {
  let bytes = match @moonhid.parse_hex(real_device_b()) {
    Ok(bytes) => bytes
    Err(_) => fail("invalid fixture hex")
  }
  assert_true(
    @moonhid.compile_descriptor(bytes)
    is Err({ code: "report_size", offset: 56, .. }),
  )
}

///|
test "real device C: known compatibility diagnostic" {
  let bytes = match @moonhid.parse_hex(real_device_c()) {
    Ok(bytes) => bytes
    Err(_) => fail("invalid fixture hex")
  }
  assert_true(
    @moonhid.compile_descriptor(bytes)
    is Err({ code: "report_size", offset: 28, .. }),
  )
}

///|
test "real device D: known compatibility diagnostic" {
  let bytes = match @moonhid.parse_hex(real_device_d()) {
    Ok(bytes) => bytes
    Err(_) => fail("invalid fixture hex")
  }
  assert_true(
    @moonhid.compile_descriptor(bytes)
    is Err({ code: "report_size", offset: 181, .. }),
  )
}

///|
test "real device F: known compatibility diagnostic" {
  let bytes = match @moonhid.parse_hex(real_device_f()) {
    Ok(bytes) => bytes
    Err(_) => fail("invalid fixture hex")
  }
  assert_true(
    @moonhid.compile_descriptor(bytes)
    is Err({ code: "report_size", offset: 34, .. }),
  )
}

///|
test "real device G: known compatibility diagnostic" {
  let bytes = match @moonhid.parse_hex(real_device_g()) {
    Ok(bytes) => bytes
    Err(_) => fail("invalid fixture hex")
  }
  assert_true(
    @moonhid.compile_descriptor(bytes)
    is Err({ code: "usage_range", offset: 102, .. }),
  )
}
