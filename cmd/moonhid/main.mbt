///|
priv enum Command {
  Inspect(String)
  Decode(@hid.ReportKind, String, String)
  Help
}

///|
fn usage() -> String {
  "moonhid inspect <descriptor.hex>\nmoonhid decode --kind input|output|feature <descriptor.hex> <report.hex>"
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
    ["decode", "--kind", kind, descriptor, report] => {
      let kind = match kind {
        "input" => @hid.Input
        "output" => @hid.Output
        "feature" => @hid.Feature
        _ => return Err("report_kind @0: Choose input, output or feature")
      }
      Ok(Decode(kind, descriptor, report))
    }
    _ => Err("arguments @0: Invalid command or argument count")
  }
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
fn execute(command : Command) -> Result[String, @hid.Diagnostic] {
  match command {
    Help => Ok(usage())
    Inspect(path) => {
      let bytes = match read_hex(path) {
        Ok(b) => b
        Err(e) => return Err(e)
      }
      match @hid.descriptor_to_json(bytes) {
        Ok(json) => Ok(json.stringify())
        Err(e) => Err(e)
      }
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
      Ok(output.stringify())
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
    Ok(output) => println(output)
    Err(error) => {
      write_stderr("\{error.code} @\{error.offset}: \{error.message}\n")
      @sys.exit(1)
    }
  }
}
