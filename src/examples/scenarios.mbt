///|
// These demonstrations use fixed synthetic data. Abort on an unexpected error
// so a broken example cannot print a plausible successful transcript.
fn[T] scenario_ok(result : Result[T, @hid.Diagnostic]) -> T {
  match result {
    Ok(value) => value
    Err(error) => abort("Scenario failed: \{error.code}: \{error.message}")
  }
}

///|
fn[T] scenario_error(result : Result[T, @hid.Diagnostic]) -> String {
  match result {
    Err(error) => error.code
    Ok(_) => abort("Scenario expected a diagnostic")
  }
}

///|
fn scenario_hex(text : String) -> Bytes {
  scenario_ok(@hid.parse_hex(text))
}

///|
fn scenario_integer(value : @hid.ReportValue) -> Int64 {
  match value {
    @hid.Integer(value) => value
    @hid.Raw(_) => abort("Scenario expected an integer")
  }
}

///|
fn scenario_raw(value : @hid.ReportValue) -> String {
  match value {
    @hid.Raw(bytes) => @hid.format_hex(bytes)
    @hid.Integer(_) => abort("Scenario expected raw bytes")
  }
}

///|
/// Four reproducible application scenarios, without files, devices or network.
/// Each line describes an operation and its actual result from the core API.
pub fn scenario_lines() -> Array[String] {
  let lines : Array[String] = []
  let descriptor = scenario_ok(keyboard_descriptor())
  let keyboard = scenario_ok(@hid.compile_descriptor(descriptor))
  lines.push("1. 键盘")
  lines.push("生成键盘与 LED 描述符 → \{@hid.format_hex(descriptor)}")
  let idle = scenario_ok(@hid.new_report(keyboard, @hid.Input, 0))
  let keys : Array[@hid.Usage] = [{ page: 7, id: 0xe1, }, { page: 7, id: 4, }]
  let pressed = scenario_ok(@hid.set_usages(keyboard, @hid.Input, idle, keys))
  lines.push("按下 Left Shift + A → \{@hid.format_hex(pressed)}")
  let released = scenario_ok(
    @hid.clear_usages(keyboard, @hid.Input, pressed, keys),
  )
  lines.push("释放 Left Shift + A → \{@hid.format_hex(released)}")
  let leds = scenario_ok(@hid.decode_report(keyboard, @hid.Output, b"\x03"))
  lines.push(
    "解码 LED Output 03 → Num Lock = \{leds.values[0].value}, Caps Lock = \{leds.values[1].value}",
  )

  let mouse = scenario_ok(
    @hid.compile_descriptor(scenario_ok(mouse_descriptor())),
  )
  let mouse_wire = scenario_hex("05 ff 02 fe")
  let decoded = scenario_ok(@hid.decode_report(mouse, @hid.Input, mouse_wire))
  lines.push("2. 鼠标和手柄")
  lines.push(
    "解码鼠标 05 ff 02 fe → X = \{decoded.values[3].value}, Y = \{decoded.values[4].value}, Wheel = \{decoded.values[5].value}",
  )
  let reference = scenario_ok(
      @hid.find_fields(mouse, @hid.Input, 0, { page: 9, id: 2, }),
    )[0]
  let changed = scenario_ok(
    @hid.write_field(
      mouse,
      @hid.Input,
      mouse_wire,
      reference.field_index,
      reference.element_index,
      @hid.Integer(1L),
    ),
  )
  lines.push(
    "Button 2 置 1，保留其他位 → \{@hid.format_hex(mouse_wire)} → \{@hid.format_hex(changed)}",
  )
  let hat = scenario_ok(
    @hid.compile_descriptor(
      scenario_ok(
        @hid.DescriptorBuilder::new()
        .usage_page(1)
        .usage(5)
        .collection(1)
        .report_id(9)
        .usage(0x39)
        .logical_range(0L, 7L)
        .physical_range(0L, 315L)
        .unit(0x14)
        .report_size(4)
        .report_count(1)
        .input(0x42)
        .input(1)
        .end_collection()
        .build(),
      ),
    ),
  )
  let hat_idle = scenario_ok(@hid.new_report(hat, @hid.Input, 9))
  let usage : @hid.Usage = { page: 1, id: 0x39, }
  let east = scenario_ok(
    @hid.set_physical_value(hat, @hid.Input, hat_idle, usage, 90.0),
  )
  let logical = scenario_integer(
    scenario_ok(@hid.get_usage_value(hat, @hid.Input, east, usage)),
  )
  let physical = scenario_ok(
    @hid.get_physical_value(hat, @hid.Input, east, usage),
  )
  let hat_wire = scenario_ok(
    @hid.encode_report(hat, @hid.Input, 9, [@hid.Integer(logical)]),
  )
  lines.push("初始化 Hat Null（ID 9）→ \{@hid.format_hex(hat_idle)}")
  lines.push(
    "Hat 设为 90 度并读回 → 逻辑值 \{logical}, 角度 \{physical} 度, 完整报告 \{@hid.format_hex(hat_wire)}",
  )

  lines.push("3. 媒体键和厂商配置")
  let consumer = scenario_ok(
    @hid.compile_descriptor(scenario_ok(consumer_descriptor())),
  )
  let media = scenario_ok(
    @hid.encode_report(consumer, @hid.Input, 0, [@hid.Integer(0xcdL)]),
  )
  lines.push(
    "编码 Play/Pause（Usage 0x0c:0xcd）→ \{@hid.format_hex(media)}",
  )
  let feature = scenario_ok(
    @hid.compile_descriptor(
      scenario_hex(
        "06 00 ff 09 01 a1 01 85 07 75 03 95 01 b1 01 75 21 09 02 b1 02 c0",
      ),
    ),
  )
  let initial = scenario_ok(
    @hid.encode_report(feature, @hid.Feature, 7, [
      @hid.Raw(b"\xff\xff\xff\xff\x01"),
    ]),
  )
  let raw = scenario_raw(
    scenario_ok(@hid.read_field(feature, @hid.Feature, initial, 1, 0)),
  )
  lines.push(
    "33 位 Raw Feature（宽松扩展，非 HID 1.11 标准证据）→ \{@hid.format_hex(initial)}",
  )
  lines.push("读取厂商配置 Raw → \{raw}")
  let configured = scenario_ok(
    @hid.write_field(
      feature,
      @hid.Feature,
      initial,
      1,
      0,
      @hid.Raw(b"\x12\x34\x56\x78\x01"),
    ),
  )
  let saved = scenario_raw(
    scenario_ok(@hid.read_field(feature, @hid.Feature, configured, 1, 0)),
  )
  lines.push(
    "写入并读回厂商配置 → \{@hid.format_hex(configured)}, Raw = \{saved}",
  )

  lines.push("4. 固件回归")
  let suspect = scenario_hex(
    "05 01 09 05 a1 01 15 00 25 0f 75 04 95 01 09 39 81 42 81 01 c0",
  )
  let lints = scenario_ok(@hid.lint_descriptor(suspect))
  lines.push(
    "检查没有空闲值的 Hat → \{lints.map(lint => lint.code).join(", ")}",
  )
  let length_error = scenario_error(
    @hid.decode_report(mouse, @hid.Input, b"\x05\xff\x02"),
  )
  lines.push("报告少一个字节 → \{length_error}")
  let range_error = scenario_error(
    @hid.write_field(mouse, @hid.Input, mouse_wire, 2, 0, @hid.Integer(-128L)),
  )
  lines.push("鼠标 X 写入 -128（Logical -127..127）→ \{range_error}")
  let encoded = scenario_ok(
    @hid.encode_report(
      mouse,
      @hid.Input,
      0,
      decoded.values.map(value => @hid.Integer(value.value)),
    ),
  )
  lines.push(
    "鼠标解码后重新编码 → \{@hid.format_hex(encoded)}, 字节相同 = \{encoded == mouse_wire}",
  )
  lines.push("文件与固定预期回归 → node scripts/firmware-ci.mjs")
  lines
}
