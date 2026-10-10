///|
test "logical ranges must be representable by the declared bits" {
  for text in ["15 00 25 02 75 01 95 01 81 02", "15 80 25 7f 75 07 95 01 81 02"] {
    let bytes = match @moonhid.parse_hex(text) {
      Ok(bytes) => bytes
      _ => fail("bad test hex")
    }
    assert_true(
      @moonhid.compile_descriptor(bytes) is Err({ code: "logical_range", .. }),
    )
  }
  let layout = compile("15 00 27 ff ff ff ff 75 20 95 01 81 02")
  assert_eq(
    decode(layout, @moonhid.Input, b"\xff\xff\xff\xff").values[0].value,
    4294967295L,
  )
}

///|
test "field and per-report bit limits bound descriptor work" {
  let many = b"\x75\x01\x95\x01" + b"\x81\x02".repeat(4097)
  assert_true(
    @moonhid.compile_descriptor(many) is Err({ code: "field_limit", .. }),
  )
  let wide = b"\x75\x20\x96\x00\x04" + b"\x81\x01".repeat(3)
  assert_true(
    @moonhid.compile_descriptor(wide) is Err({ code: "report_limit", .. }),
  )
}
