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
      "schema_version": 1,
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
