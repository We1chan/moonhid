///|
test "generated device templates match independent descriptor and report fixtures" {
  for
    (fixture, result) in [
      (@examples.mouse(), @examples.mouse_descriptor()),
      (@examples.keyboard(), @examples.keyboard_descriptor()),
      (@examples.gamepad(), @examples.gamepad_descriptor()),
    ] {
    let descriptor = match result {
      Ok(bytes) => bytes
      Err(error) => fail(error.code)
    }
    assert_eq(@hid.format_hex(descriptor), fixture.descriptor_hex)
    let layout = match @hid.compile_descriptor(descriptor) {
      Ok(layout) => layout
      Err(error) => fail(error.code)
    }
    let wire = match
      @hid.encode_report(
        layout,
        @hid.Input,
        if layout.has_report_ids {
          7
        } else {
          0
        },
        fixture.expected_values.map(value => @hid.Integer(value)),
      ) {
      Ok(wire) => wire
      Err(error) => fail(error.code)
    }
    assert_eq(@hid.format_hex(wire), fixture.input_hex)
  }
}
