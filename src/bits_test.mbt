///|
test "cross-byte fields use little endian bit order" {
  assert_eq(@moonhid.extract_bits(b"\x80\x01", 7, 2), Ok(3L))
  assert_eq(
    @moonhid.extract_bits(b"\x00\xf0\xff", 12, 12, signed=true),
    Ok(-1L),
  )
  assert_eq(@moonhid.extract_bits(b"\xff\xff\xff\xff", 0, 32), Ok(4294967295L))
  assert_eq(
    @moonhid.extract_bits(b"\x00\x00\x00\x80", 0, 32, signed=true),
    Ok(-2147483648L),
  )
}

///|
test "every single bit maps to its expected weight across byte boundaries" {
  for start = 0; start < 16; start = start + 1 {
    for width = 1; width <= 32; width = width + 1 {
      for bit = 0; bit < width; bit = bit + 1 {
        let position = start + bit
        let bytes = Bytes::makei(6, i => {
          if i == position / 8 {
            (1 << (position % 8)).to_byte()
          } else {
            0
          }
        })
        assert_eq(@moonhid.extract_bits(bytes, start, width), Ok(1L << bit))
      }
    }
  }
}

///|
test "invalid bit ranges and huge offsets fail without overflow" {
  assert_true(
    @moonhid.extract_bits(b"\xff", -1, 1) is Err({ code: "bit_range", .. }),
  )
  assert_true(
    @moonhid.extract_bits(b"\xff", 0, 33) is Err({ code: "bit_range", .. }),
  )
  assert_true(
    @moonhid.extract_bits(b"\xff", 7, 2) is Err({ code: "short_report", .. }),
  )
  assert_true(
    @moonhid.extract_bits(b"\xff", 2147483647, 32)
    is Err({ code: "short_report", .. }),
  )
}
