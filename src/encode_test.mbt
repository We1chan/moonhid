///|
fn encoded(
  layout : @moonhid.Layout,
  kind : @moonhid.ReportKind,
  id : Int32,
  values : Array[@moonhid.ReportValue],
) -> Bytes raise {
  match @moonhid.encode_report(layout, kind, id, values) {
    Ok(bytes) => bytes
    Err(error) => fail("encode: \{error.code}")
  }
}

///|
test "encoder produces independently specified mouse keyboard and LED bytes" {
  let mouse = compile(
    "05 01 09 02 a1 01 05 09 19 01 29 03 15 00 25 01 75 01 95 03 81 02 75 05 95 01 81 01 05 01 09 30 09 31 09 38 15 81 25 7f 75 08 95 03 81 06 c0",
  )
  let values = [1L, 0L, 1L, -1L, 2L, -2L]
  let wire = encoded(
    mouse,
    @moonhid.Input,
    0,
    values.map(value => @moonhid.Integer(value)),
  )
  assert_eq(wire, b"\x05\xff\x02\xfe")
  assert_eq(
    decode(mouse, @moonhid.Input, wire).values.map(v => v.value),
    values,
  )
  let keyboard = compile(
    "05 01 09 06 a1 01 05 07 19 e0 29 e7 15 00 25 01 75 01 95 08 81 02 75 08 95 01 81 01 19 00 29 65 15 00 25 65 75 08 95 06 81 00 05 08 19 01 29 05 15 00 25 01 75 01 95 05 91 02 75 03 95 01 91 01 c0",
  )
  assert_eq(
    encoded(
      keyboard,
      @moonhid.Input,
      0,
      [0L, 1L, 0L, 0L, 0L, 0L, 0L, 0L, 4L, 6L, 0L, 0L, 0L, 0L].map(value => {
        @moonhid.Integer(value)
      }),
    ),
    b"\x02\x00\x04\x06\x00\x00\x00\x00",
  )
  assert_eq(
    encoded(
      keyboard,
      @moonhid.Output,
      0,
      [1L, 1L, 0L, 0L, 0L].map(value => @moonhid.Integer(value)),
    ),
    b"\x03",
  )
  assert_eq(
    @moonhid.array_selector(keyboard.fields[2], { page: 7, id: 4, }),
    Ok(4L),
  )
}

///|
test "report directions and IDs select independent layouts and prefixes" {
  let layout = compile(
    "85 01 15 00 26 ff 00 75 08 95 01 81 02 91 02 b1 02 85 02 75 10 26 ff ff 81 02",
  )
  for kind in [@moonhid.Input, @moonhid.Output, @moonhid.Feature] {
    assert_eq(encoded(layout, kind, 1, [@moonhid.Integer(255L)]), b"\x01\xff")
    assert_eq(decode(layout, kind, b"\x01\xff").values[0].value, 255L)
  }
  assert_eq(
    encoded(layout, @moonhid.Input, 2, [@moonhid.Integer(65535L)]),
    b"\x02\xff\xff",
  )
  assert_true(
    @moonhid.encode_report(layout, @moonhid.Output, 2, [])
    is Err({ code: "unknown_report", .. }),
  )
  assert_true(
    @moonhid.encode_report(layout, @moonhid.Input, 0, [])
    is Err({ code: "unknown_report", .. }),
  )
  assert_true(
    @moonhid.encode_report(layout, @moonhid.Input, 1, [])
    is Err({ code: "value_count", .. }),
  )
  assert_true(
    @moonhid.encode_report(layout, @moonhid.Input, 1, [
      @moonhid.Integer(1L),
      @moonhid.Integer(2L),
    ])
    is Err({ code: "value_count", .. }),
  )
}

