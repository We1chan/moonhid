///|
fn lint(text : String) -> Array[@moonhid.Lint] raise {
  let bytes = match @moonhid.parse_hex(text) {
    Ok(bytes) => bytes
    Err(_) => fail("invalid lint test hex")
  }
  match @moonhid.lint_descriptor(bytes) {
    Ok(lints) => lints
    Err(error) => fail("lint compile failed: \{error.code} @\{error.offset}")
  }
}

///|
fn lint_rule(
  text : String,
  code : String,
) -> Array[(@moonhid.LintLevel, Int, Int?)] raise {
  lint(text)
  .filter(l => l.code == code)
  .map(l => (l.level, l.offset, l.field_index))
}

///|
fn lint_application(body : String) -> String {
  "05 01 09 05 a1 01 \{body} c0"
}

///|
test "lint returns the compiler Diagnostic unchanged" {
  for
    bytes in [
      b"", b"\x75", b"\xc0", b"\xb4", b"\xfe\x00\x42", b"\x75\x08\x95\x01\x15\x7f\x25\x01\x81\x02",
    ] {
    let error = match @moonhid.compile_descriptor(bytes) {
      Err(error) => error
      Ok(_) => fail("expected compiler failure")
    }
    assert_eq(@moonhid.lint_descriptor(bytes), Err(error))
  }
}

///|
test "logical_max_sign is advisory and points to the raw Maximum item" {
  let narrow = lint_application("15 00 25 ff 75 08 95 01 09 30 81 02")
  assert_eq(lint_rule(narrow, "logical_max_sign"), [(@moonhid.Info, 8, Some(0))])
  assert_eq(compile(narrow).fields[0].logical_max, 255L)
  for
    body in [
      "15 00 26 ff 00 75 08 95 01 09 30 81 02", "15 81 25 7f 75 08 95 01 09 30 81 02",
      "15 00 24 75 08 95 01 09 30 81 02", "15 00 25 ff 75 08 95 01 81 03",
    ] {
    assert_eq(lint_rule(lint_application(body), "logical_max_sign"), [])
  }
  let full = lint_application("15 00 27 ff ff ff ff 75 20 95 01 09 30 81 02")
  let messages = lint(full).filter(l => l.code == "logical_max_sign")
  assert_eq(messages.length(), 1)
  assert_true(messages[0].message.contains("4294967295"))
  assert_true(messages[0].message.contains("No wider short item"))
}

///|
test "physical_max_sign needs both physical endpoints and skips signed ranges" {
  let base = "15 00 25 01 75 08 95 01"
  assert_eq(
    lint_rule(
      lint_application("\{base} 35 00 45 ff 09 30 81 02"),
      "physical_max_sign",
    ),
    [(@moonhid.Info, 16, Some(0))],
  )
  for physical in ["35 00 46 ff 00", "35 81 45 7f", "45 ff", "35 00 44"] {
    assert_eq(
      lint_rule(
        lint_application("\{base} \{physical} 09 30 81 02"),
        "physical_max_sign",
      ),
      [],
    )
  }
}

///|
test "maximum encoding pass restores Push Pop and reports only active encodings" {
  let text = lint_application(
    "15 00 25 ff 35 00 45 ff 75 08 95 01 a4 26 ff 00 46 ff 00 09 30 81 02 b4 09 31 81 02 09 32 81 02",
  )
  assert_eq(lint_rule(text, "logical_max_sign"), [(@moonhid.Info, 8, Some(1))])
  assert_eq(lint_rule(text, "physical_max_sign"), [(@moonhid.Info, 12, Some(1))])
  let unused = lint_application(
    "15 00 25 ff 35 00 45 ff 26 ff 00 46 ff 00 75 08 95 01 09 30 81 02",
  )
  assert_eq(lint_rule(unused, "logical_max_sign"), [])
  assert_eq(lint_rule(unused, "physical_max_sign"), [])
  // The Minimum can change after a Maximum, including inside a saved state.
  let changed = lint_application(
    "15 81 25 ff 75 08 95 01 a4 15 00 09 30 81 02 b4 09 31 81 02",
  )
  assert_eq(lint_rule(changed, "logical_max_sign"), [
    (@moonhid.Info, 8, Some(0)),
  ])
  assert_eq(compile(changed).fields.map(f => f.logical_max), [255L, -1L])
}

