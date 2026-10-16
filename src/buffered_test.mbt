///|
test "Buffered Bytes preserve one complete application stream in all directions" {
  let descriptor = "06 00 ff 09 01 a1 01 85 05 15 00 25 01 75 08 95 04 09 02 82 02 01 09 03 92 02 01 09 04 b2 02 01 c0"
  let layout = compile(descriptor)
  for
    (index, kind) in [
      (0, @moonhid.Input),
      (1, @moonhid.Output),
      (2, @moonhid.Feature),
    ] {
    let wire = b"\x05\x4d\x4f\x4f\x4e"
    assert_eq(@moonhid.report_length(layout, kind, 5), Ok(5))
    assert_eq(encoded(layout, kind, 5, [@moonhid.Raw(b"MOON")]), wire)
    let report = decode(layout, kind, wire)
    assert_eq(report.values, [])
    assert_eq(report.opaque_values, [])
    assert_eq(report.buffered_values, [
      { field_index: index, bit_offset: 0, bytes: b"MOON", },
    ])
    assert_eq(
      @moonhid.read_field(layout, kind, wire, index, 0),
      Ok(@moonhid.Raw(b"MOON")),
    )
    assert_true(
      @moonhid.report_to_json(report)
      is {
        "values": [],
        "opaque_values": [],
        "buffered_values": [{ "bit_offset": 0, "hex": "4d 4f 4f 4e", .. }],
        ..
      },
    )
  }
  match @moonhid.list_reports(layout) {
    Ok(reports) =>
      assert_eq(
        reports.map(r => (r.payload_bits, r.byte_length, r.data_count)),
        [(32, 5, 1), (32, 5, 1), (32, 5, 1)],
      )
    Err(error) => fail(error.code)
  }
  assert_eq(
    @moonhid.lint_descriptor(
      match @moonhid.parse_hex(descriptor) {
        Ok(bytes) => bytes
        Err(error) => fail(error.code)
      },
    ),
    Ok([]),
  )
}

///|
test "Buffered stream length uses Size times Count without a scalar size restriction" {
  for (size, count) in [(1, 16), (2, 8), (4, 4), (8, 2), (16, 1), (40, 2)] {
    let bytes = match
      @moonhid.DescriptorBuilder::new()
      .report_size(size)
      .report_count(count)
      .input(256)
      .build() {
      Ok(bytes) => bytes
      Err(error) => fail(error.code)
    }
    let layout = compile(@moonhid.format_hex(bytes))
    let raw = Bytes::makei(size * count / 8, i => (255 - i).to_byte())
    assert_eq(encoded(layout, @moonhid.Input, 0, [@moonhid.Raw(raw)]), raw)
    assert_eq(decode(layout, @moonhid.Input, raw).buffered_values[0].bytes, raw)
    assert_eq(
      (
        layout.fields[0].bit_size,
        layout.fields[0].count,
        layout.fields[0].flags,
      ),
      (size, count, 256),
    )
  }
}

///|
test "Buffered edits preserve ID padding and neighboring numeric values" {
  let layout = compile(
    "85 07 15 00 25 01 75 03 95 01 81 02 75 05 81 01 75 08 95 02 82 02 01 95 01 81 02",
  )
  let wire = b"\x07\xf9\x00\xff\x01"
  let report = decode(layout, @moonhid.Input, wire)
  assert_eq(report.values.map(v => (v.field_index, v.value)), [(0, 1L), (3, 1L)])
  assert_eq(report.buffered_values, [
    { field_index: 2, bit_offset: 8, bytes: b"\x00\xff", },
  ])
  assert_eq(
    encoded(layout, @moonhid.Input, 7, [
      @moonhid.Integer(1L),
      @moonhid.Raw(b"\x00\xff"),
      @moonhid.Integer(1L),
    ]),
    b"\x07\x01\x00\xff\x01",
  )
  assert_eq(
    @moonhid.write_field(
      layout,
      @moonhid.Input,
      wire,
      2,
      0,
      @moonhid.Raw(b"OK"),
    ),
    Ok(b"\x07\xf9OK\x01"),
  )
  assert_eq(wire, b"\x07\xf9\x00\xff\x01")
  assert_true(
    @moonhid.read_field(layout, @moonhid.Input, wire, 2, 1)
    is Err({ code: "element_index", .. }),
  )
  assert_true(
    @moonhid.write_field(
      layout,
      @moonhid.Input,
      wire,
      2,
      1,
      @moonhid.Raw(b"OK"),
    )
    is Err({ code: "element_index", .. }),
  )
}

