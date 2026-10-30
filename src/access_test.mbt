///|
fn keyboard_layout() -> @moonhid.Layout raise {
  compile(
    "05 01 09 06 a1 01 05 07 19 e0 29 e7 15 00 25 01 75 01 95 08 81 02 75 08 95 01 81 01 19 00 29 65 15 00 25 65 75 08 95 06 81 00 05 08 19 01 29 05 15 00 25 01 75 01 95 05 91 02 75 03 95 01 91 01 c0",
  )
}

///|
/// Report 3: hat (0..7, 0..315 degrees, Null), padding, X/Y (-127..127,
/// Null) and a two-element Button Array with Logical 1..4.
fn hat_pad_layout() -> @moonhid.Layout raise {
  compile(
    "05 01 09 05 a1 01 85 03 09 39 15 00 25 07 35 00 46 3b 01 65 14 75 04 95 01 81 42 75 04 95 01 81 01 09 30 09 31 15 81 25 7f 75 08 95 02 81 42 05 09 19 01 29 04 15 01 25 04 75 08 95 02 81 00 c0",
  )
}

///|
fn ok_bytes(result : Result[Bytes, @moonhid.Diagnostic]) -> Bytes raise {
  match result {
    Ok(bytes) => bytes
    Err(error) => fail("\{error.code} @\{error.offset}: \{error.message}")
  }
}

///|
fn usage(page : Int32, id : Int32) -> @moonhid.Usage {
  { page, id, }
}

///|
test "list_reports summarises lengths and value counts per report" {
  assert_eq(
    @moonhid.list_reports(keyboard_layout()),
    Ok([
      {
        kind: @moonhid.Input,
        report_id: 0,
        payload_bits: 64,
        byte_length: 8,
        data_count: 14,
      },
      {
        kind: @moonhid.Output,
        report_id: 0,
        payload_bits: 8,
        byte_length: 1,
        data_count: 5,
      },
    ]),
  )
  assert_eq(
    @moonhid.list_reports(hat_pad_layout()),
    Ok([
      {
        kind: @moonhid.Input,
        report_id: 3,
        payload_bits: 40,
        byte_length: 6,
        data_count: 5,
      },
    ]),
  )
}

///|
test "keyboard keys and LEDs are set and cleared by Usage" {
  let layout = keyboard_layout()
  let empty = ok_bytes(@moonhid.new_report(layout, @moonhid.Input, 0))
  assert_eq(empty, b"\x00\x00\x00\x00\x00\x00\x00\x00")
  let shift_a_c = ok_bytes(
    @moonhid.set_usages(layout, @moonhid.Input, empty, [
      usage(7, 0xe1),
      usage(7, 4),
      usage(7, 6),
    ]),
  )
  assert_eq(shift_a_c, b"\x02\x00\x04\x06\x00\x00\x00\x00")
  assert_eq(
    @moonhid.active_usages(layout, @moonhid.Input, shift_a_c),
    Ok([usage(7, 0xe1), usage(7, 4), usage(7, 6)]),
  )
  // Setting an active key is a no-op; a released key frees its slot.
  assert_eq(
    @moonhid.set_usages(layout, @moonhid.Input, shift_a_c, [usage(7, 6)]),
    Ok(shift_a_c),
  )
  let shift_c = ok_bytes(
    @moonhid.clear_usages(layout, @moonhid.Input, shift_a_c, [usage(7, 4)]),
  )
  assert_eq(shift_c, b"\x02\x00\x00\x06\x00\x00\x00\x00")
  assert_eq(
    @moonhid.set_usages(layout, @moonhid.Input, shift_c, [usage(7, 5)]),
    Ok(b"\x02\x00\x05\x06\x00\x00\x00\x00"),
  )
  let six = ok_bytes(
    @moonhid.set_usages(
      layout,
      @moonhid.Input,
      empty,
      [4, 5, 6, 7, 8, 9].map(id => usage(7, id)),
    ),
  )
  assert_eq(six, b"\x00\x00\x04\x05\x06\x07\x08\x09")
  assert_true(
    @moonhid.set_usages(layout, @moonhid.Input, six, [usage(7, 10)])
    is Err({ code: "array_full", offset: 40, .. }),
  )
  assert_true(
    @moonhid.set_usages(layout, @moonhid.Input, empty, [usage(7, 0x66)])
    is Err({ code: "unknown_usage", .. }),
  )
  assert_true(
    @moonhid.set_usages(layout, @moonhid.Input, empty, [usage(7, 0)])
    is Err({ code: "unknown_usage", .. }),
  )
  let leds = ok_bytes(
    @moonhid.set_usages(
      layout,
      @moonhid.Output,
      ok_bytes(@moonhid.new_report(layout, @moonhid.Output, 0)),
      [usage(8, 1), usage(8, 2)],
    ),
  )
  assert_eq(leds, b"\x03")
  assert_eq(
    @moonhid.get_usage_value(layout, @moonhid.Output, leds, usage(8, 2)),
    Ok(@moonhid.Integer(1L)),
  )
  assert_eq(
    @moonhid.clear_usages(layout, @moonhid.Output, leds, [usage(8, 1)]),
    Ok(b"\x02"),
  )
  assert_true(
    @moonhid.set_usages(layout, @moonhid.Input, leds, [usage(7, 4)])
    is Err({ code: "report_length", .. }),
  )
}