///|
test "null_without_room checks unsigned and signed endpoints including uint32" {
  for
    body in [
      "15 00 25 0f 75 04 95 01 09 39 81 42", "15 80 25 7f 75 08 95 01 09 30 81 42",
    ] {
    assert_eq(lint_rule(lint_application(body), "null_without_room"), [
      (@moonhid.Warning, 16, Some(0)),
    ])
  }
  assert_eq(
    lint_rule(
      lint_application("15 00 27 ff ff ff ff 75 20 95 01 09 30 81 42"),
      "null_without_room",
    ),
    [(@moonhid.Warning, 19, Some(0))],
  )
  for
    body in [
      "15 00 25 07 75 04 95 01 09 39 81 42", "15 81 25 7f 75 08 95 01 09 30 81 42",
      "15 00 25 0f 75 04 95 01 09 39 81 02", "15 00 25 0f 75 04 95 01 81 43", "15 00 27 ff ff ff ff 75 28 95 01 09 30 81 42",
    ] {
    assert_eq(lint_rule(lint_application(body), "null_without_room"), [])
  }
}

///|
test "Variable usage_count distinguishes extras repeats and a shared single Usage" {
  let prefix = "05 09 19 01 29 03 15 00 25 01 75 02"
  assert_eq(
    lint_rule(lint_application("\{prefix} 95 02 81 02"), "usage_count"),
    [(@moonhid.Warning, 20, Some(0))],
  )
  assert_eq(
    lint_rule(lint_application("\{prefix} 95 04 81 02"), "usage_count"),
    [(@moonhid.Info, 20, Some(0))],
  )
  assert_eq(
    lint_rule(lint_application("\{prefix} 95 03 81 02"), "usage_count"),
    [],
  )
  for
    body in [
      "05 09 09 01 15 00 25 01 75 02 95 04 81 02", "05 09 19 01 29 03 15 00 25 01 75 02 95 02 81 03",
      "05 09 15 00 25 01 75 02 95 04 81 02",
    ] {
    assert_eq(lint_rule(lint_application(body), "usage_count"), [])
  }
}

///|
test "Array usage_count compares logical selectors rather than Report Count" {
  let prefix = "05 09 19 00 29 02 15 00"
  assert_eq(
    lint_rule(
      lint_application("\{prefix} 25 03 75 08 95 02 81 00"),
      "usage_count",
    ),
    [(@moonhid.Warning, 20, Some(0))],
  )
  assert_eq(
    lint_rule(
      lint_application("\{prefix} 25 01 75 08 95 02 81 00"),
      "usage_count",
    ),
    [(@moonhid.Warning, 20, Some(0))],
  )
  for
    body in [
      "\{prefix} 25 02 75 08 95 02 81 00",
      "05 09 19 01 29 03 15 01 25 03 75 08 95 02 81 00",
      "\{prefix} 25 03 75 08 95 02 81 01",
    ] {
    assert_eq(lint_rule(lint_application(body), "usage_count"), [])
  }
  let full = lint_application(
    "05 09 19 00 29 01 15 00 27 ff ff ff ff 75 20 95 01 81 00",
  )
  assert_true(
    lint(full).filter(l => l.code == "usage_count")[0].message.contains(
      "4294967296",
    ),
  )
}