///|
test "32 bit integer boundaries preserve unsigned and signed domains" {
  let unsigned = compile("15 00 27 ff ff ff ff 75 20 95 01 81 02")
  assert_eq(
    encoded(unsigned, @moonhid.Input, 0, [@moonhid.Integer(4294967295L)]),
    b"\xff\xff\xff\xff",
  )
  for value in [-1L, 4294967296L] {
    assert_true(
      @moonhid.encode_report(unsigned, @moonhid.Input, 0, [
        @moonhid.Integer(value),
      ])
      is Err({ code: "value_range", .. }),
    )
  }
  let signed = compile("17 00 00 00 80 27 ff ff ff 7f 75 20 95 01 81 02")
  assert_eq(
    encoded(signed, @moonhid.Input, 0, [@moonhid.Integer(-2147483648L)]),
    b"\x00\x00\x00\x80",
  )
  assert_eq(
    encoded(signed, @moonhid.Input, 0, [@moonhid.Integer(2147483647L)]),
    b"\xff\xff\xff\x7f",
  )
  assert_true(
    @moonhid.encode_report(signed, @moonhid.Input, 0, [
      @moonhid.Integer(2147483648L),
    ])
    is Err({ code: "value_range", .. }),
  )
}

///|
test "logical range is strict except declared null or explicit raw replay" {
  let strict = compile("15 01 25 03 75 03 95 01 81 02")
  assert_true(
    @moonhid.encode_report(strict, @moonhid.Input, 0, [@moonhid.Integer(0L)])
    is Err({ code: "logical_range", .. }),
  )
  assert_eq(
    @moonhid.encode_report(
      strict,
      @moonhid.Input,
      0,
      [@moonhid.Integer(7L)],
      allow_out_of_range=true,
    ),
    Ok(b"\x07"),
  )
  let nullable = compile("15 01 25 03 75 03 95 01 81 42")
  let wire = encoded(nullable, @moonhid.Input, 0, [@moonhid.Integer(0L)])
  assert_true(decode(nullable, @moonhid.Input, wire).values[0].is_null)
  assert_true(
    @moonhid.encode_report(nullable, @moonhid.Input, 0, [@moonhid.Integer(8L)])
    is Err({ code: "value_range", .. }),
  )
  let signed_null = compile("15 fe 25 02 75 03 95 01 81 42")
  let negative = encoded(signed_null, @moonhid.Input, 0, [@moonhid.Integer(-4L)])
  assert_eq(negative, b"\x04")
  assert_true(decode(signed_null, @moonhid.Input, negative).values[0].is_null)
}

///|
test "field reads and writes preserve ID padding neighboring and unused bits" {
  let layout = compile(
    "85 05 75 03 95 01 81 01 16 00 f8 26 ff 07 75 0c 95 02 81 02 75 05 95 01 81 01",
  )
  let original = b"\x05\xff\xff\xff\xff"
  assert_eq(
    @moonhid.write_field(
      layout,
      @moonhid.Input,
      original,
      1,
      0,
      @moonhid.Integer(-2048L),
    ),
    Ok(b"\x05\x07\xc0\xff\xff"),
  )
  assert_eq(
    @moonhid.write_field(
      layout,
      @moonhid.Input,
      original,
      1,
      1,
      @moonhid.Integer(0L),
    ),
    Ok(b"\x05\xff\x7f\x00\xf8"),
  )
  assert_eq(original, b"\x05\xff\xff\xff\xff")
  assert_eq(
    @moonhid.read_field(layout, @moonhid.Input, original, 1, 0),
    Ok(@moonhid.Integer(-1L)),
  )
  for index in [-1, 3, 2147483647] {
    assert_true(
      @moonhid.read_field(layout, @moonhid.Input, original, index, 0)
      is Err({ code: "field_index", .. }),
    )
  }
  for element in [-1, 2, 2147483647] {
    assert_true(
      @moonhid.write_field(
        layout,
        @moonhid.Input,
        original,
        1,
        element,
        @moonhid.Integer(0L),
      )
      is Err({ code: "element_index", .. }),
    )
  }
  assert_true(
    @moonhid.write_field(
      layout,
      @moonhid.Input,
      original,
      0,
      0,
      @moonhid.Integer(0L),
    )
    is Err({ code: "constant_field", .. }),
  )
  assert_true(
    @moonhid.read_field(layout, @moonhid.Input, b"\x05\x00", 1, 0)
    is Err({ code: "report_length", .. }),
  )
  assert_true(
    @moonhid.read_field(layout, @moonhid.Input, b"", 1, 0)
    is Err({ code: "short_report", .. }),
  )
  let mixed = compile("85 01 75 01 95 01 81 02 85 02 81 02")
  assert_true(
    @moonhid.read_field(mixed, @moonhid.Input, b"\x01\x00", 1, 0)
    is Err({ code: "field_report", .. }),
  )
  let single = compile("75 03 95 01 15 00 25 07 81 02")
  assert_eq(
    @moonhid.write_field(
      single,
      @moonhid.Input,
      b"\xff",
      0,
      0,
      @moonhid.Integer(0L),
    ),
    Ok(b"\xf8"),
  )
}

