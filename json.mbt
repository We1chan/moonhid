///|
/// Canonical lower-case, space-separated byte pairs.
pub fn format_hex(bytes : Bytes) -> String {
  bytes
  .to_array()
  .map(byte => byte.to_int().to_string(radix=16).pad_start(2, '0'))
  .join(" ")
}

///|
pub fn report_kind_name(kind : ReportKind) -> String {
  match kind {
    Input => "input"
    Output => "output"
    Feature => "feature"
  }
}

///|
fn optional_int(value : Int?) -> Json {
  match value {
    Some(value) => value.to_json()
    None => Json::null()
  }
}

///|
fn optional_int64(value : Int64?) -> Json {
  match value {
    Some(value) => number64(value)
    None => Json::null()
  }
}

///|
// Int64's generic ToJson uses strings. HID integers fit exactly in a JSON number.
fn number64(value : Int64) -> Json {
  Json::number(value.to_double())
}

///|
fn usage_json(usage : Usage?) -> Json {
  match usage {
    Some(usage) => { "page": usage.page.to_json(), "id": usage.id.to_json() }
    None => Json::null()
  }
}

///|
fn unit_json(raw : Int64?) -> Json {
  match raw {
    Some(raw) =>
      match decode_unit(raw) {
        Ok(unit) =>
          {
            "raw": number64(unit.raw),
            "system": unit.system.to_json(),
            "length": unit.length.to_json(),
            "mass": unit.mass.to_json(),
            "time": unit.time.to_json(),
            "temperature": unit.temperature.to_json(),
            "current": unit.current.to_json(),
            "luminous_intensity": unit.luminous_intensity.to_json(),
            "reserved": unit.reserved.to_json(),
          }
        Err(_) => Json::null()
      }
    None => Json::null()
  }
}

///|
/// A JSON component. Wrap in the schema_version=2 descriptor export for storage.
pub fn layout_to_json(layout : Layout) -> Json {
  let reports : Array[Json] = []
  let seen : Map[Int, Bool] = Map([])
  for field in layout.fields {
    let kind_index = match field.kind {
      Input => 0
      Output => 1
      Feature => 2
    }
    let key = kind_index * 256 + field.report_id
    if seen.contains(key) {
      continue
    }
    seen[key] = true
    let mut bits = 0
    for candidate in layout.fields {
      if candidate.kind == field.kind && candidate.report_id == field.report_id {
        bits = bits + candidate.bit_size * candidate.count
      }
    }
    reports.push({
      "kind": Json::string(report_kind_name(field.kind)),
      "report_id": field.report_id.to_json(),
      "payload_bits": bits.to_json(),
      "wire_bytes": ((bits + 7) / 8 +
      (if layout.has_report_ids { 1 } else { 0 })).to_json(),
    })
  }
  {
    "has_report_ids": Json::boolean(layout.has_report_ids),
    "reports": Json::array(reports),
    "collections": Json::array(
      layout.collections.map(c => {
        "descriptor_offset": c.descriptor_offset.to_json(),
        "end_offset": c.end_offset.to_json(),
        "collection_type": c.collection_type.to_json(),
        "usage": usage_json(c.usage),
        "parent_index": optional_int(c.parent_index),
      }),
    ),
    "fields": Json::array(
      layout.fields.map(f => {
        let (physical_min, physical_max) = effective_physical_range(f)
        {
          "descriptor_offset": f.descriptor_offset.to_json(),
          "kind": Json::string(report_kind_name(f.kind)),
          "report_id": f.report_id.to_json(),
          "bit_offset": f.bit_offset.to_json(),
          "bit_size": f.bit_size.to_json(),
          "count": f.count.to_json(),
          "flags": f.flags.to_json(),
          "logical_min": number64(f.logical_min),
          "logical_max": number64(f.logical_max),
          "physical_min": optional_int64(f.physical_min),
          "physical_max": optional_int64(f.physical_max),
          "effective_physical_min": number64(physical_min),
          "effective_physical_max": number64(physical_max),
          "unit": unit_json(f.unit),
          "unit_exponent": optional_int(f.unit_exponent),
          "collection_index": optional_int(f.collection_index),
          "usages": Json::array(f.usages.map(u => usage_json(Some(u)))),
        }
      }),
    ),
  }
}

///|
pub fn report_to_json(report : DecodedReport) -> Json {
  {
    "kind": Json::string(report_kind_name(report.kind)),
    "report_id": report.report_id.to_json(),
    "opaque_values": Json::array(
      report.opaque_values.map(v => {
        "field_index": v.field_index.to_json(),
        "element_index": v.element_index.to_json(),
        "bit_offset": v.bit_offset.to_json(),
        "bit_size": v.bit_size.to_json(),
        "hex": Json::string(format_hex(v.bytes)),
      }),
    ),
    "values": Json::array(
      report.values.map(v => {
        "field_index": v.field_index.to_json(),
        "element_index": v.element_index.to_json(),
        "bit_offset": v.bit_offset.to_json(),
        "value": number64(v.value),
        "usage": usage_json(v.usage),
        "is_array": Json::boolean(v.is_array),
        "in_logical_range": Json::boolean(v.in_logical_range),
        "is_null": Json::boolean(v.is_null),
      }),
    ),
  }
}

///|
pub fn diagnostic_to_json(error : Diagnostic) -> Json {
  {
    "offset": error.offset.to_json(),
    "code": Json::string(error.code),
    "message": Json::string(error.message),
  }
}

///|
/// Schema version 2. Array order follows the descriptor; absent metadata is null.
/// All numbers are exact within JavaScript's integer range for compiled layouts.
pub fn descriptor_to_json(bytes : Bytes) -> Result[Json, Diagnostic] {
  let layout = match compile_descriptor(bytes) {
    Ok(layout) => layout
    Err(error) => return Err(error)
  }
  let items = match parse_items(bytes) {
    Ok(items) => items
    Err(error) => return Err(error)
  }
  Ok({
    "schema_version": 2,
    "descriptor_hex": Json::string(format_hex(bytes)),
    "byte_length": bytes.length().to_json(),
    "items": Json::array(
      items.map(item => {
        "offset": item.offset.to_json(),
        "type_code": item.type_code.to_json(),
        "tag": item.tag.to_json(),
        "data_hex": Json::string(format_hex(item.data)),
        "is_long": Json::boolean(item.is_long),
      }),
    ),
    "layout": layout_to_json(layout),
  })
}
