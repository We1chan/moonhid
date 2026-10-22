///|
priv struct ReplayExpectation {
  values : Array[(@hid.Usage, @hid.ReportValue)]
  physical : Array[(@hid.Usage, Double)]
  active : Array[@hid.Usage]?
}

///|
fn replay_error(line : Int, message : String) -> @hid.Diagnostic {
  { offset: line, code: "replay_expect", message, }
}

///|
fn replay_file(path : String) -> Result[String, @hid.Diagnostic] {
  let text = @fs.read_file_to_string(path) catch {
    _ =>
      return Err({
        offset: 0,
        code: "file_read",
        message: "Cannot read replay file: \{path}",
      })
  }
  if text.length() > 8388608 {
    return Err({
      offset: 0,
      code: "replay_limit",
      message: "Replay file exceeds 8388608 UTF-16 units",
    })
  }
  Ok(text)
}

///|
fn expectation(json : Json) -> Result[ReplayExpectation, @hid.Diagnostic] {
  let object = match json {
    Object(object) => object
    _ => return Err(values_error(0, "Expected frame must be a Usage object"))
  }
  for key, _ in object {
    if !["values", "physical", "active"].contains(key) {
      return Err(values_error(0, "Unknown expected-frame key: \{key}"))
    }
  }
  let values = match usage_list(object, "values") {
    Ok(entries) => entries
    Err(error) => return Err(error)
  }
  let physical = match usage_list(object, "physical") {
    Ok(entries) => entries
    Err(error) => return Err(error)
  }
  let active = match usage_list(object, "active") {
    Ok(entries) => entries
    Err(error) => return Err(error)
  }
  if values.length() + physical.length() + active.length() > 65536 {
    return Err(values_error(0, "More than 65536 expected entries"))
  }
  let parsed_values : Array[(@hid.Usage, @hid.ReportValue)] = []
  let parsed_physical : Array[(@hid.Usage, Double)] = []
  let parsed_active : Array[@hid.Usage] = []
  let seen_values : Map[Int64, Bool] = Map([])
  for index, entry in values {
    let (usage, fields) = match json_usage(entry, index, ["value", "hex"]) {
      Ok(parsed) => parsed
      Err(error) => return Err(error)
    }
    if seen_values.contains(replay_usage_key(usage)) {
      return Err(values_error(index, "Duplicate Usage in values"))
    }
    seen_values[replay_usage_key(usage)] = true
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
            index, "Expected value needs an integer value or hex string",
          ),
        )
    }
    parsed_values.push((usage, value))
  }
  let seen_physical : Map[Int64, Bool] = Map([])
  for index, entry in physical {
    let (usage, fields) = match json_usage(entry, index, ["value"]) {
      Ok(parsed) => parsed
      Err(error) => return Err(error)
    }
    if seen_physical.contains(replay_usage_key(usage)) {
      return Err(values_error(index, "Duplicate Usage in physical"))
    }
    seen_physical[replay_usage_key(usage)] = true
    let value = match fields.get("value") {
      Some(Number(value, ..)) if !value.is_nan() && !value.is_inf() => value
      _ =>
        return Err(
          values_error(index, "Expected physical value must be finite"),
        )
    }
    parsed_physical.push((usage, value))
  }
  let seen_active : Map[Int64, Bool] = Map([])
  for index, entry in active {
    let (usage, _) = match json_usage(entry, index, []) {
      Ok(parsed) => parsed
      Err(error) => return Err(error)
    }
    if seen_active.contains(replay_usage_key(usage)) {
      return Err(values_error(index, "Duplicate Usage in active"))
    }
    parsed_active.push(usage)
    seen_active[replay_usage_key(usage)] = true
  }
  Ok({
    values: parsed_values,
    physical: parsed_physical,
    active: if object.contains("active") {
      Some(parsed_active)
    } else {
      None
    },
  })
}

///|
fn replay_expectations(
  text : String,
) -> Result[Array[ReplayExpectation], @hid.Diagnostic] {
  let result : Array[ReplayExpectation] = []
  let mut line = 0
  for row in text.split("\n") {
    line = line + 1
    if row.trim().is_empty() {
      continue
    }
    if result.length() >= 65536 {
      return Err({
        offset: line,
        code: "replay_limit",
        message: "More than 65536 expected frames",
      })
    }
    let json = @json.parse(row.to_owned()) catch {
      _ =>
        return Err(replay_error(line, "Expected JSONL line is not valid JSON"))
    }
    match expectation(json) {
      Ok(expected) => result.push(expected)
      Err(error) =>
        return Err(
          replay_error(line, "\{error.code} @\{error.offset}: \{error.message}"),
        )
    }
  }
  Ok(result)
}

///|
fn replay_value(value : @hid.ReportValue) -> String {
  match value {
    @hid.Integer(value) => value.to_string()
    @hid.Raw(bytes) => "hex \{@hid.format_hex(bytes)}"
  }
}

