///|
fn declaration_bytes(text : String) -> Bytes raise {
  match @moonhid.descriptor_from_declaration(text) {
    Ok(bytes) => bytes
    Err(error) => fail("\{error.code} @\{error.offset}: \{error.message}")
  }
}

///|
test "declarations use semantic defaults and exact raw widths" {
  let text =
    #|{"version":1,"items":[{"usage_page":1},{"usage":5},{"collection":"application","items":[
    #|{"usage":{"page":0,"id":"0x30"}},{"logical_range":[0,255]},
    #|{"report_size":8},{"report_count":1},{"unit_exponent":-4},{"input":["data","variable","absolute"]}]}]}
  let bytes = declaration_bytes(text)
  assert_eq(
    @moonhid.format_hex(bytes),
    "05 01 09 05 a1 01 0b 30 00 00 00 15 00 26 ff 00 75 08 95 01 55 0c 81 02 c0",
  )
  let exported = match @moonhid.declaration_from_descriptor(bytes) {
    Ok(json) => json.stringify()
    Err(error) => fail(error.code)
  }
  assert_eq(declaration_bytes(exported), bytes)
  let signed_text =
    #|{"version":1,"items":[{"logical_minimum":129,"size":1},{"logical_maximum":127},{"report_size":8},{"report_count":1},{"input":2}]}
  let signed = declaration_bytes(signed_text)
  assert_eq(@moonhid.format_hex(signed), "15 81 25 7f 75 08 95 01 81 02")
  let zero = b"\xa0\x04\x14\x24\x34\x44\x54\x64\x75\x01\x95\x01\x08\x80\xc0"
  let exported = match @moonhid.declaration_from_descriptor(zero) {
    Ok(json) => json.stringify()
    Err(error) => fail(error.code)
  }
  assert_eq(declaration_bytes(exported), zero)
}

///|
test "declarations preserve all seven real descriptors and metadata" {
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
      Err(error) => fail(error.code)
    }
    let declaration = match @moonhid.declaration_from_descriptor(bytes) {
      Ok(json) => json
      Err(error) => fail(error.code)
    }
    assert_eq(declaration_bytes(declaration.stringify()), bytes)
  }
  for
    bytes in [
      b"\x05\x09\xa9\x01\x09\x01\xa8\xa9\x01\x09\x02\xa8\x75\x01\x95\x01\x81\x02",
      b"\x7b\xff\xff\xff\xff\x39\x03\x75\x08\x95\x01\x81\x02", b"\x15\x00\x27\xff\xff\xff\xff\x75\x20\x95\x01\x81\x02",
      b"\x15\x81\x25\xff\x55\xfc\x75\x08\x95\x01\x81\x02", b"\x89\x01\x99\x03\x49\x02\x59\x04\x75\x08\x95\x01\x81\x02",
    ] {
    let declaration = match @moonhid.declaration_from_descriptor(bytes) {
      Ok(json) => json
      Err(error) => fail(error.code)
    }
    assert_eq(declaration_bytes(declaration.stringify()), bytes)
  }
}

///|
test "declaration errors have stable codes item indices and JSON paths" {
  for
    (text, code, offset, path) in [
      ("{", "declaration_json", 0, "$"),
      (
        "{\"version\":1,\"items\":[{\"report_size\":1e999}]}", "declaration_value",
        0, "$.items[0].report_size",
      ),
      ("{\"version\":2,\"items\":[]}", "declaration_value", 0, "$.version"),
      (
        "{\"version\":1,\"items\":[],\"other\":1}", "declaration_key", 0, "$.other",
      ),
      ("{\"version\":1,\"items\":{}}", "declaration_value", 0, "$.items"),
      (
        "{\"version\":1,\"items\":[{\"unknown\":1}]}", "declaration_key", 0, "$.items[0].unknown",
      ),
      (
        "{\"version\":1,\"items\":[{\"report_size\":1.5}]}", "declaration_value",
        0, "$.items[0].report_size",
      ),
      (
        "{\"version\":1,\"items\":[{\"report_size\":8,\"size\":3}]}", "declaration_value",
        0, "$.items[0].size",
      ),
      (
        "{\"version\":1,\"items\":[{\"report_size\":8,\"size\":0}]}", "declaration_value",
        0, "$.items[0].report_size",
      ),
      (
        "{\"version\":1,\"items\":[{\"input\":[\"variable\",\"array\"]}]}", "declaration_value",
        0, "$.items[0].input[1]",
      ),
      (
        "{\"version\":1,\"items\":[{\"input\":[\"unknown\"]}]}", "declaration_value",
        0, "$.items[0].input[0]",
      ),
      (
        "{\"version\":1,\"items\":[{\"pop\":true}]}", "declaration_value", 0, "$.items[0].pop",
      ),
      (
        "{\"version\":1,\"items\":[{\"push\":false}]}", "declaration_value", 0, "$.items[0].push",
      ),
      (
        "{\"version\":1,\"items\":[{\"usage\":{\"page\":65536,\"id\":1}}]}", "declaration_value",
        0, "$.items[0].usage",
      ),
      (
        "{\"version\":1,\"items\":[{\"unit\":\"0x100000000\"}]}", "declaration_value",
        0, "$.items[0].unit",
      ),
      (
        "{\"version\":1,\"items\":[{\"logical_range\":[1,0]}]}", "declaration_value",
        0, "$.items[0].logical_range",
      ),
      (
        "{\"version\":1,\"items\":[{\"usage_range\":[0,65536]}]}", "declaration_value",
        0, "$.items[0].usage_range",
      ),
      (
        "{\"version\":1,\"items\":[{\"input\":2,\"items\":[]}]}", "declaration_key",
        0, "$.items[0].items",
      ),
      (
        "{\"version\":1,\"items\":[{\"collection\":\"application\",\"items\":[{\"input\":2}]}]}",
        "declaration_value", 1, "$.items[0].items[0].input",
      ),
    ] {
    match @moonhid.descriptor_from_declaration(text) {
      Err(error) => {
        assert_eq(error.code, code)
        assert_eq(error.offset, offset)
        assert_true(error.message.contains(path))
      }
      Ok(_) => fail("Declaration should fail: \{text}")
    }
  }
  assert_true(
    @moonhid.declaration_from_descriptor(b"\xfe\x00\x80")
    is Err({ code: "unsupported_item", .. }),
  )
}