///|
test "opaque fields encode and edit unaligned raw bytes without losing neighbors" {
  let layout = compile("85 07 75 03 95 01 81 01 75 21 81 02")
  let raw = b"\xff\xff\xff\xff\x01"
  let wire = encoded(layout, @moonhid.Input, 7, [@moonhid.Raw(raw)])
  assert_eq(wire, b"\x07\xf8\xff\xff\xff\x0f")
  assert_eq(decode(layout, @moonhid.Input, wire).opaque_values[0].bytes, raw)
  assert_eq(
    @moonhid.read_field(layout, @moonhid.Input, wire, 1, 0),
    Ok(@moonhid.Raw(raw)),
  )
  assert_eq(
    @moonhid.write_field(
      layout,
      @moonhid.Input,
      b"\x07\xff\xff\xff\xff\xff",
      1,
      0,
      @moonhid.Raw(b"\x00\x00\x00\x00\x00"),
    ),
    Ok(b"\x07\x07\x00\x00\x00\xf0"),
  )
  for invalid in [b"", b"\xff\xff\xff\xff", b"\xff\xff\xff\xff\x02"] {
    assert_true(
      @moonhid.encode_report(layout, @moonhid.Input, 7, [@moonhid.Raw(invalid)])
      is Err({ code: "value_range", .. }),
    )
  }
  assert_true(
    @moonhid.encode_report(layout, @moonhid.Input, 7, [@moonhid.Integer(0L)])
    is Err({ code: "value_type", .. }),
  )
  assert_true(
    @moonhid.encode_report(compile("75 08 95 01 81 02"), @moonhid.Input, 0, [
      @moonhid.Raw(b"\x00"),
    ])
    is Err({ code: "value_type", .. }),
  )
  let constant = compile("75 21 95 01 81 01")
  assert_eq(encoded(constant, @moonhid.Input, 0, []), b"\x00\x00\x00\x00\x00")
  let maximum = compile("77 00 00 01 00 95 01 81 02")
  let huge = Bytes::make(8192, 0xa5)
  assert_eq(encoded(maximum, @moonhid.Input, 0, [@moonhid.Raw(huge)]), huge)
}

