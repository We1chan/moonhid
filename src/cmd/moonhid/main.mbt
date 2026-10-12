///|
priv enum Command {
  Inspect(String)
  Lint(String)
  Decode(@hid.ReportKind, String, String)
  Encode(@hid.ReportKind, Int, String, String)
  Generate(String)
  Help
}

///|
fn usage() -> String {
  "moonhid inspect <descriptor.hex>\nmoonhid lint <descriptor.hex>\nmoonhid decode --kind input|output|feature <descriptor.hex> <report.hex>\nmoonhid encode --kind input|output|feature --id 0..255 <descriptor.hex> <values.json>\nmoonhid generate mouse|keyboard|gamepad|consumer|vendor"
}

///|
fn parse_kind(text : String) -> Result[@hid.ReportKind, String] {
  match text {
    "input" => Ok(@hid.Input)
    "output" => Ok(@hid.Output)
    "feature" => Ok(@hid.Feature)
    _ => Err("report_kind @0: Choose input, output or feature")
  }
}

///|
fn write_stderr(message : String) -> Unit {
  write_stderr_bytes(@utf8.encode(message))
}

///|
fn parse_command(args : Array[String]) -> Result[Command, String] {
  match args {
    ["--help"] | ["-h"] => Ok(Help)
    ["inspect", path] => Ok(Inspect(path))
    ["lint", path] => Ok(Lint(path))
    ["generate", name] => {
      if !["mouse", "keyboard", "gamepad", "consumer", "vendor"].contains(name) {
        return Err(
          "template @0: Choose mouse, keyboard, gamepad, consumer or vendor",
        )
      }
      Ok(Generate(name))
    }
    ["decode", "--kind", kind, descriptor, report] => {
      let kind = match parse_kind(kind) {
        Ok(kind) => kind
        Err(error) => return Err(error)
      }
      Ok(Decode(kind, descriptor, report))
    }
    ["encode", "--kind", kind, "--id", id_text, descriptor, values] => {
      let kind = match parse_kind(kind) {
        Ok(kind) => kind
        Err(error) => return Err(error)
      }
      let id = @string.parse_int(id_text) catch {
        _ => return Err("report_id @0: Report ID must be 0..255")
      }
      if id < 0 || id > 255 {
        return Err("report_id @0: Report ID must be 0..255")
      }
      Ok(Encode(kind, id, descriptor, values))
    }
    _ => Err("arguments @0: Invalid command or argument count")
  }
}

///|
fn values_error(offset : Int, message : String) -> @hid.Diagnostic {
  { offset, code: "values_json", message, }
}

///|
fn read_values(path : String) -> Result[Json, @hid.Diagnostic] {
  let text = @fs.read_file_to_string(path) catch {
    _ =>
      return Err({
        offset: 0,
        code: "file_read",
        message: "Cannot read values file: \{path}",
      })
  }
  let json = @json.parse(text) catch {
    _ => return Err(values_error(0, "Values file must contain valid JSON"))
  }
  Ok(json)
}

///|
fn json_integer(number : Double, index : Int) -> Result[Int64, @hid.Diagnostic] {
  if number < -2147483648.0 || number > 4294967295.0 {
    return Err({
      offset: index,
      code: "value_range",
      message: "Integer exceeds the supported 32-bit domain",
    })
  }
  let value = number.to_int64()
  if value.to_double() != number {
    return Err(
      values_error(index, "Report integers cannot have fractional values"),
    )
  }
  Ok(value)
}

///|
fn raw_value(hex : String) -> Result[@hid.ReportValue, @hid.Diagnostic] {
  match @hid.parse_hex(hex) {
    Ok(bytes) => Ok(@hid.Raw(bytes))
    Err(error) => Err(error)
  }
}

///|
/// The positional form: every non-Constant element in field/element order.
fn positional_values(
  items : Array[Json],
) -> Result[Array[@hid.ReportValue], @hid.Diagnostic] {
  if items.length() > 65536 {
    return Err({
      offset: 0,
      code: "value_count",
      message: "More than 65536 values",
    })
  }
  let values : Array[@hid.ReportValue] = []
  for index = 0; index < items.length(); index = index + 1 {
    match items[index] {
      Number(number, ..) =>
        match json_integer(number, index) {
          Ok(value) => values.push(@hid.Integer(value))
          Err(error) => return Err(error)
        }
      Object(object) => {
        let hex = match object.get("hex") {
          Some(String(hex)) if object.length() == 1 => hex
          _ =>
            return Err(
              values_error(
                index, "Raw values require an object containing only a hex string",
              ),
            )
        }
        match raw_value(hex) {
          Ok(value) => values.push(value)
          Err(error) => return Err(error)
        }
      }
      _ =>
        return Err(
          values_error(index, "Values must be integers or raw hex objects"),
        )
    }
  }
  Ok(values)
}

