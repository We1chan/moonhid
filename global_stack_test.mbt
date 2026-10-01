///|
test "Push Pop restores every global without restoring local usages" {
  let layout = compile(
    "05 09 15 00 25 01 75 01 95 01 85 01 a4 05 01 15 81 25 7f 75 08 95 02 85 02 09 30 09 31 81 06 b4 09 01 81 02",
  )
  assert_eq(layout.fields[0].report_id, 2)
  let button = layout.fields[1]
  assert_eq((button.report_id, button.bit_size, button.count), (1, 1, 1))
  assert_eq(button.logical_min, 0L)
  assert_eq(button.logical_max, 1L)
  assert_eq(button.usages, [{ page: 9, id: 1, }])
}

///|
test "malformed global stack is rejected at its source" {
  assert_true(
    @moonhid.compile_descriptor(b"\xb4")
    is Err({ offset: 0, code: "global_stack", .. }),
  )
  assert_true(
    @moonhid.compile_descriptor(b"\xa5\x01")
    is Err({ offset: 0, code: "global_stack", .. }),
  )
  assert_true(
    @moonhid.compile_descriptor(b"\xa4\x75\x08\x95\x01\x81\x02")
    is Err({ code: "global_stack", .. }),
  )
}