///|
test "usage_count keeps compact ranges and primary Delimiter semantics" {
  assert_eq(
    lint_rule(
      lint_application(
        "05 09 19 00 2a ff ff 15 00 27 ff ff 00 00 75 10 95 01 81 00",
      ),
      "usage_count",
    ),
    [],
  )
  assert_eq(
    lint_rule(
      lint_application(
        "05 09 09 01 a9 01 09 02 a9 00 a9 01 19 01 29 10 a9 00 15 00 25 01 75 04 95 02 81 02",
      ),
      "usage_count",
    ),
    [],
  )
  // Opaque Variable fields still have a meaningful declared Usage count.
  assert_true(
    lint(lint_application("09 30 09 31 15 00 25 01 75 28 95 01 81 02")).any(l => {
      l.code == "usage_count" && l.level == @moonhid.Warning
    }),
  )
}

///|
test "missing_usage respects Main local reset and excludes Constant padding" {
  let body = "15 00 25 01 75 08 95 01"
  assert_eq(lint_rule(lint_application("\{body} 81 02"), "missing_usage"), [
    (@moonhid.Warning, 14, Some(0)),
  ])
  assert_eq(
    lint_rule(lint_application("\{body} 09 30 81 02"), "missing_usage"),
    [],
  )
  assert_eq(lint_rule(lint_application("\{body} 81 03"), "missing_usage"), [])
  assert_eq(
    lint_rule(lint_application("\{body} 09 30 81 02 81 02"), "missing_usage"),
    [(@moonhid.Warning, 18, Some(1))],
  )
}

///|
test "unaligned_report uses final payload size and independent kind ID cursors" {
  let text = lint_application(
    "85 01 15 00 25 01 75 03 95 01 09 30 81 02 75 08 09 31 91 02 85 02 75 05 09 32 b1 02",
  )
  assert_eq(lint_rule(text, "unaligned_report"), [
    (@moonhid.Info, 18, Some(0)),
    (@moonhid.Info, 32, Some(2)),
  ])
  let layout = compile(text)
  assert_eq(@moonhid.report_length(layout, @moonhid.Input, 1), Ok(2))
  assert_eq(@moonhid.report_length(layout, @moonhid.Output, 1), Ok(2))
  assert_eq(@moonhid.report_length(layout, @moonhid.Feature, 2), Ok(2))
  assert_eq(
    lint_rule(
      lint_application("15 00 25 01 75 03 95 01 09 30 81 02 75 05 81 01"),
      "unaligned_report",
    ),
    [],
  )
  assert_eq(
    lint_rule(
      lint_application("15 00 25 01 75 03 95 01 81 01"),
      "unaligned_report",
    ),
    [(@moonhid.Info, 14, Some(0))],
  )
}

///|
test "field_outside_application searches all ancestors and ignores Constant fields" {
  let body = "15 00 25 01 75 08 95 01 09 30 81 02"
  assert_eq(lint_rule("05 01 \{body}", "field_outside_application"), [
    (@moonhid.Warning, 12, Some(0)),
  ])
  assert_eq(lint_rule(lint_application(body), "field_outside_application"), [])
  assert_eq(
    lint_rule(
      lint_application("09 01 a1 00 \{body} c0"),
      "field_outside_application",
    ),
    [],
  )
  assert_eq(
    lint_rule("05 01 09 01 a1 00 \{body} c0", "field_outside_application"),
    [(@moonhid.Warning, 16, Some(0))],
  )
  assert_eq(lint_rule("75 08 95 01 81 03", "field_outside_application"), [])
}

///|
test "collection_without_usage points to Collection and local Usage does not carry over" {
  let body = "15 00 25 01 75 08 95 01 09 30 81 02"
  assert_eq(lint_rule("05 01 a1 01 \{body} c0", "collection_without_usage"), [
    (@moonhid.Warning, 2, None),
  ])
  assert_eq(lint_rule(lint_application(body), "collection_without_usage"), [])
  assert_eq(
    lint_rule(lint_application("a1 00 \{body} c0"), "collection_without_usage"),
    [(@moonhid.Warning, 6, None)],
  )
}