///|
fn usage_part(object : Map[String, Json], name : String) -> Int? {
  match object.get(name) {
    Some(Number(number, ..)) if number >= 0.0 &&
      number <= 65535.0 &&
      number.to_int().to_double() == number => Some(number.to_int())
    _ => None
  }
}

///|
/// Reads {"page": 0..65535, "id": 0..65535} plus the listed extra keys.
fn json_usage(
  entry : Json,
  index : Int,
  extra : Array[String],
) -> Result[(@hid.Usage, Map[String, Json]), @hid.Diagnostic] {
  let object = match entry {
    Object(object) => object
    _ => return Err(values_error(index, "Usage entries must be JSON objects"))
  }
  for key, _ in object {
    if key != "page" && key != "id" && !extra.contains(key) {
      return Err(values_error(index, "Unknown key in Usage entry: \{key}"))
    }
  }
  match (usage_part(object, "page"), usage_part(object, "id")) {
    (Some(page), Some(id)) => Ok(({ page, id, }, object))
    _ => Err(values_error(index, "Usage page and id must be integers 0..65535"))
  }
}

///|
fn usage_list(
  object : Map[String, Json],
  key : String,
) -> Result[Array[Json], @hid.Diagnostic] {
  match object.get(key) {
    None => Ok([])
    Some(Array(entries)) => Ok(entries)
    Some(_) => Err(values_error(0, "\{key} must be a JSON array"))
  }
}

///|
/// The Usage form starts from new_report, then applies "values"
/// (integers or raw hex), "physical" quantities and "active" on/off Usages.
fn usage_report(
  layout : @hid.Layout,
  kind : @hid.ReportKind,
  id : Int,
  object : Map[String, Json],
) -> Result[Bytes, @hid.Diagnostic] {
  for key, _ in object {
    if !["values", "physical", "active"].contains(key) {
      return Err(values_error(0, "Unknown top-level key: \{key}"))
    }
  }
  let mut wire = match @hid.new_report(layout, kind, id) {
    Ok(wire) => wire
    Err(error) => return Err(error)
  }
  let values = match usage_list(object, "values") {
    Ok(entries) => entries
    Err(error) => return Err(error)
  }
  for index, entry in values {
    let (usage, fields) = match json_usage(entry, index, ["value", "hex"]) {
      Ok(parsed) => parsed
      Err(error) => return Err(error)
    }
    let value = match (fields.get("value"), fields.get("hex")) {
      (Some(Number(number, ..)), None) =>
        match json_integer(number, index) {
          Ok(value) => @hid.Integer(value)
          Err(error) => return Err(error)
        }
      (None, Some(String(hex))) =>
        match raw_value(hex) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
      _ =>
        return Err(
          values_error(
            index, "Value entries need an integer value or a hex string",
          ),
        )
    }
    wire = match @hid.set_usage_value(layout, kind, wire, usage, value) {
      Ok(wire) => wire
      Err(error) => return Err(error)
    }
  }
  let physical = match usage_list(object, "physical") {
    Ok(entries) => entries
    Err(error) => return Err(error)
  }
  for index, entry in physical {
    let (usage, fields) = match json_usage(entry, index, ["value"]) {
      Ok(parsed) => parsed
      Err(error) => return Err(error)
    }
    let quantity = match fields.get("value") {
      Some(Number(number, ..)) => number
      _ =>
        return Err(values_error(index, "Physical entries need a numeric value"))
    }
    wire = match @hid.set_physical_value(layout, kind, wire, usage, quantity) {
      Ok(wire) => wire
      Err(error) => return Err(error)
    }
  }
  let active = match usage_list(object, "active") {
    Ok(entries) => entries
    Err(error) => return Err(error)
  }
  let usages : Array[@hid.Usage] = []
  for index, entry in active {
    match json_usage(entry, index, []) {
      Ok((usage, _)) => usages.push(usage)
      Err(error) => return Err(error)
    }
  }
  @hid.set_usages(layout, kind, wire, usages)
}

