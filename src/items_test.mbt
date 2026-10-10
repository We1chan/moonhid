///|
test "short item sizes include four byte encoding and zero byte Main" {
  let items = @moonhid.parse_items(
    b"\x05\x01\x76\x08\x00\x27\xff\xff\xff\x7f\xc0",
  )
  match items {
    Ok(items) => {
      assert_eq(items.length(), 4)
      assert_eq(items[0].type_code, 1)
      assert_eq(items[1].data.length(), 2)
      assert_eq(items[2].data.length(), 4)
      assert_eq(items[3].tag, 12)
      assert_eq(items[3].offset, 10)
    }
    Err(_) => fail("valid items rejected")
  }
}

///|
test "long items preserve tag and payload" {
  match @moonhid.parse_items(b"\xfe\x02\x42\x11\x22") {
    Ok([item]) => {
      assert_true(item.is_long)
      assert_eq(item.tag, 0x42)
      assert_eq(item.data, b"\x11\x22")
    }
    _ => fail("long item rejected")
  }
}

///|
test "truncated items return the offending prefix offset" {
  for bytes in [b"\x05", b"\x76\x08", b"\xfe", b"\xfe\x03", b"\xfe\x02\x42\x11"] {
    assert_true(
      @moonhid.parse_items(bytes)
      is Err({ offset: 0, code: "truncated_item", .. }),
    )
  }
  assert_true(@moonhid.parse_items(b"\xc0\x27\xff") is Err({ offset: 1, .. }))
  assert_true(
    @moonhid.parse_items(Bytes::new(65537))
    is Err({ code: "descriptor_limit", .. }),
  )
}