///|
/// Values/physical are partial assertions; active, when present, is an exact set.
fn replay_difference(
  layout : @hid.Layout,
  kind : @hid.ReportKind,
  wire : Bytes,
  expected : ReplayExpectation,
) -> String? {
  for index, (usage, expected) in expected.values {
    let actual = match @hid.get_usage_value(layout, kind, wire, usage) {
      Ok(value) => value
      Err(error) =>
        return Some("values[\{index}]: \{error.code}: \{error.message}")
    }
    if actual != expected {
      return Some(
        "values[\{index}] Usage \{usage.page}:\{usage.id}: expected \{replay_value(expected)}, got \{replay_value(actual)}",
      )
    }
  }
  for index, (usage, expected) in expected.physical {
    let actual = match @hid.get_physical_value(layout, kind, wire, usage) {
      Ok(value) => value
      Err(error) =>
        return Some("physical[\{index}]: \{error.code}: \{error.message}")
    }
    // The tolerance covers Double arithmetic only, not a logical-unit tolerance.
    let scale = if expected.abs() > 1.0 { expected.abs() } else { 1.0 }
    if (actual - expected).abs() > 0.000000001 * scale {
      return Some(
        "physical[\{index}] Usage \{usage.page}:\{usage.id}: expected \{expected}, got \{actual}",
      )
    }
  }
  if expected.active is Some(expected) {
    let actual = match @hid.active_usages(layout, kind, wire) {
      Ok(usages) => usages
      Err(error) => return Some("active: \{error.code}: \{error.message}")
    }
    let expected_set : Map[Int64, Bool] = Map([])
    let actual_set : Map[Int64, Bool] = Map([])
    for usage in expected {
      expected_set[replay_usage_key(usage)] = true
    }
    for usage in actual {
      actual_set[replay_usage_key(usage)] = true
    }
    for usage in expected {
      if !actual_set.contains(replay_usage_key(usage)) {
        return Some("active: missing Usage \{usage.page}:\{usage.id}")
      }
    }
    for usage in actual {
      if !expected_set.contains(replay_usage_key(usage)) {
        return Some("active: unexpected Usage \{usage.page}:\{usage.id}")
      }
    }
  }
  None
}

///|
fn replay_usage_key(usage : @hid.Usage) -> Int64 {
  (usage.page.to_int64() << 16) | usage.id.to_int64()
}

///|
fn replay(
  kind : @hid.ReportKind,
  descriptor_path : String,
  frames_path : String,
  expected_path : String?,
) -> Result[(String, Int), @hid.Diagnostic] {
  let descriptor = match read_hex(descriptor_path) {
    Ok(bytes) => bytes
    Err(error) => return Err(error)
  }
  let layout = match @hid.compile_descriptor(descriptor) {
    Ok(layout) => layout
    Err(error) => return Err(error)
  }
  let text = match replay_file(frames_path) {
    Ok(text) => text
    Err(error) => return Err(error)
  }
  let frames : Array[(Int, String)] = []
  let mut line = 0
  for row in text.split("\n") {
    line = line + 1
    let frame = match row.split_once("#") {
      Some((frame, _)) => frame
      None => row
    }
    if frame.trim().is_empty() {
      continue
    }
    if frames.length() >= 65536 {
      return Err({
        offset: line,
        code: "replay_limit",
        message: "More than 65536 frames",
      })
    }
    frames.push((line, frame.to_owned()))
  }
  let expected = match expected_path {
    None => None
    Some(path) => {
      let text = match replay_file(path) {
        Ok(text) => text
        Err(error) => return Err(error)
      }
      let expected = match replay_expectations(text) {
        Ok(expected) => expected
        Err(error) => return Err(error)
      }
      if expected.length() != frames.length() {
        return Err(
          replay_error(
            0,
            "Expected \{expected.length()} frames but input has \{frames.length()}",
          ),
        )
      }
      Some(expected)
    }
  }
  let mut failed = false
  let mut mismatched = false
  for index, (line, frame) in frames {
    let decoded = replay_frame(layout, kind, frame)
    let output : Json = match decoded {
      Ok((wire, report)) => {
        let output : Map[String, Json] = {
          "line": Json(line),
          "ok": Json(true),
          "report_id": Json(report.report_id),
          "wire_hex": Json(@hid.format_hex(wire)),
          "decoded": @hid.report_to_json(report),
        }
        if expected is Some(expected) {
          let difference = replay_difference(
            layout,
            kind,
            wire,
            expected[index],
          )
          output["matched"] = Json(difference is None)
          if difference is Some(message) {
            output["difference"] = Json(message)
            if !mismatched {
              write_stderr("replay_mismatch line \{line}: \{message}\n")
            }
            mismatched = true
          }
        }
        Json::object(output)
      }
      Err(error) => {
        if !failed {
          write_stderr(
            "replay line \{line}: \{error.code} @\{error.offset}: \{error.message}\n",
          )
        }
        failed = true
        {
          "line": Json(line),
          "ok": Json(false),
          "diagnostic": @hid.diagnostic_to_json(error),
        }
      }
    }
    println(output.stringify())
  }
  Ok(("", if failed { 1 } else if mismatched { 3 } else { 0 }))
}

///|
fn replay_frame(
  layout : @hid.Layout,
  kind : @hid.ReportKind,
  text : String,
) -> Result[(Bytes, @hid.DecodedReport), @hid.Diagnostic] {
  let wire = match @hid.parse_hex(text) {
    Ok(wire) => wire
    Err(error) => return Err(error)
  }
  match @hid.decode_report(layout, kind, wire) {
    Ok(report) => Ok((wire, report))
    Err(error) => Err(error)
  }
}