///|
fn read_hex(path : String) -> Result[Bytes, @hid.Diagnostic] {
  let text = @fs.read_file_to_string(path) catch {
    _ =>
      return Err({
        offset: 0,
        code: "file_read",
        message: "Cannot read hex file: \{path}",
      })
  }
  @hid.parse_hex(text)
}

///|
// A successful operation can still use exit 3 for lint Warnings. Keep this
// distinct from Diagnostic failures, whose message belongs on stderr.
fn execute(command : Command) -> Result[(String, Int), @hid.Diagnostic] {
  match command {
    Help => Ok((usage(), 0))
    Generate(name) => {
      let result = match name {
        "mouse" => @examples.mouse_descriptor()
        "keyboard" => @examples.keyboard_descriptor()
        "gamepad" => @examples.gamepad_descriptor()
        "consumer" => @examples.consumer_descriptor()
        _ => @examples.vendor_descriptor()
      }
      match result {
        Ok(bytes) => Ok((@hid.format_hex(bytes), 0))
        Err(error) => Err(error)
      }
    }
    Encode(kind, id, descriptor_path, values_path) => {
      let descriptor = match read_hex(descriptor_path) {
        Ok(bytes) => bytes
        Err(error) => return Err(error)
      }
      let layout = match @hid.compile_descriptor(descriptor) {
        Ok(layout) => layout
        Err(error) => return Err(error)
      }
      let encoded = match read_values(values_path) {
        Ok(Array(items)) =>
          match positional_values(items) {
            Ok(values) => @hid.encode_report(layout, kind, id, values)
            Err(error) => Err(error)
          }
        Ok(Object(object)) => usage_report(layout, kind, id, object)
        Ok(_) => Err(values_error(0, "Values must be a JSON array or object"))
        Err(error) => Err(error)
      }
      match encoded {
        Ok(bytes) => Ok((@hid.format_hex(bytes), 0))
        Err(error) => Err(error)
      }
    }
    Inspect(path) => {
      let bytes = match read_hex(path) {
        Ok(b) => b
        Err(e) => return Err(e)
      }
      match @hid.descriptor_to_json(bytes) {
        Ok(json) => Ok((json.stringify(), 0))
        Err(e) => Err(e)
      }
    }
    Lint(path) => {
      let bytes = match read_hex(path) {
        Ok(bytes) => bytes
        Err(error) => return Err(error)
      }
      let lints = match @hid.lint_descriptor(bytes) {
        Ok(lints) => lints
        Err(error) => return Err(error)
      }
      let output = lints
        .map(lint => {
          let level = match lint.level {
            @hid.Warning => "warning"
            @hid.Info => "info"
          }
          "\{level} \{lint.code} @\{lint.offset}: \{lint.message}"
        })
        .join("\n")
      Ok((output, if lints.any(l => l.level == @hid.Warning) { 3 } else { 0 }))
    }
    Decode(kind, descriptor_path, report_path) => {
      let descriptor = match read_hex(descriptor_path) {
        Ok(b) => b
        Err(e) => return Err(e)
      }
      let layout = match @hid.compile_descriptor(descriptor) {
        Ok(l) => l
        Err(e) => return Err(e)
      }
      let bytes = match read_hex(report_path) {
        Ok(b) => b
        Err(e) => return Err(e)
      }
      let report = match @hid.decode_report(layout, kind, bytes) {
        Ok(r) => r
        Err(e) => return Err(e)
      }
      let output : Json = {
        "schema_version": 2,
        "wire_hex": Json::string(@hid.format_hex(bytes)),
        "decoded": @hid.report_to_json(report),
      }
      Ok((output.stringify(), 0))
    }
  }
}

///|
fn main {
  let command = match parse_command(user_args()) {
    Ok(command) => command
    Err(message) => {
      write_stderr("\{message}\n\{usage()}\n")
      @sys.exit(2)
      return
    }
  }
  match execute(command) {
    Ok((output, status)) => {
      if !output.is_empty() {
        println(output)
      }
      if status != 0 {
        @sys.exit(status)
      }
    }
    Err(error) => {
      write_stderr("\{error.code} @\{error.offset}: \{error.message}\n")
      @sys.exit(1)
    }
  }
}
