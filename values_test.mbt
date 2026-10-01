///|
test "unsigned values retain 32 bits" {
  assert_eq(@moonhid.unsigned_value(b""), Ok(0L))
  assert_eq(@moonhid.unsigned_value(b"\x80"), Ok(128L))
  assert_eq(@moonhid.unsigned_value(b"\x34\x12"), Ok(0x1234L))
  assert_eq(@moonhid.unsigned_value(b"\xff\xff\xff\xff"), Ok(4294967295L))
}

///|
test "signed values extend the payload sign bit" {
  assert_eq(@moonhid.signed_value(b"\x81"), Ok(-127L))
  assert_eq(@moonhid.signed_value(b"\x00\x80"), Ok(-32768L))
  assert_eq(@moonhid.signed_value(b"\x00\x00\x00\x80"), Ok(-2147483648L))
  assert_eq(@moonhid.signed_value(b"\xff\xff\xff\x7f"), Ok(2147483647L))
  assert_true(
    @moonhid.signed_value(b"\x01\x02\x03") is Err({ code: "value_size", .. }),
  )
}
