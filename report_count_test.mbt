///|
test "report bit budget permits the maximum number of one-bit values" {
  let layout = compile("15 00 25 01 75 01 97 00 00 01 00 81 02")
  assert_eq(@moonhid.report_length(layout, @moonhid.Input, 0), Ok(8192))
  let report = decode(layout, @moonhid.Input, Bytes::make(8192, 0xff))
  assert_eq(report.values.length(), 65536)
  assert_true(report.values.all(v => v.value == 1L))
}

///|
test "large counts still reject excess bits and unsafe caller-created dimensions" {
  assert_true(
    @moonhid.compile_descriptor(b"\x75\x02\x97\x00\x00\x01\x00\x81\x02")
    is Err({ code: "report_limit", .. }),
  )
  assert_true(
    @moonhid.compile_descriptor(b"\x97\x01\x00\x01\x00")
    is Err({ code: "report_count", .. }),
  )
  let layout = compile("75 08 95 01 81 02")
  for (size, count) in [(65536, 65536), (2147483647, 1), (1, 2147483647)] {
    let invalid : @moonhid.Layout = {
      ..layout,
      fields: [{ ..layout.fields[0], bit_size: size, count, }],
    }
    assert_true(
      @moonhid.report_length(invalid, @moonhid.Input, 0)
      is Err({ code: "invalid_layout", .. }),
    )
  }
}