///|
test "declarations bound collection depth and global stack" {
  let mut children : Array[Json] = [
    { "report_size": 8 },
    { "report_count": 1 },
    { "input": 2 },
  ]
  for depth = 0; depth < 64; depth = depth + 1 {
    children = [{ "collection": "application", "items": Json::array(children) }]
  }
  let document : Json = { "version": 1, "items": Json::array(children) }
  let bytes = declaration_bytes(document.stringify())
  assert_eq(bytes.length(), 64 * 3 + 6)
  children = [{ "collection": "application", "items": Json::array(children) }]
  let too_deep : Json = { "version": 1, "items": Json::array(children) }
  assert_true(
    @moonhid.descriptor_from_declaration(too_deep.stringify())
    is Err({ code: "declaration_limit", .. }),
  )
  let pushes : Array[Json] = Array::make(65, { "push": true })
  let stack : Json = { "version": 1, "items": Json::array(pushes) }
  assert_true(
    @moonhid.descriptor_from_declaration(stack.stringify())
    is Err({ code: "declaration_limit", offset: 64, .. }),
  )
}

///|
test "declarations restore Report ID and signed Minimum after Pop" {
  let text =
    #|{"version":1,"items":[{"usage_page":1},{"logical_range":[-127,127]},
    #|{"report_size":8},{"report_count":1},{"report_id":1},{"usage":48},{"input":6},
    #|{"push":true},{"report_id":2},{"logical_range":[0,255]},{"usage":49},{"feature":2},
    #|{"pop":true},{"logical_maximum":-1},{"usage":50},{"input":6}]}
  let bytes = declaration_bytes(text)
  let layout = match @moonhid.compile_descriptor(bytes) {
    Ok(layout) => layout
    Err(error) => fail(error.code)
  }
  assert_eq(layout.fields[2].report_id, 1)
  assert_eq(layout.fields[2].logical_min, -127L)
  assert_eq(layout.fields[2].logical_max, -1L)
  assert_eq(layout.fields[2].bit_offset, 8)
  assert_eq(@moonhid.report_length(layout, @moonhid.Input, 1), Ok(3))
  let exported = match @moonhid.declaration_from_descriptor(bytes) {
    Ok(json) => json
    Err(error) => fail(error.code)
  }
  assert_eq(declaration_bytes(exported.stringify()), bytes)
}

///|
test "declarations name Buffered Bytes and preserve the full stream" {
  let text =
    #|{"version":1,"items":[{"report_id":5},{"report_size":8},{"report_count":4},{"input":["data","buffered_bytes"]}]}
  let bytes = declaration_bytes(text)
  assert_eq(@moonhid.format_hex(bytes), "85 05 75 08 95 04 82 00 01")
  let layout = match @moonhid.compile_descriptor(bytes) {
    Ok(layout) => layout
    Err(error) => fail(error.code)
  }
  let report = match
    @moonhid.decode_report(layout, @moonhid.Input, b"\x05\x00\xff\x01\x80") {
    Ok(report) => report
    Err(error) => fail(error.code)
  }
  assert_eq(report.values.length(), 0)
  assert_eq(report.buffered_values[0].bytes, b"\x00\xff\x01\x80")
}
