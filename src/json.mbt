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
fn optional_int(value : Int32?) -> Json {
  match value {
    Some(value) => Json(value)
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
    Some(usage) => { "page": Json(usage.page), "id": Json(usage.id) }
    None => Json::null()
  }
}

///|
fn usage_span_json(span : UsageSpan) -> Json {
  { "page": Json(span.page), "min": Json(span.min), "max": Json(span.max) }
}

///|
fn index_span_json(span : IndexSpan) -> Json {
  { "min": number64(span.min), "max": number64(span.max) }
}

///|
fn unit_json(raw : Int64?) -> Json {
  match raw {
    Some(raw) =>
      match decode_unit(raw) {
        Ok(unit) =>
          {
            "raw": number64(unit.raw),
            "system": Json(unit.system),
            "length": Json(unit.length),
            "mass": Json(unit.mass),
            "time": Json(unit.time),
            "temperature": Json(unit.temperature),
            "current": Json(unit.current),
            "luminous_intensity": Json(unit.luminous_intensity),
            "reserved": Json(unit.reserved),
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
  let seen : Map[Int32, Bool] = Map([])
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
      "report_id": Json(field.report_id),
      "payload_bits": Json(bits),
      "wire_bytes": Json(
        (bits + 7) / 8 + (if layout.has_report_ids { 1 } else { 0 }),
      ),
    })
  }
  {
    "has_report_ids": Json::boolean(layout.has_report_ids),
    "reports": Json::array(reports),
    "collections": Json::array(
      layout.collections.map(c => {
        "descriptor_offset": Json(c.descriptor_offset),
        "end_offset": Json(c.end_offset),
        "collection_type": Json(c.collection_type),
        "usage": usage_json(c.usage),
        "parent_index": optional_int(c.parent_index),
        "string_spans": Json::array(c.string_spans.map(index_span_json)),
        "designator_spans": Json::array(c.designator_spans.map(index_span_json)),
        "alternate_usages": Json::array(
          c.alternate_usages.map(group => {
            Json::array(group.map(usage_span_json))
          }),
        ),
      }),
    ),
    "fields": Json::array(
      layout.fields.map(f => {
        let (physical_min, physical_max) = effective_physical_range(f)
        {
          "descriptor_offset": Json(f.descriptor_offset),
          "kind": Json::string(report_kind_name(f.kind)),
          "report_id": Json(f.report_id),
          "bit_offset": Json(f.bit_offset),
          "bit_size": Json(f.bit_size),
          "count": Json(f.count),
          "flags": Json(f.flags),
          "logical_min": number64(f.logical_min),
          "logical_max": number64(f.logical_max),
          "physical_min": optional_int64(f.physical_min),
          "physical_max": optional_int64(f.physical_max),
          "effective_physical_min": number64(physical_min),
          "effective_physical_max": number64(physical_max),
          "unit": unit_json(f.unit),
          "unit_exponent": optional_int(f.unit_exponent),
          "collection_index": optional_int(f.collection_index),
          "usage_spans": Json::array(f.usage_spans.map(usage_span_json)),
          "usage_count": Json(usage_count(f.usage_spans)),
          "string_spans": Json::array(f.string_spans.map(index_span_json)),
          "designator_spans": Json::array(
            f.designator_spans.map(index_span_json),
          ),
          "alternate_usages": Json::array(
            f.alternate_usages.map(group => {
              Json::array(group.map(usage_span_json))
            }),
          ),
        }
      }),
    ),
  }
}

///|
pub fn report_to_json(report : DecodedReport) -> Json {
  {
    "kind": Json::string(report_kind_name(report.kind)),
    "report_id": Json(report.report_id),
    "buffered_values": Json::array(
      report.buffered_values.map(v => {
        "field_index": Json(v.field_index),
        "bit_offset": Json(v.bit_offset),
        "hex": Json::string(format_hex(v.bytes)),
      }),
    ),
    "opaque_values": Json::array(
      report.opaque_values.map(v => {
        "field_index": Json(v.field_index),
        "element_index": Json(v.element_index),
        "bit_offset": Json(v.bit_offset),
        "bit_size": Json(v.bit_size),
        "hex": Json::string(format_hex(v.bytes)),
      }),
    ),
    "values": Json::array(
      report.values.map(v => {
        "field_index": Json(v.field_index),
        "element_index": Json(v.element_index),
        "bit_offset": Json(v.bit_offset),
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
    "offset": Json(error.offset),
    "code": Json::string(error.code),
    "message": Json::string(error.message),
  }
}

///|
/// An unversioned component of the schema v2 descriptor's lints array.
pub fn lint_to_json(lint : Lint) -> Json {
  {
    "offset": Json(lint.offset),
    "code": Json(lint.code),
    "level": Json::string(
      match lint.level {
        Warning => "warning"
        Info => "info"
      },
    ),
    "message": Json(lint.message),
    "field_index": optional_int(lint.field_index),
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
    "byte_length": Json(bytes.length()),
    "lints": Json::array(lint_compiled(layout, items).map(lint_to_json)),
    "items": Json::array(
      items.map(item => {
        "offset": Json(item.offset),
        "type_code": Json(item.type_code),
        "tag": Json(item.tag),
        "data_hex": Json::string(format_hex(item.data)),
        "is_long": Json::boolean(item.is_long),
      }),
    ),
    "layout": layout_to_json(layout),
  })
}