///|
test "Usage lookup returns repeated Variable matches and Array logical selectors" {
  let layout = compile(
    "05 01 09 30 15 00 25 7f 75 08 95 03 81 02 05 07 19 04 29 06 15 0a 25 0c 95 02 81 00",
  )
  assert_eq(
    @moonhid.find_fields(layout, @moonhid.Input, 0, { page: 1, id: 0x30, }),
    Ok([
      { field_index: 0, element_index: 0, },
      { field_index: 0, element_index: 1, },
      { field_index: 0, element_index: 2, },
    ]),
  )
  assert_eq(
    @moonhid.find_fields(layout, @moonhid.Input, 0, { page: 7, id: 5, }),
    Ok([]),
  )
  assert_eq(
    @moonhid.array_selector(layout.fields[1], { page: 7, id: 5, }),
    Ok(11L),
  )
  assert_true(
    @moonhid.array_selector(layout.fields[1], { page: 7, id: 7, })
    is Err({ code: "unknown_usage", .. }),
  )
  assert_true(
    @moonhid.array_selector(layout.fields[0], { page: 1, id: 0x30, })
    is Err({ code: "value_type", .. }),
  )
  let wire = encoded(
    layout,
    @moonhid.Input,
    0,
    [1L, 2L, 3L, 11L, 12L].map(value => @moonhid.Integer(value)),
  )
  assert_eq(
    decode(layout, @moonhid.Input, wire).values[3].usage,
    Some({ page: 7, id: 5, }),
  )
  let array = layout.fields[1]
  for
    invalid in [
      { ..array, flags: 512, },
      { ..array, bit_size: 0, },
      { ..array, bit_size: 33, },
      { ..array, logical_min: -9223372036854775808L, },
      { ..array, logical_max: 9223372036854775807L, },
      { ..array, usage_spans: [{ page: 7, min: 6, max: 4, }], },
    ] {
    assert_true(
      @moonhid.array_selector(invalid, { page: 7, id: 5, })
      is Err({ code: "invalid_layout", .. }),
    )
  }
  let spans = compile(
    "05 07 09 04 09 06 0b 30 00 01 00 15 0a 25 0b 75 08 95 01 81 00",
  )
  assert_eq(
    @moonhid.array_selector(spans.fields[0], { page: 7, id: 6, }),
    Ok(11L),
  )
  assert_true(
    @moonhid.array_selector(spans.fields[0], { page: 1, id: 0x30, })
    is Err({ code: "logical_range", .. }),
  )
}

///|
test "bit insertion covers every unaligned width and preserves outside bits" {
  for start = 0; start < 16; start = start + 1 {
    for width = 1; width <= 32; width = width + 1 {
      for value in [0L, (1L << width) - 1L, (1L << width) / 3L] {
        let original = Bytes::make(6, 0xa5)
        let result = match @moonhid.insert_bits(original, start, width, value) {
          Ok(result) => result
          Err(_) => fail("insert failed")
        }
        assert_eq(@moonhid.extract_bits(result, start, width), Ok(value))
        for bit = 0; bit < 48; bit = bit + 1 {
          if bit < start || bit >= start + width {
            assert_eq(
              @moonhid.extract_bits(result, bit, 1),
              @moonhid.extract_bits(original, bit, 1),
            )
          }
        }
      }
    }
  }
  assert_eq(
    @moonhid.insert_bits(b"\x00\x00\x00\x00", 0, 32, -2147483648L, signed=true),
    Ok(b"\x00\x00\x00\x80"),
  )
  assert_true(
    @moonhid.insert_bits(b"\xff", 2147483647, 32, 0L)
    is Err({ code: "short_report", .. }),
  )
  assert_true(
    @moonhid.insert_bits(b"\xff", -1, 1, 0L) is Err({ code: "bit_range", .. }),
  )
  assert_true(
    @moonhid.insert_bits(b"\xff", 0, 0, 0L) is Err({ code: "bit_range", .. }),
  )
  assert_true(
    @moonhid.insert_bits(b"\xff", 0, 33, 0L) is Err({ code: "bit_range", .. }),
  )
  assert_true(
    @moonhid.insert_bits(b"\xff", 0, 1, 2L) is Err({ code: "value_range", .. }),
  )
  assert_eq(@moonhid.insert_bytes(b"\xff\xff", 7, 2, b"\x00"), Ok(b"\x7f\xfe"))
  assert_true(
    @moonhid.insert_bytes(b"\xff", 2147483647, 65536, b"")
    is Err({ code: "short_report", .. }),
  )
  assert_true(
    @moonhid.insert_bytes(b"\xff", 0, 0, b"") is Err({ code: "bit_range", .. }),
  )
  assert_true(
    @moonhid.insert_bytes(b"\xff", 0, 1, b"\x02")
    is Err({ code: "value_range", .. }),
  )
}