///|
test "new_report writes Null values, Report ID and empty Array selectors" {
  let layout = hat_pad_layout()
  let idle = ok_bytes(@moonhid.new_report(layout, @moonhid.Input, 3))
  assert_eq(idle, b"\x03\x0f\x80\x80\x00\x00")
  let decoded = match @moonhid.decode_report(layout, @moonhid.Input, idle) {
    Ok(report) => report
    Err(error) => fail(error.code)
  }
  assert_eq(decoded.values.map(v => v.is_null), [true, true, true, false, false])
  assert_eq(decoded.values.map(v => v.usage), [
    Some(usage(1, 0x39)),
    Some(usage(1, 0x30)),
    Some(usage(1, 0x31)),
    None,
    None,
  ])
  assert_eq(@moonhid.active_usages(layout, @moonhid.Input, idle), Ok([]))
  assert_true(
    @moonhid.get_physical_value(layout, @moonhid.Input, idle, usage(1, 0x39))
    is Err({ code: "null_value", offset: 25, .. }),
  )
  assert_eq(
    @moonhid.get_usage_value(layout, @moonhid.Input, idle, usage(1, 0x31)),
    Ok(@moonhid.Integer(-128L)),
  )
  assert_true(
    @moonhid.new_report(layout, @moonhid.Input, 4)
    is Err({ code: "unknown_report", .. }),
  )
}

///|
test "usage values, physical hat angles and Button Arrays share one report" {
  let layout = hat_pad_layout()
  let idle = ok_bytes(@moonhid.new_report(layout, @moonhid.Input, 3))
  let east = ok_bytes(
    @moonhid.set_physical_value(
      layout,
      @moonhid.Input,
      idle,
      usage(1, 0x39),
      90.0,
    ),
  )
  assert_eq(east, b"\x03\x02\x80\x80\x00\x00")
  assert_eq(
    @moonhid.get_physical_value(layout, @moonhid.Input, east, usage(1, 0x39)),
    Ok(90.0),
  )
  let moved = ok_bytes(
    @moonhid.set_usage_value(
      layout,
      @moonhid.Input,
      east,
      usage(1, 0x30),
      @moonhid.Integer(-1L),
    ),
  )
  assert_eq(moved, b"\x03\x02\xff\x80\x00\x00")
  assert_true(
    @moonhid.set_usage_value(
      layout,
      @moonhid.Input,
      moved,
      usage(1, 0x30),
      @moonhid.Integer(-128L),
    )
    is Ok(_),
  )
  assert_true(
    @moonhid.set_usage_value(
      layout,
      @moonhid.Input,
      moved,
      usage(1, 0x30),
      @moonhid.Integer(128L),
    )
    is Err({ code: "value_range", .. }),
  )
  let buttons = ok_bytes(
    @moonhid.set_usages(layout, @moonhid.Input, moved, [
      usage(9, 2),
      usage(9, 4),
    ]),
  )
  assert_eq(buttons, b"\x03\x02\xff\x80\x02\x04")
  assert_eq(
    @moonhid.active_usages(layout, @moonhid.Input, buttons),
    Ok([usage(9, 2), usage(9, 4)]),
  )
  assert_true(
    @moonhid.set_usages(layout, @moonhid.Input, buttons, [usage(9, 1)])
    is Err({ code: "array_full", .. }),
  )
  assert_eq(
    @moonhid.clear_usages(layout, @moonhid.Input, buttons, [
      usage(9, 2),
      usage(9, 3),
    ]),
    Ok(b"\x03\x02\xff\x80\x00\x04"),
  )
  assert_true(
    @moonhid.set_usages(layout, @moonhid.Input, buttons, [usage(1, 0x39)])
    is Err({ code: "value_type", .. }),
  )
}

