///|
priv enum Command {
  Inspect(String)
  Lint(String)
  Decode(@hid.ReportKind, String, String)
  Help
}

///|
fn usage() -> String {
  "moonhid inspect <descriptor.hex>\nmoonhid lint <descriptor.hex>\nmoonhid decode --kind input|output|feature <descriptor.hex> <report.hex>"
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
// A successful operation can still use exit 3 for lint Warnings. Keep this
// distinct from Diagnostic failures, whose message belongs on stderr.
fn execute(command : Command) -> Result[(String, Int), @hid.Diagnostic] {
  match command {
    Help => Ok((usage(), 0))
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
