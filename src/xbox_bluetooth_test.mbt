// Xbox Bluetooth host Input reports captured in Chrome on Windows, 2026-10-07.
// The reference is author-created raw bit layout; original descriptor semantics are unverified.

///|
test "Xbox live capture: A, axis endpoints and return to centre" {
  let layout = compile(
    "05 01 09 05 a1 01 15 00 27 ff ff 00 00 75 10 95 05 09 30 09 31 09 33 09 34 09 32 81 02 25 01 75 01 95 10 05 09 19 01 29 10 81 02 25 0f 75 04 95 01 05 01 09 39 81 02 95 05 81 01 c0",
  )
  assert_eq(@moonhid.report_length(layout, @moonhid.Input, 0), Ok(15))
  let report = match
    @moonhid.decode_report(
      layout,
      @moonhid.Input,
      b"\xd2\x85\xbf\x80\xc4\x80\x76\x7b\x00\x80\x01\x00\x00\x00\x00",
    ) {
    Ok(report) => report
    Err(_) => fail("captured report rejected")
  }
  assert_eq(report.values.map(v => v.value), [
    34258L, 32959L, 32964L, 31606L, 32768L, 1L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L,
    0L, 0L, 0L, 0L, 0L, 0L, 0L,
  ])
  assert_true(report.values.all(v => v.in_logical_range && !v.is_null))
  let report = match
    @moonhid.decode_report(
      layout,
      @moonhid.Input,
      b"\xd2\x85\xbf\x80\xc4\x80\x76\x7b\x00\x80\x00\x00\x00\x00\x00",
    ) {
    Ok(report) => report
    Err(_) => fail("captured report rejected")
  }
  assert_eq(report.values.map(v => v.value), [
    34258L, 32959L, 32964L, 31606L, 32768L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L,
    0L, 0L, 0L, 0L, 0L, 0L, 0L,
  ])
  assert_true(report.values.all(v => v.in_logical_range && !v.is_null))
  let report = match
    @moonhid.decode_report(
      layout,
      @moonhid.Input,
      b"\x00\x00\xc6\x84\xc4\x80\x76\x7b\x00\x80\x00\x00\x00\x00\x00",
    ) {
    Ok(report) => report
    Err(_) => fail("captured report rejected")
  }
  assert_eq(report.values.map(v => v.value), [
    0L, 33990L, 32964L, 31606L, 32768L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L,
    0L, 0L, 0L, 0L, 0L, 0L,
  ])
  assert_true(report.values.all(v => v.in_logical_range && !v.is_null))
  let report = match
    @moonhid.decode_report(
      layout,
      @moonhid.Input,
      b"\xff\xff\x3e\x83\xc4\x80\x76\x7b\x00\x80\x00\x00\x00\x00\x00",
    ) {
    Ok(report) => report
    Err(_) => fail("captured report rejected")
  }
  assert_eq(report.values.map(v => v.value), [
    65535L, 33598L, 32964L, 31606L, 32768L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L,
    0L, 0L, 0L, 0L, 0L, 0L, 0L,
  ])
  assert_true(report.values.all(v => v.in_logical_range && !v.is_null))
  let report = match
    @moonhid.decode_report(
      layout,
      @moonhid.Input,
      b"\x00\x80\x00\x80\x00\x80\x00\x80\x00\x80\x00\x00\x00\x00\x00",
    ) {
    Ok(report) => report
    Err(_) => fail("captured report rejected")
  }
  assert_eq(report.values.map(v => v.value), [
    32768L, 32768L, 32768L, 32768L, 32768L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L,
    0L, 0L, 0L, 0L, 0L, 0L, 0L,
  ])
  assert_true(report.values.all(v => v.in_logical_range && !v.is_null))
}
