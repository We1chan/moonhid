///|
fn layout(hex : String) -> @hid.Layout {
  match @hid.parse_hex(hex) {
    Ok(bytes) =>
      match @hid.compile_descriptor(bytes) {
        Ok(layout) => layout
        Err(_) => abort("invalid fixture")
      }
    Err(_) => abort("invalid hex fixture")
  }
}

///|
test "unnumbered keyboard Input and LED Output frame conversion" {
  let keyboard = match @examples.keyboard_descriptor() {
    Ok(bytes) =>
      match @hid.compile_descriptor(bytes) {
        Ok(layout) => layout
        Err(_) => abort("keyboard")
      }
    Err(_) => abort("keyboard")
  }
  let input = b"\x02\x00\x04\x00\x00\x00\x00\x00"
  assert_eq(@transport.to_hidapi(keyboard, @hid.Input, input), Ok(input))
  assert_eq(@transport.from_hidapi(keyboard, @hid.Input, input), Ok(input))
  assert_eq(
    @transport.to_hidapi(keyboard, @hid.Output, b"\x02"),
    Ok(b"\x00\x02"),
  )
  assert_eq(
    @transport.from_hidapi(keyboard, @hid.Output, b"\x00\xe2"),
    Ok(b"\xe2"),
  )
  assert_eq(
    @transport.to_webhid(keyboard, @hid.Output, b"\x03"),
    Ok({ report_id: 0, payload: b"\x03", }),
  )
  assert_eq(
    @transport.from_webhid(keyboard, @hid.Output, {
      report_id: 0,
      payload: b"\xe2",
    }),
    Ok(b"\xe2"),
  )
}

///|
test "numbered reports preserve exactly one ID in all directions" {
  let device = layout("85 07 75 08 95 01 81 02 91 02 b1 02")
  for kind in [@hid.Input, @hid.Output, @hid.Feature] {
    let wire = b"\x07\xa5"
    assert_eq(@transport.to_hidapi(device, kind, wire), Ok(wire))
    assert_eq(@transport.from_hidapi(device, kind, wire), Ok(wire))
    assert_eq(
      @transport.to_webhid(device, kind, wire),
      Ok({ report_id: 7, payload: b"\xa5", }),
    )
    assert_eq(
      @transport.from_webhid(device, kind, { report_id: 7, payload: b"\xa5", }),
      Ok(wire),
    )
  }
}

///|
test "unnumbered Feature has mandatory API prefix and exact payload length" {
  let device = layout("75 08 95 02 b1 02")
  assert_eq(
    @transport.to_hidapi(device, @hid.Feature, b"\xff\x00"),
    Ok(b"\x00\xff\x00"),
  )
  assert_eq(
    @transport.from_hidapi(device, @hid.Feature, b"\x00\xff\x00"),
    Ok(b"\xff\x00"),
  )
  for buffer in [b"", b"\x01\xff\x00"] {
    assert_true(
      @transport.from_hidapi(device, @hid.Feature, buffer)
      is Err({ code: "transport_id", .. }),
    )
  }
  assert_true(
    @transport.from_hidapi(device, @hid.Feature, b"\x00\xff")
    is Err({ code: "report_length", .. }),
  )
}

///|
test "invalid WebHID IDs and unknown numbered reports are rejected" {
  let device = layout("75 08 95 01 81 02")
  for id in [-1, 1, 256] {
    assert_true(
      @transport.from_webhid(device, @hid.Input, {
        report_id: id,
        payload: b"\x00",
      })
      is Err({ code: "transport_id", .. }),
    )
  }
  let numbered = layout("85 07 75 08 95 01 81 02")
  assert_true(
    @transport.from_webhid(numbered, @hid.Input, {
      report_id: 8,
      payload: b"\x00",
    })
    is Err({ code: "unknown_report", .. }),
  )
  assert_true(
    @transport.to_webhid(numbered, @hid.Input, b"\x07")
    is Err({ code: "report_length", .. }),
  )
  assert_true(
    @transport.to_hidapi(numbered, @hid.Output, b"\x07\x00")
    is Err({ code: "unknown_report", .. }),
  )
}
