///|
fn failure(stage : String, error : @hid.Diagnostic) -> String {
  let result : Json = {
    "ok": false,
    "schema_version": 2,
    "stage": Json::string(stage),
    "error": @hid.diagnostic_to_json(error),
  }
  result.stringify()
}

///|
/// Native JavaScript strings in, versioned JSON strings out. Successful
/// inspection includes descriptor.lints; Warnings do not make ok=false.
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
    "schema_version": 2,
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
  let (layout, kind) = match report_context(descriptor_hex, kind) {
    Ok(context) => context
    Err(error) => return error
  }
  let wire = match @hid.parse_hex(report_hex) {
    Ok(wire) => wire
    Err(error) => return failure("report_hex", error)
  }
  wire_result(layout, kind, wire)
}

///|
fn report_context(
  descriptor_hex : String,
  kind : String,
) -> Result[(@hid.Layout, @hid.ReportKind), String] {
  let kind = match kind {
    "input" => @hid.Input
    "output" => @hid.Output
    "feature" => @hid.Feature
    _ =>
      return Err(
        failure("report", {
          offset: 0,
          code: "report_kind",
          message: "Choose input, output or feature",
        }),
      )
  }
  let bytes = match @hid.parse_hex(descriptor_hex) {
    Ok(bytes) => bytes
    Err(error) => return Err(failure("descriptor_hex", error))
  }
  let layout = match @hid.compile_descriptor(bytes) {
    Ok(layout) => layout
    Err(error) => return Err(failure("descriptor", error))
  }
  Ok((layout, kind))
}

///|
fn wire_result(
  layout : @hid.Layout,
  kind : @hid.ReportKind,
  wire : Bytes,
) -> String {
  let report = match @hid.decode_report(layout, kind, wire) {
    Ok(report) => report
    Err(error) => return failure("report", error)
  }
  let result : Json = {
    "ok": true,
    "schema_version": 2,
    "wire_hex": Json::string(@hid.format_hex(wire)),
    "decoded": @hid.report_to_json(report),
  }
  result.stringify()
}

///|
/// Initializes IDs, Null states and Array empty selectors in the MoonBit core.
pub fn initialize_wire(
  descriptor_hex : String,
  kind : String,
  report_id : Int32,
) -> String {
  let (layout, kind) = match report_context(descriptor_hex, kind) {
    Ok(context) => context
    Err(error) => return error
  }
  let wire = match @hid.new_report(layout, kind, report_id) {
    Ok(wire) => wire
    Err(error) => return failure("report", error)
  }
  wire_result(layout, kind, wire)
}

///|
/// Replaces one element, preserving ID, Constant, tail and neighboring bits.
/// Integers are decimal text; Raw/Buffered Bytes values are strict hex text.
pub fn write_wire_field(
  descriptor_hex : String,
  kind : String,
  report_hex : String,
  field_index : Int32,
  element_index : Int32,
  value_text : String,
) -> String {
  let (layout, kind) = match report_context(descriptor_hex, kind) {
    Ok(context) => context
    Err(error) => return error
  }
  let wire = match @hid.parse_hex(report_hex) {
    Ok(wire) => wire
    Err(error) => return failure("report_hex", error)
  }
  let current = match
    @hid.read_field(layout, kind, wire, field_index, element_index) {
    Ok(value) => value
    Err(error) => return failure("field", error)
  }
  let value = match current {
    @hid.Integer(_) => {
      let value = @string.parse_int64(value_text.trim(), base=10) catch {
        _ =>
          return failure("field_value", {
            offset: 0,
            code: "value_type",
            message: "Enter a decimal integer",
          })
      }
      @hid.Integer(value)
    }
    @hid.Raw(_) => {
      let bytes = match @hid.parse_hex(value_text) {
        Ok(bytes) => bytes
        Err(error) => return failure("field_value_hex", error)
      }
      @hid.Raw(bytes)
    }
  }
  let wire = match
    @hid.write_field(layout, kind, wire, field_index, element_index, value) {
    Ok(wire) => wire
    Err(error) => return failure("field", error)
  }
  wire_result(layout, kind, wire)
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
