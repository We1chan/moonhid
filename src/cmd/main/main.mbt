///|
fn parse(text : String) -> Bytes {
  match @hid.parse_hex(text) {
    Ok(bytes) => bytes
    Err(error) => abort("Fixture error: \{error.code}")
  }
}

///|
fn main {
  for fixture in @examples.all() {
    let layout = match @hid.compile_descriptor(parse(fixture.descriptor_hex)) {
      Ok(layout) => layout
      Err(error) => abort("\{fixture.name}: \{error.code}")
    }
    let report = match
      @hid.decode_report(layout, @hid.Input, parse(fixture.input_hex)) {
      Ok(report) => report
      Err(error) => abort("\{fixture.name}: \{error.code}")
    }
    println(
      "\{fixture.name}: report_id=\{report.report_id}, fields=\{layout.fields.length()}",
    )
    for value in report.values {
      let usage = match value.usage {
        Some(usage) => "\{usage.page}:\{usage.id}"
        None => "unassigned"
      }
      println("  bit \{value.bit_offset}: usage=\{usage}, value=\{value.value}")
    }
  }
}
