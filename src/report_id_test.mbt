///|
test "IDs and report directions retain independent bit cursors" {
  let layout = compile(
    "75 08 95 01 85 01 81 02 91 02 85 02 81 02 85 01 81 02 b1 02",
  )
  assert_true(layout.has_report_ids)
  assert_eq(layout.fields.map(f => (f.report_id, f.bit_offset)), [
    (1, 0),
    (1, 0),
    (2, 0),
    (1, 8),
    (1, 0),
  ])
}

///|
test "zero, wide and mixed report identifiers are rejected" {
  for text in ["85 00", "86 01 00", "75 08 95 01 81 02 85 01 81 02"] {
    let bytes = match @moonhid.parse_hex(text) {
      Ok(bytes) => bytes
      _ => fail("bad hex")
    }
    assert_true(@moonhid.compile_descriptor(bytes) is Err(_))
  }
}
