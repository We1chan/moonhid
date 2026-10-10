// Fixed seeds and UInt shifts keep this corpus identical on all four backends.

///|
struct FuzzRng {
  mut state : UInt
}

///|
fn FuzzRng::next(self : FuzzRng) -> UInt {
  let mut x = self.state
  x = x ^ (x << 13)
  x = x ^ (x >> 17)
  x = x ^ (x << 5)
  self.state = x
  x
}

///|
fn FuzzRng::below(self : FuzzRng, limit : Int) -> Int {
  (self.next() % limit.reinterpret_as_uint()).reinterpret_as_int()
}

///|
fn fuzz_diagnostic(error : @moonhid.Diagnostic, length : Int) -> Unit raise {
  assert_true(error.offset >= 0 && error.offset <= length)
  assert_false(error.message.is_empty())
  assert_true(
    [
      "descriptor_limit", "truncated_item", "unsupported_item", "usage_page", "unit_exponent",
      "report_size", "report_id", "report_count", "global_stack", "unsupported_global",
      "usage_range", "local_range", "local_limit", "delimiter", "unsupported_local",
      "usage_limit", "collection", "buffered_bytes", "main_flags", "missing_dimensions",
      "field_limit", "report_limit", "logical_range", "unsupported_main", "dangling_local",
      "mixed_report_ids", "empty_layout",
    ].contains(error.code),
  )
}

///|
fn fuzz_spans(spans : Array[@moonhid.UsageSpan]) -> Unit raise {
  assert_true(spans.length() <= 1024)
  for span in spans {
    assert_true(span.page >= 0 && span.page <= 65535)
    assert_true(span.min >= 0 && span.min <= span.max && span.max <= 65535)
  }
}

///|
fn fuzz_metadata(
  primary : Array[@moonhid.UsageSpan],
  strings : Array[@moonhid.IndexSpan],
  designators : Array[@moonhid.IndexSpan],
  alternatives : Array[Array[@moonhid.UsageSpan]],
) -> Unit raise {
  fuzz_spans(primary)
  let mut total = primary.length()
  assert_true(alternatives.length() <= 1024)
  for group in alternatives {
    fuzz_spans(group)
    total = total + group.length()
  }
  assert_true(total <= 1024)
  for spans in [strings, designators] {
    assert_true(spans.length() <= 1024)
    for span in spans {
      assert_true(
        span.min >= 0 && span.min <= span.max && span.max <= 4294967295L,
      )
    }
  }
}

