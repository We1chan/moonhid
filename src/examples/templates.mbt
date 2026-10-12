///|
/// Generates the same descriptor as the independently stored mouse fixture.
pub fn mouse_descriptor() -> Result[Bytes, @hid.Diagnostic] {
  @hid.DescriptorBuilder::new()
  .usage_page(1)
  .usage(2)
  .collection(1)
  .usage_page(9)
  .usage_range(1, 3)
  .logical_range(0L, 1L)
  .report_size(1)
  .report_count(3)
  .input(2)
  .report_size(5)
  .report_count(1)
  .input(1)
  .usage_page(1)
  .usage(0x30)
  .usage(0x31)
  .usage(0x38)
  .logical_range(-127L, 127L)
  .report_size(8)
  .report_count(3)
  .input(6)
  .end_collection()
  .build()
}

///|
/// Boot-style keyboard Input and LED Output descriptor, without changing protocol.
pub fn keyboard_descriptor() -> Result[Bytes, @hid.Diagnostic] {
  @hid.DescriptorBuilder::new()
  .usage_page(1)
  .usage(6)
  .collection(1)
  .usage_page(7)
  .usage_range(0xe0, 0xe7)
  .logical_range(0L, 1L)
  .report_size(1)
  .report_count(8)
  .input(2)
  .report_size(8)
  .report_count(1)
  .input(1)
  .usage_range(0, 0x65)
  .logical_range(0L, 0x65L)
  .report_size(8)
  .report_count(6)
  .input(0)
  .usage_page(8)
  .usage_range(1, 5)
  .logical_range(0L, 1L)
  .report_size(1)
  .report_count(5)
  .output(2)
  .report_size(3)
  .report_count(1)
  .output(1)
  .end_collection()
  .build()
}

///|
/// Twelve buttons and signed 16-bit axes, numbered Input report 7.
pub fn gamepad_descriptor() -> Result[Bytes, @hid.Diagnostic] {
  @hid.DescriptorBuilder::new()
  .usage_page(1)
  .usage(5)
  .collection(1)
  .report_id(7)
  .usage_page(9)
  .usage_range(1, 12)
  .logical_range(0L, 1L)
  .report_size(1)
  .report_count(12)
  .input(2)
  .report_size(4)
  .report_count(1)
  .input(1)
  .usage_page(1)
  .usage(0x30)
  .usage(0x31)
  .logical_range(-32768L, 32767L)
  .report_size(16)
  .report_count(2)
  .input(2)
  .end_collection()
  .build()
}

///|
/// Consumer Control (media keys): one 16-bit Array over Usages 0..0x3FF.
/// Same bytes as TinyUSB TUD_HID_REPORT_DESC_CONSUMER without a Report ID.
pub fn consumer_descriptor() -> Result[Bytes, @hid.Diagnostic] {
  @hid.DescriptorBuilder::new()
  .usage_page(0x0c)
  .usage(1)
  .collection(1)
  .logical_range(0L, 0x3ffL)
  .usage_range(0, 0x3ff)
  .report_count(1)
  .report_size(16)
  .input(0)
  .end_collection()
  .build()
}

///|
/// Vendor-defined raw Input and Output of report_bytes bytes each (1..8192).
/// Same bytes as TinyUSB TUD_HID_REPORT_DESC_GENERIC_INOUT(report_bytes).
pub fn vendor_descriptor(
  report_bytes? : Int = 64,
) -> Result[Bytes, @hid.Diagnostic] {
  if report_bytes < 1 || report_bytes > 8192 {
    return Err({
      offset: 0,
      code: "report_count",
      message: "Vendor reports must be 1..8192 bytes",
    })
  }
  @hid.DescriptorBuilder::new()
  .usage_page(0xff00)
  .usage(1)
  .collection(1)
  .usage(2)
  .logical_range(0L, 255L)
  .report_size(8)
  .report_count(report_bytes)
  .input(2)
  .usage(3)
  .logical_range(0L, 255L)
  .report_size(8)
  .report_count(report_bytes)
  .output(2)
  .end_collection()
  .build()
}
