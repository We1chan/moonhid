///|
test "String and Designator metadata preserve uint32 ranges and reset after Main" {
  let layout = compile(
    "7b ff ff ff ff 39 03 49 04 59 06 a0 75 08 95 01 79 02 89 03 99 05 38 81 02 81 02 c0",
  )
  assert_eq(layout.collections[0].string_spans, [
    { min: 4294967295L, max: 4294967295L, },
  ])
  assert_eq(layout.collections[0].designator_spans, [
    { min: 3L, max: 3L, },
    { min: 4L, max: 6L, },
  ])
  assert_eq(layout.fields[0].string_spans, [
    { min: 2L, max: 2L, },
    { min: 3L, max: 5L, },
  ])
  assert_eq(layout.fields[0].designator_spans, [{ min: 0L, max: 0L, }])
  assert_eq(layout.fields[1].string_spans, [])
  assert_eq(layout.fields[1].designator_spans, [])
  assert_true(
    @moonhid.layout_to_json(layout)
    is {
      "collections": [
        { "string_spans": [{ "min": 4294967295, "max": 4294967295, .. }], .. },
      ],
      ..
    },
  )
}

///|
test "Delimiter uses common and preferred set and preserves alternatives" {
  let layout = compile(
    "05 09 09 01 a9 01 09 02 09 03 a8 a9 01 19 04 29 06 a9 00 15 00 25 01 75 01 95 04 81 02 81 02",
  )
  let field = layout.fields[0]
  assert_eq(field.usage_spans, [
    { page: 9, min: 1, max: 1, },
    { page: 9, min: 2, max: 2, },
    { page: 9, min: 3, max: 3, },
  ])
  assert_eq(field.alternate_usages, [[{ page: 9, min: 4, max: 6, }]])
  assert_eq(
    decode(layout, @moonhid.Input, b"\xff").values[3].usage,
    Some({ page: 9, id: 3, }),
  )
  assert_eq(layout.fields[1].usage_spans, [])
  assert_eq(layout.fields[1].alternate_usages, [])
}

///|
test "local metadata and Delimiter errors have explicit diagnostics" {
  for
    (hex, code) in [
      ("a9 00", "delimiter"),
      ("a9 01 a9 01", "delimiter"),
      ("a9 01", "delimiter"),
      ("75 01 95 01 a9 01 80", "delimiter"),
      ("99 02", "local_range"),
      ("89 03 99 02", "local_range"),
      ("89 03 89 04", "local_range"),
      ("49 02 59 01", "local_range"),
      ("75 01 95 01 89 01 80", "local_range"),
      ("19 01 a9 01", "usage_range"),
    ] {
    let bytes = match @moonhid.parse_hex(hex) {
      Ok(b) => b
      Err(_) => fail("bad hex")
    }
    match @moonhid.compile_descriptor(bytes) {
      Err(e) => assert_eq(e.code, code)
      Ok(_) => fail("invalid local state accepted")
    }
  }
  assert_true(
    @moonhid.compile_descriptor(b"\x79\x01".repeat(1025))
    is Err({ code: "local_limit", .. }),
  )
  assert_true(
    @moonhid.compile_descriptor(b"\xa9\x01\xa9\x00".repeat(1025))
    is Err({ code: "delimiter", .. }),
  )
  let descriptor = b"\x09\x01".repeat(1024) + b"\xa9\x01\xa8\xa9\x01\x09\x02"
  assert_true(
    @moonhid.compile_descriptor(descriptor) is Err({ code: "usage_limit", .. }),
  )
}

///|
test "caller-created local metadata obeys supported bounds" {
  let layout = compile("75 08 95 01 81 02")
  let invalid : @moonhid.Layout = {
    ..layout,
    fields: [{ ..layout.fields[0], string_spans: [{ min: -1L, max: 0L, }], }],
  }
  assert_true(
    @moonhid.report_length(invalid, @moonhid.Input, 0)
    is Err({ code: "invalid_layout", .. }),
  )
}