///|
fn fuzz_reports(layout : @moonhid.Layout, rng : FuzzRng) -> Int raise {
  assert_true(layout.fields.length() >= 1 && layout.fields.length() <= 4096)
  assert_true(layout.collections.length() <= 4096)
  for field in layout.fields {
    assert_true(field.bit_size >= 1 && field.bit_size <= 65536)
    assert_true(field.count >= 1 && field.count <= 65536)
    fuzz_metadata(
      field.usage_spans,
      field.string_spans,
      field.designator_spans,
      field.alternate_usages,
    )
  }
  for collection in layout.collections {
    fuzz_metadata(
      [],
      collection.string_spans,
      collection.designator_spans,
      collection.alternate_usages,
    )
  }
  let reports = real_report_summary(layout)
  for (kind, id, bits) in reports {
    assert_true(bits >= 1 && bits <= 65536)
    let prefix = if layout.has_report_ids { 1 } else { 0 }
    let length = match @moonhid.report_length(layout, kind, id) {
      Ok(length) => length
      Err(error) => fail("compiled layout rejected: \{error.code}")
    }
    assert_eq(length, (bits + 7) / 8 + prefix)
    assert_true(length <= 8193)
    let wire = Bytes::makei(length, i => {
      if i == 0 && layout.has_report_ids {
        id.to_byte()
      } else {
        rng.below(256).to_byte()
      }
    })
    let report = decode(layout, kind, wire)
    assert_eq((report.kind, report.report_id), (kind, id))
    let mut scalar_count = 0
    let mut opaque_count = 0
    for field in layout.fields {
      if field.kind == kind && field.report_id == id && (field.flags & 1) == 0 {
        if field.bit_size <= 32 {
          scalar_count = scalar_count + field.count
        } else {
          opaque_count = opaque_count + field.count
        }
      }
    }
    assert_eq(report.values.length(), scalar_count)
    assert_eq(report.opaque_values.length(), opaque_count)
    for value in report.values {
      assert_true(
        value.field_index >= 0 && value.field_index < layout.fields.length(),
      )
      let field = layout.fields[value.field_index]
      assert_eq((field.kind, field.report_id, field.flags & 1), (kind, id, 0))
      assert_true(field.bit_size <= 32)
      assert_true(value.element_index >= 0 && value.element_index < field.count)
      assert_eq(
        value.bit_offset,
        field.bit_offset + value.element_index * field.bit_size,
      )
      assert_true(
        value.bit_offset >= 0 && value.bit_offset + field.bit_size <= bits,
      )
      let minimum = if field.logical_min < 0 {
        -(1L << (field.bit_size - 1))
      } else {
        0L
      }
      let maximum = if field.logical_min < 0 {
        (1L << (field.bit_size - 1)) - 1
      } else {
        (1L << field.bit_size) - 1
      }
      assert_true(value.value >= minimum && value.value <= maximum)
      assert_eq(
        value.in_logical_range,
        value.value >= field.logical_min && value.value <= field.logical_max,
      )
      assert_eq(value.is_array, (field.flags & 2) == 0)
      assert_eq(
        value.is_null,
        !value.in_logical_range && (field.flags & 64) != 0,
      )
      match value.usage {
        Some(usage) =>
          assert_true(
            field.usage_spans.any(s => {
              s.page == usage.page && s.min <= usage.id && usage.id <= s.max
            }),
          )
        None => ()
      }
      if value.is_array && !value.in_logical_range {
        assert_eq(value.usage, None)
      }
    }
    for value in report.opaque_values {
      assert_true(
        value.field_index >= 0 && value.field_index < layout.fields.length(),
      )
      let field = layout.fields[value.field_index]
      assert_eq((field.kind, field.report_id, field.flags & 1), (kind, id, 0))
      assert_true(field.bit_size > 32 && field.bit_size <= 65536)
      assert_true(value.element_index >= 0 && value.element_index < field.count)
      assert_eq(
        value.bit_offset,
        field.bit_offset + value.element_index * field.bit_size,
      )
      assert_eq(value.bit_size, field.bit_size)
      assert_true(
        value.bit_offset >= 0 && value.bit_offset + value.bit_size <= bits,
      )
      assert_eq(value.bytes.length(), (value.bit_size + 7) / 8)
      let tail_bits = value.bit_size % 8
      if tail_bits != 0 {
        assert_eq(
          value.bytes[value.bytes.length() - 1].to_int() >> tail_bits,
          0,
        )
      }
    }
    assert_true(
      @moonhid.decode_report(layout, kind, wire + b"\x00")
      is Err({ code: "report_length", .. }),
    )
  }
  reports.length()
}

///|
fn fuzz_descriptor(bytes : Bytes, rng : FuzzRng) -> Int raise {
  let parsed = match @moonhid.parse_items(bytes) {
    Ok(items) => {
      assert_true(items.length() <= bytes.length() && items.length() <= 65536)
      let mut end = 0
      for item in items {
        assert_eq(item.offset, end)
        end = item.offset +
          (if item.is_long { 3 } else { 1 }) +
          item.data.length()
        assert_true(end <= bytes.length())
      }
      assert_eq(end, bytes.length())
      true
    }
    Err(error) => {
      fuzz_diagnostic(error, bytes.length())
      assert_true(
        error.code == "descriptor_limit" || error.code == "truncated_item",
      )
      false
    }
  }
  match @moonhid.compile_descriptor(bytes) {
    Ok(layout) => {
      assert_true(parsed)
      fuzz_reports(layout, rng)
    }
    Err(error) => {
      fuzz_diagnostic(error, bytes.length())
      0
    }
  }
}

///|
fn fuzz_u32(value : Int64) -> Bytes {
  Bytes::makei(4, i => ((value >> (8 * i)) & 255L).to_int().to_byte())
}

