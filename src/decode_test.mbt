///|
fn decode(
  layout : @moonhid.Layout,
  kind : @moonhid.ReportKind,
  bytes : Bytes,
) -> @moonhid.DecodedReport raise {
  match @moonhid.decode_report(layout, kind, bytes) {
    Ok(report) => report
    Err(error) => fail("decode failed: \{error.code}")
  }
}

///|
test "mouse reports omit padding and sign extend axes" {
  let layout = compile(
    "05 09 19 01 29 03 15 00 25 01 75 01 95 03 81 02 75 05 95 01 81 01 05 01 09 30 09 31 15 81 25 7f 75 08 95 02 81 06",
  )
  let report = decode(layout, @moonhid.Input, b"\x05\xff\x02")
  assert_eq(report.values.map(v => v.value), [1L, 0L, 1L, -1L, 2L])
  assert_eq(report.values[3].usage, Some({ page: 1, id: 0x30, }))
  assert_eq(@moonhid.report_length(layout, @moonhid.Input, 0), Ok(3))
}

///|
test "array selectors map logical offsets to sparse usages and mark null state" {
  let layout = compile("05 07 09 04 09 06 15 01 25 02 75 08 95 03 81 40")
  let report = decode(layout, @moonhid.Input, b"\x01\x02\x00")
  assert_eq(report.values.map(v => v.usage), [
    Some({ page: 7, id: 4, }),
    Some({ page: 7, id: 6, }),
    None,
  ])
  assert_true(report.values[0].is_array)
  assert_false(report.values[0].is_null)
  assert_true(report.values[2].is_null)
}

///|
test "ID prefix and report direction select the correct layout" {
  let layout = compile(
    "75 08 95 01 85 01 15 00 25 ff 81 02 91 02 85 02 15 81 25 7f 81 02",
  )
  assert_eq(decode(layout, @moonhid.Input, b"\x02\xff").values[0].value, -1L)
  assert_eq(decode(layout, @moonhid.Output, b"\x01\xff").values[0].value, 255L)
  assert_true(
    @moonhid.decode_report(layout, @moonhid.Input, b"\x03\x00")
    is Err({ code: "unknown_report", .. }),
  )
  assert_true(
    @moonhid.decode_report(layout, @moonhid.Input, b"\x01")
    is Err({ code: "report_length", .. }),
  )
  assert_true(
    @moonhid.decode_report(layout, @moonhid.Input, b"\x01\x00\x00")
    is Err({ code: "report_length", .. }),
  )
  assert_true(
    @moonhid.decode_report(layout, @moonhid.Input, b"")
    is Err({ code: "short_report", .. }),
  )
}

///|
test "invalid caller-created layouts fail without indexing unsafe ranges" {
  let layout = compile("75 08 95 01 81 02")
  let broken : @moonhid.Layout = {
    ..layout,
    fields: [{ ..layout.fields[0], bit_offset: 2147483647, }],
  }
  assert_true(
    @moonhid.decode_report(broken, @moonhid.Input, b"\x00")
    is Err({ code: "invalid_layout", .. }),
  )
}
