///|
test "raw item serialization retains widths reserved items and long data" {
  let bytes = b"\x00\x05\x00\x06\x00\x00\x07\x00\x00\x00\x00\xfc\xfe\x03\x42abc"
  let items = match @moonhid.parse_items(bytes) {
    Ok(items) => items
    Err(_) => fail("parse items")
  }
  assert_eq(@moonhid.serialize_items(items), Ok(bytes))
  assert_eq(@moonhid.serialize_items([]), Ok(b""))
  for type_code = 0; type_code <= 3; type_code = type_code + 1 {
    for tag = 0; tag <= 15; tag = tag + 1 {
      for width in [0, 1, 2, 4] {
        if type_code == 3 && tag == 15 && width == 2 {
          continue
        }
        let data = Bytes::make(width, 0xa5)
        let item : @moonhid.Item = {
          offset: 99,
          type_code,
          tag,
          data,
          is_long: false,
        }
        let output = match @moonhid.serialize_items([item]) {
          Ok(output) => output
          Err(_) => fail("serialize")
        }
        let reparsed = match @moonhid.parse_items(output) {
          Ok(items) => items
          Err(_) => fail("parse")
        }
        assert_eq(reparsed, [{ ..item, offset: 0, }])
      }
    }
  }
  let item : @moonhid.Item = {
    offset: 0,
    type_code: 0,
    tag: 8,
    data: b"\x00",
    is_long: false,
  }
  for
    invalid in [
      { ..item, data: b"abc", },
      { ..item, type_code: 4, },
      { ..item, tag: -1, },
      { ..item, tag: 16, },
      { ..item, type_code: 3, tag: 15, data: b"ab", },
      { ..item, is_long: true, },
      { ..item, is_long: true, type_code: 3, data: Bytes::make(256, 0), },
    ] {
    assert_true(
      @moonhid.serialize_items([invalid]) is Err({ code: "invalid_item", .. }),
    )
  }
  assert_true(
    @moonhid.serialize_items(Array::make(32769, item))
    is Err({ code: "descriptor_limit", .. }),
  )
  assert_true(
    @moonhid.serialize_items(Array::make(65537, item))
    is Err({ code: "descriptor_limit", .. }),
  )
}

///|
test "builder generates nested collections metadata all directions and multiple IDs" {
  let builder = @moonhid.DescriptorBuilder::new()
    .usage_page(1)
    .usage(5)
    .collection(1)
    .report_id(1)
    .usage(1)
    .collection(0)
    .usage(0x30)
    .logical_range(-2048L, 2047L)
    .physical_range(-1000L, 1000L)
    .unit(0x11L)
    .unit_exponent(-2)
    .report_size(12)
    .report_count(1)
    .input(2)
    .end_collection()
    .push()
    .usage_page(0xff00)
    .usage(1)
    .logical_range(0L, 255L)
    .report_size(8)
    .report_count(2)
    .output(2)
    .pop()
    .report_id(2)
    .usage(0x31)
    .feature(2)
    .end_collection()
  let bytes = match builder.build() {
    Ok(bytes) => bytes
    Err(error) => fail(error.code)
  }
  assert_eq(builder.build(), Ok(bytes))
  let layout = compile(@moonhid.format_hex(bytes))
  assert_eq(layout.collections.length(), 2)
  assert_eq(layout.collections[1].parent_index, Some(0))
  assert_eq(layout.fields.map(f => (f.kind, f.report_id, f.bit_offset)), [
    (@moonhid.Input, 1, 0),
    (@moonhid.Output, 1, 0),
    (@moonhid.Feature, 2, 0),
  ])
  assert_eq(layout.fields[0].physical_min, Some(-1000L))
  assert_eq(layout.fields[0].physical_max, Some(1000L))
  assert_eq(layout.fields[0].unit_exponent, Some(-2))
  assert_eq(layout.fields[2].logical_min, -2048L)
  assert_eq(layout.fields[2].unit, Some(0x11L))
  assert_eq(
    encoded(layout, @moonhid.Input, 1, [@moonhid.Integer(-1L)]),
    b"\x01\xff\x0f",
  )
  assert_eq(
    encoded(layout, @moonhid.Output, 1, [
      @moonhid.Integer(1L),
      @moonhid.Integer(255L),
    ]),
    b"\x01\x01\xff",
  )
  assert_eq(
    encoded(layout, @moonhid.Feature, 2, [@moonhid.Integer(2047L)]),
    b"\x02\xff\x07",
  )
}

