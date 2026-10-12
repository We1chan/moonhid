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
  "moonhid inspect <descriptor.hex>\nmoonhid lint <descriptor.hex>\nmoonhid decode --kind input|output|feature <descriptor.hex> <report.hex>\nmoonhid encode --kind input|output|feature --id 0..255 <descriptor.hex> <values.json>\nmoonhid generate mouse|keyboard|gamepad"
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
      if !["mouse", "keyboard", "gamepad"].contains(name) {
        return Err("template @0: Choose mouse, keyboard or gamepad")
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
fn read_values(
  path : String,
) -> Result[Array[@hid.ReportValue], @hid.Diagnostic] {
  let text = @fs.read_file_to_string(path) catch {
    _ =>
      return Err({
        offset: 0,
        code: "file_read",
        message: "Cannot read values file: \{path}",
      })
  }
  let json = @json.parse(text) catch {
    _ =>
      return Err({
        offset: 0,
        code: "values_json",
        message: "Values file must contain valid JSON",
      })
  }
  let items = match json {
    Array(items) => items
    _ =>
      return Err({
        offset: 0,
        code: "values_json",
        message: "Values must be a JSON array",
      })
  }
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
      Number(number, ..) => {
        if number < -2147483648.0 || number > 4294967295.0 {
          return Err({
            offset: index,
            code: "value_range",
            message: "Integer exceeds the supported 32-bit domain",
          })
        }
        let value = number.to_int64()
        if value.to_double() != number {
          return Err({
            offset: index,
            code: "values_json",
            message: "Report integers cannot have fractional values",
          })
        }
        values.push(@hid.Integer(value))
      }
      Object(object) => {
        let hex = match object.get("hex") {
          Some(String(hex)) if object.length() == 1 => hex
          _ =>
            return Err({
              offset: index,
              code: "values_json",
              message: "Raw values require an object containing only a hex string",
            })
        }
        match @hid.parse_hex(hex) {
          Ok(bytes) => values.push(@hid.Raw(bytes))
          Err(error) => return Err(error)
        }
      }
      _ =>
        return Err({
          offset: index,
          code: "values_json",
          message: "Values must be integers or raw hex objects",
        })
    }
  }
  Ok(values)
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
        _ => @examples.gamepad_descriptor()
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
      let values = match read_values(values_path) {
        Ok(values) => values
        Err(error) => return Err(error)
      }
      match @hid.encode_report(layout, kind, id, values) {
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