///|
test "Buffered Bytes reject incorrect lengths types counts and wire IDs" {
  let layout = compile("85 05 75 08 95 02 82 02 01")
  for raw in [b"", b"\x00", b"\x00\x00\x00"] {
    assert_true(
      @moonhid.encode_report(layout, @moonhid.Input, 5, [@moonhid.Raw(raw)])
      is Err({ code: "value_range", .. }),
    )
  }
  assert_true(
    @moonhid.encode_report(layout, @moonhid.Input, 5, [@moonhid.Integer(0L)])
    is Err({ code: "value_type", .. }),
  )
  assert_true(
    @moonhid.encode_report(layout, @moonhid.Input, 5, [
      @moonhid.Raw(b"a"),
      @moonhid.Raw(b"b"),
    ])
    is Err({ code: "value_count", .. }),
  )
  assert_true(
    @moonhid.decode_report(layout, @moonhid.Input, b"\x05\x00")
    is Err({ code: "report_length", .. }),
  )
  assert_true(
    @moonhid.decode_report(layout, @moonhid.Input, b"\x05\x00\x00\x00")
    is Err({ code: "report_length", .. }),
  )
  assert_true(
    @moonhid.decode_report(layout, @moonhid.Input, b"\x06\x00\x00")
    is Err({ code: "unknown_report", .. }),
  )
}

///|
test "Buffered report IDs and directions have independent lengths and offsets" {
  let layout = compile(
    "75 08 95 04 85 05 82 02 01 85 07 95 02 82 02 01 75 10 b2 02 01",
  )
  assert_eq(
    encoded(layout, @moonhid.Input, 5, [@moonhid.Raw(b"MOON")]),
    b"\x05MOON",
  )
  assert_eq(
    encoded(layout, @moonhid.Input, 7, [@moonhid.Raw(b"OK")]),
    b"\x07OK",
  )
  assert_eq(
    encoded(layout, @moonhid.Feature, 7, [@moonhid.Raw(b"\x00\x01\xfe\xff")]),
    b"\x07\x00\x01\xfe\xff",
  )
  assert_eq(
    decode(layout, @moonhid.Input, b"\x07OK").buffered_values[0].field_index,
    1,
  )
  assert_eq(
    decode(layout, @moonhid.Feature, b"\x07\x00\x01\xfe\xff").buffered_values[0].field_index,
    2,
  )
  assert_true(
    @moonhid.decode_report(layout, @moonhid.Input, b"\x05OK")
    is Err({ code: "report_length", .. }),
  )
  assert_true(
    @moonhid.decode_report(layout, @moonhid.Output, b"\x07OK")
    is Err({ code: "unknown_report", .. }),
  )
}

///|
test "Buffered Bytes enforce stream alignment and reserved flags at the Main item" {
  for
    (hex, offset, code) in [
      ("75 01 95 01 82 02 01", 4, "buffered_alignment"),
      ("75 01 95 01 81 01 75 08 82 02 01", 8, "buffered_alignment"),
      ("75 08 95 01 82 02 03", 4, "main_flags"),
      ("75 08 95 01 92 00 02", 4, "main_flags"),
      ("75 08 95 01 b2 00 02", 4, "main_flags"),
    ] {
    let bytes = match @moonhid.parse_hex(hex) {
      Ok(bytes) => bytes
      Err(error) => fail(error.code)
    }
    match @moonhid.compile_descriptor(bytes) {
      Err(error) => assert_eq((error.offset, error.code), (offset, code))
      Ok(_) => fail("invalid Buffered Bytes descriptor accepted")
    }
  }
  let layout = compile("75 08 95 02 82 02 01")
  for
    field in [
      { ..layout.fields[0], bit_size: 7, },
      { ..layout.fields[0], flags: 768, },
    ] {
    assert_true(
      @moonhid.report_length({ ..layout, fields: [field], }, @moonhid.Input, 0)
      is Err({ code: "invalid_layout", .. }),
    )
  }
}