///|
test "multiple applications without IDs warn only when a report actually spans them" {
  let globals = "05 01 15 00 25 01 75 08 95 01"
  let first = "09 05 a1 01 09 30 81 02 c0"
  assert_eq(
    lint_rule(
      "\{globals} \{first} 09 02 a1 01 09 31 81 02 c0",
      "multiple_applications_without_report_id",
    ),
    [(@moonhid.Warning, 21, None)],
  )
  assert_eq(
    lint_rule(
      "\{globals} \{first} 09 02 a1 01 09 31 91 02 c0",
      "multiple_applications_without_report_id",
    ),
    [(@moonhid.Info, 21, None)],
  )
  assert_eq(
    lint_rule("\{globals} \{first}", "multiple_applications_without_report_id"),
    [],
  )
  assert_eq(
    lint_rule(
      "\{globals} 09 05 a1 01 85 01 09 30 81 02 c0 09 02 a1 01 85 02 09 31 81 02 c0",
      "multiple_applications_without_report_id",
    ),
    [],
  )
}

///|
test "report_id_shared_across_applications uses kind ID and includes padding" {
  let globals = "05 01 15 00 25 01 75 08 95 01"
  let first = "09 05 a1 01 85 01 09 30 81 02 c0"
  for flags in ["02", "03"] {
    assert_eq(
      lint_rule(
        "\{globals} \{first} 09 02 a1 01 85 01 09 31 81 \{flags} 09 32 81 02 c0",
        "report_id_shared_across_applications",
      ),
      [(@moonhid.Warning, 29, Some(1))],
    )
  }
  for
    second in [
      "09 02 a1 01 85 02 09 31 81 02 c0", "09 02 a1 01 85 01 09 31 91 02 c0", "09 02 a1 01 85 01 09 31 b1 02 c0",
    ] {
    assert_eq(
      lint_rule(
        "\{globals} \{first} \{second}",
        "report_id_shared_across_applications",
      ),
      [],
    )
  }
  assert_eq(
    lint_rule(
      "\{globals} 09 05 a1 01 85 01 09 30 81 02 09 02 a1 01 09 31 81 02 c0 c0",
      "report_id_shared_across_applications",
    ),
    [],
  )
}

///|
test "lint preserves compiler results and returns ordered item offsets on seeded mutations" {
  let rng = FuzzRng::{ state: 0x65b14e2dU, }
  let corpus = [
    real_device_a(),
    real_device_b(),
    real_device_c(),
    real_device_d(),
    real_device_e(),
    real_device_f(),
    real_device_g(),
  ]
  for i = 0; i < 280; i = i + 1 {
    let original = match @moonhid.parse_hex(corpus[i % corpus.length()]) {
      Ok(bytes) => bytes
      Err(_) => fail("invalid corpus")
    }
    let mutation = rng.below(original.length())
    let replacement = rng.below(256).to_byte()
    let bytes = Bytes::makei(original.length(), j => {
      if j == mutation {
        replacement
      } else {
        original[j]
      }
    })
    let compiled = @moonhid.compile_descriptor(bytes)
    match (compiled, @moonhid.lint_descriptor(bytes)) {
      (Err(a), Err(b)) => assert_eq(a, b)
      (Ok(layout), Ok(lints)) => {
        let items = match @moonhid.parse_items(bytes) {
          Ok(items) => items
          Err(_) => fail("compiled bytes did not tokenize")
        }
        for j = 0; j < lints.length(); j = j + 1 {
          let entry = lints[j]
          assert_true(items.any(item => item.offset == entry.offset))
          assert_false(entry.message.is_empty())
          if entry.field_index is Some(index) {
            assert_true(index >= 0 && index < layout.fields.length())
          }
          if j > 0 {
            let before = lints[j - 1]
            assert_true(
              before.offset < entry.offset ||
              (
                before.offset == entry.offset &&
                before.code.lexical_compare(entry.code) < 0
              ),
            )
          }
        }
        assert_eq(@moonhid.lint_descriptor(bytes), Ok(lints))
      }
      _ => fail("lint changed compile success/failure")
    }
    assert_eq(@moonhid.compile_descriptor(bytes), compiled)
  }
}
