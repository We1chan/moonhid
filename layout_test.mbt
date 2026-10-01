///|
fn compile(text : String) -> @moonhid.Layout raise {
  match @moonhid.parse_hex(text) {
    Ok(bytes) =>
      match @moonhid.compile_descriptor(bytes) {
        Ok(layout) => layout
        Err(error) => fail("compile failed: \{error.code} at \{error.offset}")
      }
    Err(_) => fail("invalid test hex")
  }
}

///|
test "mouse layout retains padding and signed relative axes" {
  let layout = compile(
    "05 09 19 01 29 03 15 00 25 01 75 01 95 03 81 02 75 05 95 01 81 01 05 01 09 30 09 31 15 81 25 7f 75 08 95 02 81 06",
  )
  assert_eq(layout.fields.length(), 3)
  assert_eq(layout.fields[0].usage_spans, [{ page: 9, min: 1, max: 3, }])
  assert_eq(layout.fields[1].bit_offset, 3)
  assert_eq(layout.fields[2].bit_offset, 8)
  assert_eq(layout.fields[2].logical_min, -127L)
  assert_eq(layout.fields[2].flags, 6)
  assert_false(layout.has_report_ids)
}

///|
test "local state resets at Collections and report kinds have independent offsets" {
  let layout = compile(
    "05 01 09 02 a1 01 75 08 95 01 15 00 25 ff 09 30 81 02 09 31 91 02 81 02 b1 02 c0",
  )
  assert_eq(layout.fields[0].logical_max, 255L)
  assert_eq(layout.fields[0].usage_spans[0].min, 0x30)
  assert_eq(layout.fields[1].kind, @moonhid.Output)
  assert_eq(layout.fields[1].bit_offset, 0)
  assert_eq(layout.fields[2].bit_offset, 8)
  assert_eq(layout.fields[2].usage_spans, [])
  assert_eq(layout.fields[3].bit_offset, 0)
}

///|
test "compiler rejects malformed and unsupported descriptors" {
  for
    bytes in [
      b"", b"\xc0", b"\xa1\x01", b"\x81\x02", b"\x75\x21", b"\xfe\x00\x42", b"\x05\x09\x19\x03\x29\x01",
    ] {
    assert_true(@moonhid.compile_descriptor(bytes) is Err(_))
  }
  assert_true(
    @moonhid.compile_descriptor(b"\x75\x08\x95\x01\x81\x02\x09\x01")
    is Err({ code: "dangling_local", .. }),
  )
}