///|
test "Buffered Bytes never acquire integer Null Array button or physical semantics" {
  let layout = compile(
    "06 00 ff 09 01 a1 01 15 00 25 01 35 00 45 64 75 08 95 02 09 02 82 42 01 c0",
  )
  let usage : @moonhid.Usage = { page: 65280, id: 2, }
  assert_eq(@moonhid.new_report(layout, @moonhid.Input, 0), Ok(b"\x00\x00"))
  assert_eq(
    @moonhid.find_fields(layout, @moonhid.Input, 0, usage),
    Ok([{ field_index: 0, element_index: 0, }]),
  )
  assert_eq(
    @moonhid.get_usage_value(layout, @moonhid.Input, b"\x00\xff", usage),
    Ok(@moonhid.Raw(b"\x00\xff")),
  )
  assert_eq(
    @moonhid.set_usage_value(
      layout,
      @moonhid.Input,
      b"\x00\x00",
      usage,
      @moonhid.Raw(b"\xff\x00"),
    ),
    Ok(b"\xff\x00"),
  )
  assert_eq(@moonhid.active_usages(layout, @moonhid.Input, b"\x01\x01"), Ok([]))
  assert_true(
    @moonhid.set_usages(layout, @moonhid.Input, b"\x00\x00", [usage])
    is Err({ code: "value_type", .. }),
  )
  assert_true(
    @moonhid.physical_value(layout.fields[0], 1L)
    is Err({ code: "value_type", .. }),
  )
  assert_true(
    @moonhid.logical_from_physical(layout.fields[0], 1.0)
    is Err({ code: "value_type", .. }),
  )
  assert_true(
    @moonhid.get_physical_value(layout, @moonhid.Input, b"\x01\x01", usage)
    is Err({ code: "value_type", .. }),
  )
  assert_true(
    @moonhid.array_selector(layout.fields[0], usage)
    is Err({ code: "value_type", .. }),
  )
  assert_eq(@moonhid.field_usage(layout.fields[0], 0), Some(usage))
  assert_eq(@moonhid.field_usage(layout.fields[0], 1), None)
  // Numeric global ranges are metadata only, even when reversed for a stream.
  let reversed = compile("15 7f 25 01 75 01 95 08 82 00 01")
  assert_eq(
    encoded(reversed, @moonhid.Input, 0, [@moonhid.Raw(b"\xff")]),
    b"\xff",
  )
}

///|
test "Buffered constants are retained in layouts omitted in values and preserved by edits" {
  let layout = compile("75 08 95 02 82 03 01 09 01 82 02 01")
  let wire = b"\xaa\xbbCD"
  assert_eq(decode(layout, @moonhid.Input, wire).buffered_values, [
    { field_index: 1, bit_offset: 16, bytes: b"CD", },
  ])
  assert_eq(
    encoded(layout, @moonhid.Input, 0, [@moonhid.Raw(b"CD")]),
    b"\x00\x00CD",
  )
  assert_eq(
    @moonhid.write_field(
      layout,
      @moonhid.Input,
      wire,
      1,
      0,
      @moonhid.Raw(b"EF"),
    ),
    Ok(b"\xaa\xbbEF"),
  )
  assert_true(
    @moonhid.read_field(layout, @moonhid.Input, wire, 0, 0)
    is Err({ code: "constant_field", .. }),
  )
}

///|
test "Buffered reports honor the 65536 bit limit with and without IDs" {
  for prefix in ["", "85 01 "] {
    let layout = compile(prefix + "75 08 96 00 20 82 02 01")
    let id = if prefix == "" { 0 } else { 1 }
    let raw = Bytes::makei(8192, i => (i % 256).to_byte())
    let wire = encoded(layout, @moonhid.Input, id, [@moonhid.Raw(raw)])
    assert_eq(wire.length(), 8192 + id)
    assert_eq(
      decode(layout, @moonhid.Input, wire).buffered_values[0].bytes,
      raw,
    )
  }
  assert_true(
    @moonhid.compile_descriptor(b"\x75\x08\x96\x01\x20\x82\x02\x01")
    is Err({ code: "report_limit", .. }),
  )
}
