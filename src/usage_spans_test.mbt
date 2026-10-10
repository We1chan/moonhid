///|
test "full 16-bit usage ranges stay compact and map both endpoints" {
  let layout = compile("05 07 19 00 2a ff ff 15 00 26 ff ff 75 10 95 02 81 00")
  let field = layout.fields[0]
  assert_eq(field.usage_spans, [{ page: 7, min: 0, max: 65535, }])
  assert_eq(@moonhid.field_usage(field, 65535), Some({ page: 7, id: 65535, }))
  assert_eq(@moonhid.field_usage(field, 65536), None)
  assert_eq(@moonhid.field_usage(field, -1), None)
  assert_eq(
    decode(layout, @moonhid.Input, b"\x00\x00\xff\xff").values.map(v => v.usage),
    [Some({ page: 7, id: 0, }), Some({ page: 7, id: 65535, })],
  )
  assert_true(
    @moonhid.layout_to_json(layout)
    is {
      "fields": [
        {
          "usage_count": 65536,
          "usage_spans": [{ "page": 7, "min": 0, "max": 65535, .. }],
          ..
        },
      ],
      ..
    },
  )
}

///|
test "mixed single and range usages retain sequence and Variable repetition" {
  let layout = compile(
    "05 09 09 01 19 04 29 06 09 09 15 00 25 01 75 01 95 07 81 02",
  )
  let field = layout.fields[0]
  assert_eq(Array::makei(7, i => @moonhid.field_usage(field, i)), [
    Some({ page: 9, id: 1, }),
    Some({ page: 9, id: 4, }),
    Some({ page: 9, id: 5, }),
    Some({ page: 9, id: 6, }),
    Some({ page: 9, id: 9, }),
    Some({ page: 9, id: 9, }),
    Some({ page: 9, id: 9, }),
  ])
}

///|
test "Usage limits count spans and caller-created invalid ranges are rejected" {
  assert_true(
    @moonhid.compile_descriptor(b"\x09\x01".repeat(1025))
    is Err({ code: "usage_limit", .. }),
  )
  assert_true(
    @moonhid.compile_descriptor(b"\x19\x03\x29\x01")
    is Err({ code: "usage_range", .. }),
  )
  assert_true(
    @moonhid.compile_descriptor(b"\x1b\x00\x00\x01\x00\x2b\x01\x00\x02\x00")
    is Err({ code: "usage_range", .. }),
  )
  let layout = compile("75 08 95 01 81 02")
  let invalid : @moonhid.Layout = {
    ..layout,
    fields: [
      { ..layout.fields[0], usage_spans: [{ page: 1, min: 0, max: 65536, }], },
    ],
  }
  assert_true(
    @moonhid.report_length(invalid, @moonhid.Input, 0)
    is Err({ code: "invalid_layout", .. }),
  )
}
