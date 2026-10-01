///|
test "zero-length Global and Local values are zero" {
  let layout = compile("04 14 24 34 44 54 64 75 01 95 01 08 80")
  let field = layout.fields[0]
  assert_eq((field.logical_min, field.logical_max, field.flags), (0L, 0L, 0))
  assert_eq(field.physical_min, Some(0L))
  assert_eq(field.physical_max, Some(0L))
  assert_eq(field.unit, Some(0L))
  assert_eq(field.unit_exponent, Some(0))
  assert_eq(field.usages, [{ page: 0, id: 0, }])
  assert_eq(decode(layout, @moonhid.Input, b"\x00").values[0].value, 0L)
}

///|
test "zero-length Main flags and Physical Collection compile" {
  let layout = compile("a0 75 01 95 01 80 90 b0 c0")
  assert_eq(layout.collections[0].collection_type, 0)
  assert_eq(layout.fields.map(f => (f.kind, f.flags)), [
    (@moonhid.Input, 0),
    (@moonhid.Output, 0),
    (@moonhid.Feature, 0),
  ])
}

///|
test "zero values preserve dimension ID and stack diagnostics" {
  for
    (bytes, code) in [
      (b"\x84", "report_id"),
      (b"\x94", "report_count"),
      (b"\x74\x95\x01\x80", "missing_dimensions"),
      (b"\xb5\x00", "global_stack"),
      (b"\xa5\x00", "global_stack"),
      (b"\x75\x08\x95\x01\x82\x00\x01", "buffered_bytes"),
      (b"\x75\x08\x95\x01\x82\x00\x02", "main_flags"),
    ] {
    match @moonhid.compile_descriptor(bytes) {
      Err(error) => assert_eq(error.code, code)
      Ok(_) => fail("invalid descriptor accepted")
    }
  }
}
