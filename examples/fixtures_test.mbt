///|
fn bytes(text : String) -> Bytes raise {
  match @hid.parse_hex(text) {
    Ok(bytes) => bytes
    _ => fail("invalid fixture hex")
  }
}

///|
test "three device scenarios compile and decode end to end" {
  for fixture in @examples.all() {
    let layout = match @hid.compile_descriptor(bytes(fixture.descriptor_hex)) {
      Ok(layout) => layout
      Err(error) => fail("\{fixture.name}: \{error.code}")
    }
    let report = match
      @hid.decode_report(layout, @hid.Input, bytes(fixture.input_hex)) {
      Ok(report) => report
      Err(error) => fail("\{fixture.name}: \{error.code}")
    }
    assert_eq(report.values.map(v => v.value), fixture.expected_values)
    if fixture.name == "keyboard" {
      assert_eq(report.values[1].usage, Some({ page: 7, id: 0xe1, }))
      assert_eq(report.values[8].usage, Some({ page: 7, id: 4, }))
      let leds = match @hid.decode_report(layout, @hid.Output, b"\x03") {
        Ok(leds) => leds
        _ => fail("keyboard LEDs rejected")
      }
      assert_eq(leds.values.map(v => v.value), [1L, 1L, 0L, 0L, 0L])
    }
  }
}

///|
test "synthetic fixtures produce no lint Warnings" {
  for fixture in @examples.all() {
    let lints = match @hid.lint_descriptor(bytes(fixture.descriptor_hex)) {
      Ok(lints) => lints
      Err(error) => fail("\{fixture.name}: \{error.code}")
    }
    assert_eq(lints.filter(l => l.level == @hid.Warning), [])
  }
}