///|
test "builder integer signedness and explicit extended Usage page survive compilation" {
  let result = @moonhid.DescriptorBuilder::new()
    .usage_page(1)
    .extended_usage({ page: 0, id: 0x30, })
    .logical_range(0L, 4294967295L)
    .report_size(32)
    .report_count(1)
    .input(2)
    .build()
  let layout = match result {
    Ok(bytes) => compile(@moonhid.format_hex(bytes))
    Err(error) => fail(error.code)
  }
  assert_eq(layout.fields[0].usage_spans, [{ page: 0, min: 0x30, max: 0x30, }])
  assert_eq(layout.fields[0].logical_max, 4294967295L)
  assert_eq(
    encoded(layout, @moonhid.Input, 0, [@moonhid.Integer(4294967295L)]),
    b"\xff\xff\xff\xff",
  )
  let maximum = @moonhid.DescriptorBuilder::new()
    .report_size(1)
    .report_count(65536)
    .input(1)
    .build()
  assert_true(maximum is Ok(_))
}

///|
test "builder returns precise validation errors and retains its first error" {
  assert_true(
    @moonhid.DescriptorBuilder::new().build()
    is Err({ code: "empty_layout", .. }),
  )
  assert_true(
    @moonhid.DescriptorBuilder::new()
    .report_id(0)
    .report_size(0)
    .input(2)
    .build()
    is Err({ code: "report_id", offset: 0, .. }),
  )
  assert_true(
    @moonhid.DescriptorBuilder::new().report_size(0).build()
    is Err({ code: "report_size", .. }),
  )
  assert_true(
    @moonhid.DescriptorBuilder::new().report_count(65537).build()
    is Err({ code: "report_count", .. }),
  )
  assert_true(
    @moonhid.DescriptorBuilder::new().usage_page(65536).build()
    is Err({ code: "usage_page", .. }),
  )
  assert_true(
    @moonhid.DescriptorBuilder::new().usage(-1).build()
    is Err({ code: "usage_range", .. }),
  )
  assert_true(
    @moonhid.DescriptorBuilder::new().usage_range(2, 1).build()
    is Err({ code: "usage_range", .. }),
  )
  assert_true(
    @moonhid.DescriptorBuilder::new()
    .extended_usage({ page: 65536, id: 0, })
    .build()
    is Err({ code: "usage_range", .. }),
  )
  assert_true(
    @moonhid.DescriptorBuilder::new().logical_range(2L, 1L).build()
    is Err({ code: "logical_range", .. }),
  )
  assert_true(
    @moonhid.DescriptorBuilder::new().logical_range(-2147483649L, 0L).build()
    is Err({ code: "item_value", .. }),
  )
  assert_true(
    @moonhid.DescriptorBuilder::new().logical_range(0L, 4294967296L).build()
    is Err({ code: "item_value", .. }),
  )
  assert_true(
    @moonhid.DescriptorBuilder::new().unit_exponent(8).build()
    is Err({ code: "unit_exponent", .. }),
  )
  assert_true(
    @moonhid.DescriptorBuilder::new().collection(256).build()
    is Err({ code: "collection", .. }),
  )
  assert_true(
    @moonhid.DescriptorBuilder::new().short_item(3, 0, 0L).build()
    is Err({ code: "invalid_item", .. }),
  )
  assert_true(
    @moonhid.DescriptorBuilder::new()
    .report_size(1)
    .report_count(1)
    .input(256)
    .build()
    is Err({ code: "buffered_alignment", .. }),
  )
  assert_true(
    @moonhid.DescriptorBuilder::new()
    .collection(1)
    .report_size(1)
    .report_count(1)
    .input(2)
    .build()
    is Err({ code: "collection", .. }),
  )
  assert_true(
    @moonhid.DescriptorBuilder::new().pop().build()
    is Err({ code: "global_stack", .. }),
  )
  let too_large = @moonhid.DescriptorBuilder::new()
    .report_size(1)
    .report_count(1)
  for i = 0; i < 40000; i = i + 1 {
    ignore(too_large.input(1))
  }
  assert_true(too_large.build() is Err({ code: "descriptor_limit", .. }))
}