///|
test "repeated Usages and Arrays without an empty value are explicit errors" {
  let vendor = compile(
    "06 00 ff 09 01 a1 01 09 02 15 00 26 ff 00 75 08 95 04 81 02 c0",
  )
  let wire = ok_bytes(@moonhid.new_report(vendor, @moonhid.Input, 0))
  assert_true(
    @moonhid.get_usage_value(vendor, @moonhid.Input, wire, usage(0xff00, 2))
    is Err({ code: "ambiguous_usage", offset: 18, .. }),
  )
  assert_true(
    @moonhid.get_usage_value(vendor, @moonhid.Input, wire, usage(0xff00, 3))
    is Err({ code: "unknown_usage", .. }),
  )
  let full = compile("05 09 19 01 29 04 15 00 25 03 75 02 95 02 81 00")
  let zero = ok_bytes(@moonhid.new_report(full, @moonhid.Input, 0))
  assert_eq(zero, b"\x00")
  assert_eq(
    @moonhid.active_usages(full, @moonhid.Input, zero),
    Ok([usage(9, 1)]),
  )
  assert_true(
    @moonhid.clear_usages(full, @moonhid.Input, zero, [usage(9, 1)])
    is Err({ code: "array_no_empty", .. }),
  )
}

///|
test "physical scaling applies the Unit Exponent and rounds half away from zero" {
  let layout = compile(
    "05 01 09 30 15 00 26 c8 00 35 00 45 64 55 0f 75 08 95 01 81 02 09 31 15 9c 25 64 35 f6 45 0a 55 00 75 08 95 01 81 02",
  )
  let tenths = layout.fields[0]
  assert_eq(@moonhid.physical_value(tenths, 50L), Ok(2.5))
  assert_eq(@moonhid.physical_value(tenths, 200L), Ok(10.0))
  assert_eq(@moonhid.logical_from_physical(tenths, 2.5), Ok(50L))
  assert_eq(@moonhid.logical_from_physical(tenths, 2.53), Ok(51L))
  assert_true(
    @moonhid.logical_from_physical(tenths, 10.1)
    is Err({ code: "logical_range", .. }),
  )
  assert_true(
    @moonhid.logical_from_physical(tenths, 0.0 / 0.0)
    is Err({ code: "value_range", .. }),
  )
  assert_true(
    @moonhid.physical_value(tenths, 201L) is Err({ code: "logical_range", .. }),
  )
  let signed = layout.fields[1]
  assert_eq(@moonhid.physical_value(signed, 50L), Ok(5.0))
  assert_eq(@moonhid.logical_from_physical(signed, -0.25), Ok(-3L))
  assert_eq(@moonhid.logical_from_physical(signed, -0.24), Ok(-2L))
  assert_eq(@moonhid.logical_from_physical(signed, 0.25), Ok(3L))
  // Without Physical items the Logical range is the physical range.
  let plain = compile("05 01 09 30 15 81 25 7f 75 08 95 01 81 02").fields[0]
  assert_eq(@moonhid.physical_value(plain, -127L), Ok(-127.0))
  let flat = compile("05 01 09 30 15 00 25 00 75 01 95 01 81 02").fields[0]
  assert_true(
    @moonhid.physical_value(flat, 0L) is Err({ code: "physical_range", .. }),
  )
}

///|
test "builder encodes non-negative maxima so signed and unsigned readers agree" {
  let bytes = match
    @moonhid.DescriptorBuilder::new()
    .usage_page(0xff00)
    .usage(1)
    .collection(1)
    .usage(2)
    .logical_range(0L, 255L)
    .physical_range(0L, 32768L)
    .report_size(8)
    .report_count(1)
    .input(2)
    .usage(3)
    .logical_range(0L, 4294967295L)
    .report_size(32)
    .input(2)
    .end_collection()
    .build() {
    Ok(bytes) => bytes
    Err(error) => fail(error.code)
  }
  assert_eq(
    @moonhid.format_hex(bytes),
    "06 00 ff 09 01 a1 01 09 02 15 00 26 ff 00 35 00 47 00 80 00 00 75 08 95 01 81 02 09 03 15 00 27 ff ff ff ff 75 20 81 02 c0",
  )
  let lints = match @moonhid.lint_descriptor(bytes) {
    Ok(lints) => lints
    Err(error) => fail(error.code)
  }
  // Only the full uint32 Maximum keeps the unavoidable 4-byte ambiguity.
  assert_eq(
    lints
    .filter(l => l.code == "logical_max_sign" || l.code == "physical_max_sign")
    .map(l => l.offset),
    [31],
  )
  assert_true(
    @moonhid.DescriptorBuilder::new().physical_range(10L, -10L).build()
    is Err({ code: "item_value", .. }),
  )
}
