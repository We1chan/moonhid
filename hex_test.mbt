///|
test "hex accepts compact bytes and ASCII separators" {
  assert_eq(
    @moonhid.parse_hex("05 01\n09\t02a1\r01"),
    Ok(b"\x05\x01\x09\x02\xa1\x01"),
  )
  assert_eq(@moonhid.parse_hex(""), Ok(b""))
}

///|
test "hex diagnostics preserve source positions" {
  assert_true(
    @moonhid.parse_hex("0g") is Err({ offset: 1, code: "invalid_hex", .. }),
  )
  assert_true(
    @moonhid.parse_hex("a") is Err({ offset: 0, code: "odd_hex", .. }),
  )
  assert_true(
    @moonhid.parse_hex("a b") is Err({ offset: 1, code: "split_byte", .. }),
  )
  assert_true(@moonhid.parse_hex("0x05") is Err({ code: "invalid_hex", .. }))
}
