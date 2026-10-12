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

///|
test "consumer and vendor templates match TinyUSB descriptor macros" {
  // Expansions of TUD_HID_REPORT_DESC_CONSUMER() and
  // TUD_HID_REPORT_DESC_GENERIC_INOUT(64) from TinyUSB hid_device.h.
  let consumer = match @examples.consumer_descriptor() {
    Ok(bytes) => bytes
    Err(error) => fail(error.code)
  }
  assert_eq(
    @hid.format_hex(consumer),
    "05 0c 09 01 a1 01 15 00 26 ff 03 19 00 2a ff 03 95 01 75 10 81 00 c0",
  )
  let vendor = match @examples.vendor_descriptor() {
    Ok(bytes) => bytes
    Err(error) => fail(error.code)
  }
  assert_eq(
    @hid.format_hex(vendor),
    "06 00 ff 09 01 a1 01 09 02 15 00 26 ff 00 75 08 95 40 81 02 09 03 15 00 26 ff 00 75 08 95 40 91 02 c0",
  )
  assert_true(@examples.vendor_descriptor(report_bytes=8) is Ok(_))
  assert_true(
    @examples.vendor_descriptor(report_bytes=0)
    is Err({ code: "report_count", .. }),
  )
  assert_true(
    @examples.vendor_descriptor(report_bytes=8193)
    is Err({ code: "report_count", .. }),
  )
  let layout = match @hid.compile_descriptor(consumer) {
    Ok(layout) => layout
    Err(error) => fail(error.code)
  }
  let idle = match @hid.new_report(layout, @hid.Input, 0) {
    Ok(bytes) => bytes
    Err(error) => fail(error.code)
  }
  assert_eq(idle, b"\x00\x00")
  let volume_up = match
    @hid.set_usages(layout, @hid.Input, idle, [{ page: 0x0c, id: 0xe9, }]) {
    Ok(bytes) => bytes
    Err(error) => fail(error.code)
  }
  assert_eq(volume_up, b"\xe9\x00")
  assert_eq(
    @hid.clear_usages(layout, @hid.Input, volume_up, [{ page: 0x0c, id: 0xe9, }]),
    Ok(idle),
  )
}

///|
test "every template passes lint without Warning or Info" {
  for
    result in [
      @examples.mouse_descriptor(),
      @examples.keyboard_descriptor(),
      @examples.gamepad_descriptor(),
      @examples.consumer_descriptor(),
      @examples.vendor_descriptor(),
    ] {
    let bytes = match result {
      Ok(bytes) => bytes
      Err(error) => fail(error.code)
    }
    let lints = match @hid.lint_descriptor(bytes) {
      Ok(lints) => lints
      Err(error) => fail(error.code)
    }
    assert_eq(lints.map(l => l.code), [])
  }
}
