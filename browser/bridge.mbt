///|
fn failure(stage : String, error : @hid.Diagnostic) -> String {
  let result : Json = {
    "ok": false,
    "schema_version": 1,
    "stage": Json::string(stage),
    "error": @hid.diagnostic_to_json(error),
  }
  result.stringify()
}

///|
/// Native JavaScript strings in, versioned JSON strings out.
pub fn inspect_descriptor(descriptor_hex : String) -> String {
  let bytes = match @hid.parse_hex(descriptor_hex) {
    Ok(bytes) => bytes
    Err(error) => return failure("descriptor_hex", error)
  }
  let descriptor = match @hid.descriptor_to_json(bytes) {
    Ok(descriptor) => descriptor
    Err(error) => return failure("descriptor", error)
  }
  let result : Json = {
    "ok": true,
    "schema_version": 1,
    "descriptor": descriptor,
  }
  result.stringify()
}

///|
pub fn decode_wire(
  descriptor_hex : String,
  kind : String,
  report_hex : String,
) -> String {
  let kind = match kind {
    "input" => @hid.Input
    "output" => @hid.Output
    "feature" => @hid.Feature
    _ =>
      return failure("report", {
        offset: 0,
        code: "report_kind",
        message: "Choose input, output or feature",
      })
  }
  let bytes = match @hid.parse_hex(descriptor_hex) {
    Ok(bytes) => bytes
    Err(error) => return failure("descriptor_hex", error)
  }
  let layout = match @hid.compile_descriptor(bytes) {
    Ok(layout) => layout
    Err(error) => return failure("descriptor", error)
  }
  let wire = match @hid.parse_hex(report_hex) {
    Ok(wire) => wire
    Err(error) => return failure("report_hex", error)
  }
  let report = match @hid.decode_report(layout, kind, wire) {
    Ok(report) => report
    Err(error) => return failure("report", error)
  }
  let result : Json = {
    "ok": true,
    "schema_version": 1,
    "wire_hex": Json::string(@hid.format_hex(wire)),
    "decoded": @hid.report_to_json(report),
  }
  result.stringify()
}

///|
pub fn examples_json() -> String {
  let result = Json::array(
    @examples.all().map(fixture => {
      "name": Json::string(fixture.name),
      "descriptor_hex": Json::string(fixture.descriptor_hex),
      "input_hex": Json::string(fixture.input_hex),
      "expected_values": Json::array(
        fixture.expected_values.map(v => Json::number(v.to_double())),
      ),
      "output_hex": if fixture.name == "keyboard" {
        Json::string("03")
      } else {
        Json::null()
      },
    }),
  )
  result.stringify()
}
