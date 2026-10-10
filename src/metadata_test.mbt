///|
test "nested and sibling collections retain usage parents and field membership" {
  let layout = compile(
    "05 01 09 02 a1 01 09 01 a1 00 15 81 25 7f 75 08 95 01 09 30 81 06 c0 09 03 a1 02 09 31 81 06 c0 c0",
  )
  assert_eq(layout.collections.length(), 3)
  assert_eq(layout.collections.map(c => c.parent_index), [
    None,
    Some(0),
    Some(0),
  ])
  assert_eq(layout.collections.map(c => c.usage), [
    Some({ page: 1, id: 2, }),
    Some({ page: 1, id: 1, }),
    Some({ page: 1, id: 3, }),
  ])
  assert_eq(layout.collections.map(c => c.collection_type), [1, 0, 2])
  assert_eq(layout.fields.map(f => f.collection_index), [Some(1), Some(2)])
  assert_eq(layout.collections[0].descriptor_offset, 4)
  assert_eq(layout.collections[1].end_offset, 22)
  assert_eq(layout.collections[0].end_offset, 32)
  assert_eq(compile("75 08 95 01 81 02").fields[0].collection_index, None)
}

///|
test "physical metadata and signed Unit Exponent survive Global Push Pop" {
  let layout = compile(
    "15 81 25 7f 36 99 f3 46 67 0c 55 0c 65 13 75 08 95 01 a4 35 00 45 ff 55 00 65 11 81 02 b4 81 06",
  )
  assert_eq(layout.fields[0].physical_min, Some(0L))
  assert_eq(layout.fields[0].physical_max, Some(255L))
  assert_eq(layout.fields[1].physical_min, Some(-3175L))
  assert_eq(layout.fields[1].physical_max, Some(3175L))
  assert_eq(layout.fields[1].unit_exponent, Some(-4))
  assert_eq(layout.fields[1].unit, Some(0x13L))
  assert_eq(
    @moonhid.effective_physical_range(layout.fields[1]),
    (-3175L, 3175L),
  )
}

///|
test "physical defaults preserve absence and declared zero ranges" {
  let layout = compile("15 81 25 7f 75 08 95 01 81 02 35 00 81 02 45 00 81 02")
  assert_eq(layout.fields[0].physical_min, None)
  for field in layout.fields {
    assert_eq(@moonhid.effective_physical_range(field), (-127L, 127L))
  }
}

///|
test "unit nibbles decode compound dimensions and preserve reserved values" {
  match @moonhid.decode_unit(0xe121L) {
    Ok(unit) => {
      assert_eq((unit.system, unit.length, unit.mass, unit.time), (1, 2, 1, -2))
      assert_eq(unit.raw, 0xe121L)
    }
    _ => fail("valid Unit rejected")
  }
  assert_true(@moonhid.decode_unit(-1L) is Err({ code: "unit_range", .. }))
  assert_true(@moonhid.decode_unit(4294967296L) is Err(_))
  let layout = compile("75 08 95 01 55 fe 81 02")
  assert_eq(layout.fields[0].unit_exponent, Some(-2))
  assert_true(
    @moonhid.compile_descriptor(b"\x55\x10")
    is Err({ code: "unit_exponent", .. }),
  )
}