///|
fn fuzz_structured(iteration : Int, rng : FuzzRng) -> Bytes {
  let mut bytes = b"\x05\x01\x09\x05\xa1\x01"
  for direction = 0; direction < 3; direction = direction + 1 {
    if iteration % 2 == 0 {
      bytes = bytes + b"\x85" + Bytes::make(1, (direction + 1).to_byte())
    }
    let fields = 1 + rng.below(4)
    for index = 0; index < fields; index = index + 1 {
      let mode = (iteration + direction + index) % 4
      let width = if mode == 2 {
        33 + rng.below(64)
      } else if mode == 3 {
        1 + rng.below(96)
      } else {
        [1, 7, 8, 16, 31, 32][rng.below(6)]
      }
      let signed = mode != 3 && rng.below(2) == 0
      let bound_bits = if width > 32 { 8 } else { width }
      let mut minimum = if signed { -(1L << (bound_bits - 1)) } else { 0L }
      let mut maximum = if signed {
        (1L << (bound_bits - 1)) - 1
      } else {
        (1L << bound_bits) - 1
      }
      if bound_bits >= 3 && rng.below(2) == 0 {
        minimum = minimum / 2
        maximum = maximum / 2
      }
      let flags = if mode == 3 {
        1
      } else {
        (if mode == 0 { 0 } else { 2 }) |
        (if rng.below(2) == 0 { 64 } else { 0 })
      }
      let usage_min = rng.below(100)
      let usage_max = usage_min + rng.below(16)
      bytes = bytes +
        b"\xa4\x05" +
        Bytes::make(1, (1 + rng.below(9)).to_byte()) +
        b"\x19" +
        Bytes::make(1, usage_min.to_byte()) +
        b"\x29" +
        Bytes::make(1, usage_max.to_byte())
      if (iteration + index) % 3 == 0 {
        bytes = bytes + b"\x79\x02\x49\x01\x59\x04"
      }
      if (iteration + index) % 5 == 0 {
        bytes = bytes + b"\xa9\x01\x09\x01\xa8\xa9\x01\x09\x02\xa8"
      }
      bytes = bytes +
        b"\x17" +
        fuzz_u32(minimum) +
        b"\x27" +
        fuzz_u32(maximum) +
        b"\x77" +
        fuzz_u32(width.to_int64()) +
        b"\x97" +
        fuzz_u32((1 + rng.below(8)).to_int64()) +
        Bytes::make(1, [0x81, 0x91, 0xb1][direction].to_byte()) +
        Bytes::make(1, flags.to_byte()) +
        b"\xb4"
    }
  }
  bytes + b"\xc0"
}

///|
test "fuzz seed 4d484944: 2000 arbitrary descriptors and byte limits" {
  let rng : FuzzRng = { state: 0x4d484944U, }
  for iteration = 0; iteration < 2000; iteration = iteration + 1 {
    let bytes = Bytes::makei(rng.below(257), _ => rng.below(256).to_byte())
    ignore(fuzz_descriptor(bytes, rng))
  }
  ignore(fuzz_descriptor(Bytes::make(65536, 0), rng))
  ignore(fuzz_descriptor(Bytes::make(65537, 0), rng))
}

///|
test "fuzz seed 13579bdf: 500 valid structured layouts and 1500 reports" {
  let rng : FuzzRng = { state: 0x13579bdfU, }
  let mut opaque_fields = 0
  let mut scalar_fields = 0
  let mut array_fields = 0
  for iteration = 0; iteration < 500; iteration = iteration + 1 {
    let bytes = fuzz_structured(iteration, rng)
    let layout = match @moonhid.compile_descriptor(bytes) {
      Ok(layout) => layout
      Err(error) =>
        fail("structured case \{iteration}: \{error.code} @\{error.offset}")
    }
    for field in layout.fields {
      if (field.flags & 1) != 0 {
        continue
      }
      if field.bit_size > 32 {
        opaque_fields = opaque_fields + 1
      } else {
        scalar_fields = scalar_fields + 1
      }
      if (field.flags & 2) == 0 {
        array_fields = array_fields + 1
      }
    }
    assert_eq(fuzz_descriptor(bytes, rng), 3)
  }
  assert_true(opaque_fields > 500 && scalar_fields > 500 && array_fields > 500)
}

///|
test "fuzz seed a5a5c3c3: 280 mutations of seven real descriptors" {
  let rng : FuzzRng = { state: 0xa5a5c3c3U, }
  let mut reports = 0
  for
    text in [
      real_device_a(),
      real_device_b(),
      real_device_c(),
      real_device_d(),
      real_device_e(),
      real_device_f(),
      real_device_g(),
    ] {
    let source = match @moonhid.parse_hex(text) {
      Ok(bytes) => bytes
      Err(_) => fail("bad fixture")
    }
    for iteration = 0; iteration < 40; iteration = iteration + 1 {
      let position = rng.below(source.length())
      let random_byte = rng.below(256).to_byte()
      let changed = match iteration % 4 {
        0 =>
          Bytes::makei(source.length(), i => {
            if i == position {
              (source[i].to_int() ^ (1 << rng.below(8))).to_byte()
            } else {
              source[i]
            }
          })
        1 =>
          Bytes::makei(source.length() - 1, i => {
            source[if i < position { i } else { i + 1 }]
          })
        2 =>
          Bytes::makei(source.length() + 1, i => {
            if i == position {
              random_byte
            } else {
              source[if i < position { i } else { i - 1 }]
            }
          })
        _ => Bytes::makei(rng.below(source.length() + 1), i => source[i])
      }
      reports = reports + fuzz_descriptor(changed, rng)
    }
  }
  assert_true(reports > 0)
}
