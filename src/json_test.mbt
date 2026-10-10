///|
test "versioned export round trips numbers metadata and report lengths" {
  let bytes = match
    @moonhid.parse_hex(
      "05 01 09 05 a1 01 85 07 15 00 27 ff ff ff ff 35 00 47 ff ff ff ff 55 0e 65 11 75 20 95 01 09 30 81 02 c0",
    ) {
    Ok(bytes) => bytes
    _ => fail("invalid test hex")
  }
  let exported = match @moonhid.descriptor_to_json(bytes) {
    Ok(json) => json
    _ => fail("valid descriptor rejected")
  }
  let parsed = @json.parse(exported.stringify())
  assert_eq(parsed, exported)
  assert_true(
    parsed
    is {
      "schema_version": 2,
      "layout": {
        "has_report_ids": true,
        "reports": [
          {
            "kind": "input",
            "report_id": 7,
            "payload_bits": 32,
            "wire_bytes": 5,
            ..
          },
        ],
        "fields": [
          {
            "logical_max": 4294967295,
            "physical_max": 4294967295,
            "unit_exponent": -2,
            "collection_index": 0,
            ..
          },
        ],
        ..
      },
      ..
    },
  )
  let report = decode(
    compile(@moonhid.format_hex(bytes)),
    @moonhid.Input,
    b"\x07\xff\xff\xff\xff",
  )
  assert_true(
    @moonhid.report_to_json(report)
    is { "values": [{ "value": 4294967295, "in_logical_range": true, .. }], .. },
  )
}

///|
test "JSON missing metadata is null and Constant layout is retained" {
  let layout = compile("75 01 95 03 81 01 15 00 25 01 75 01 95 05 81 02")
  assert_true(
    @moonhid.layout_to_json(layout)
    is {
      "collections": [],
      "fields": [
        {
          "physical_min": Null,
          "unit": Null,
          "collection_index": Null,
          "flags": 1,
          ..
        },
        _,
        ..,
      ],
      "reports": [{ "payload_bits": 8, "wire_bytes": 1, .. }],
      ..
    },
  )
  assert_eq(@moonhid.format_hex(b"\x00\x0a\xff"), "00 0a ff")
  assert_true(
    @moonhid.descriptor_to_json(b"\x75") is Err({ code: "truncated_item", .. }),
  )
}

///|
test "JSON lints preserve levels offsets optional field indices and schema v2" {
  let bytes = match
    @moonhid.parse_hex("05 01 a1 01 15 00 25 03 75 02 95 01 81 42 c0") {
    Ok(bytes) => bytes
    Err(_) => fail("invalid test hex")
  }
  let exported = match @moonhid.descriptor_to_json(bytes) {
    Ok(json) => json
    Err(_) => fail("Warnings must not reject JSON export")
  }
  let parsed = @json.parse(exported.stringify())
  assert_eq(parsed, exported)
  assert_true(
    parsed
    is {
      "schema_version": 2,
      "lints": [
        {
          "offset": 2,
          "code": "collection_without_usage",
          "level": "warning",
          "field_index": Null,
          ..
        },
        {
          "offset": 12,
          "code": "missing_usage",
          "level": "warning",
          "field_index": 0,
          ..
        },
        {
          "offset": 12,
          "code": "null_without_room",
          "level": "warning",
          "field_index": 0,
          ..
        },
        {
          "offset": 12,
          "code": "unaligned_report",
          "level": "info",
          "field_index": 0,
          ..
        },
      ],
      "layout": { "reports": [{ "payload_bits": 2, "wire_bytes": 1, .. }], .. },
      ..
    },
  )
  let info = @moonhid.lint_to_json({
    offset: 8,
    code: "logical_max_sign",
    level: @moonhid.Info,
    message: "positive extent",
    field_index: Some(0),
  })
  assert_true(
    info
    is {
      "offset": 8,
      "level": "info",
      "message": "positive extent",
      "field_index": 0,
      ..
    },
  )
}

///|
test "JSON export includes empty lints and retains the compiler Diagnostic" {
  let clean = b"\x05\x01\x09\x05\xa1\x01\x15\x00\x25\x01\x75\x08\x95\x01\x09\x30\x81\x02\xc0"
  assert_true(
    @moonhid.descriptor_to_json(clean)
    is Ok({ "schema_version": 2, "lints": [], .. }),
  )
  for bytes in [b"", b"\x75", b"\xc0", b"\xfe\x00\x42"] {
    let error = match @moonhid.compile_descriptor(bytes) {
      Err(error) => error
      Ok(_) => fail("expected compiler error")
    }
    assert_eq(@moonhid.descriptor_to_json(bytes), Err(error))
  }
}

///|
test "JSON lints agree with the core API on all saved real descriptors" {
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
    let bytes = match @moonhid.parse_hex(text) {
      Ok(bytes) => bytes
      Err(_) => fail("invalid corpus hex")
    }
    let core = match @moonhid.lint_descriptor(bytes) {
      Ok(lints) => lints
      Err(_) => fail("real descriptor rejected")
    }
    let json = match @moonhid.descriptor_to_json(bytes) {
      Ok(json) => json
      Err(_) => fail("real JSON export rejected")
    }
    let expected = Json::array(core.map(@moonhid.lint_to_json))
    assert_true(json is { "lints": actual, .. } && actual == expected)
  }
}
