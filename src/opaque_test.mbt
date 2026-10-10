///|
test "raw bit copying packs unaligned bits and zero-fills trailing bits" {
  assert_eq(
    @moonhid.extract_bytes(b"\xf8\xff\xff\xff\xff", 3, 33),
    Ok(b"\xff\xff\xff\xff\x01"),
  )
  assert_eq(@moonhid.extract_bytes(b"\x80\x01", 7, 2), Ok(b"\x03"))
  assert_true(
    @moonhid.extract_bytes(b"", 2147483647, 65536)
    is Err({ code: "short_report", .. }),
  )
  assert_true(
    @moonhid.extract_bytes(b"\x00", 0, 0) is Err({ code: "bit_range", .. }),
  )
  assert_true(
    @moonhid.extract_bytes(b"\x00", -1, 1) is Err({ code: "bit_range", .. }),
  )
}

///|
test "opaque values use payload offsets after the Report ID and omit Constant" {
  let layout = compile("85 07 75 03 95 01 81 01 75 21 81 02")
  let report = decode(layout, @moonhid.Input, b"\x07\xff\xff\xff\xff\xff")
  assert_eq(report.values, [])
  assert_eq(report.opaque_values.length(), 1)
  let raw = report.opaque_values[0]
  assert_eq(
    (raw.field_index, raw.element_index, raw.bit_offset, raw.bit_size),
    (1, 0, 3, 33),
  )
  assert_eq(raw.bytes, b"\xff\xff\xff\xff\x01")
  assert_true(
    @moonhid.report_to_json(report)
    is {
      "values": [],
      "opaque_values": [
        { "bit_offset": 3, "bit_size": 33, "hex": "ff ff ff ff 01", .. },
      ],
      ..
    },
  )
}

///|
test "wide Variable fields avoid shifts at 63 or more bits while Arrays stay bounded" {
  for size in [33, 63, 64, 16024, 65536] {
    let descriptor = b"\x15\xff\x25\x01\x77" +
      Bytes::makei(4, i => ((size >> (8 * i)) & 255).to_byte()) +
      b"\x95\x01\x81\x02"
    let layout = compile(@moonhid.format_hex(descriptor))
    let report = decode(layout, @moonhid.Input, Bytes::make((size + 7) / 8, 0))
    assert_eq(report.opaque_values[0].bytes.length(), (size + 7) / 8)
  }
  assert_true(
    @moonhid.compile_descriptor(b"\x75\x21\x95\x01\x81\x00")
    is Err({ code: "report_size", .. }),
  )
  let layout = compile("75 21 95 01 81 01")
  assert_eq(decode(layout, @moonhid.Input, Bytes::make(5, 0)).opaque_values, [])
  let broken : @moonhid.Layout = {
    ..layout,
    fields: [{ ..layout.fields[0], flags: 0, }],
  }
  assert_true(
    @moonhid.report_length(broken, @moonhid.Input, 0)
    is Err({ code: "invalid_layout", .. }),
  )
}
