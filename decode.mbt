///|
pub(all) struct DecodedValue {
  field_index : Int
  element_index : Int
  bit_offset : Int
  value : Int64
  usage : Usage?
  is_array : Bool
  in_logical_range : Bool
  is_null : Bool
} derive(Debug, Eq)

///|
pub extend DecodedValue with @debug.Debug::{to_repr}

///|
pub extend DecodedValue with Eq::{equal, not_equal}

///|
pub(all) struct DecodedReport {
  kind : ReportKind
  report_id : Int
  values : Array[DecodedValue]
} derive(Debug, Eq)

///|
pub extend DecodedReport with @debug.Debug::{to_repr}

///|
pub extend DecodedReport with Eq::{equal, not_equal}

///|
/// Returns the exact wire length, including an ID prefix when used.
pub fn report_length(
  layout : Layout,
  kind : ReportKind,
  report_id : Int,
) -> Result[Int, Diagnostic] {
  if layout.fields.length() > 4096 {
    return Err(diagnostic(0, "invalid_layout", "Layout exceeds 4096 fields"))
  }
  let mut bits = 0
  let mut found = false
  for field in layout.fields {
    if field.kind != kind || field.report_id != report_id {
      continue
    }
    found = true
    if field.bit_size < 1 ||
      field.bit_size > 32 ||
      field.count < 1 ||
      field.count > 1024 ||
      field.bit_offset != bits {
      return Err(
        diagnostic(
          field.descriptor_offset,
          "invalid_layout",
          "Layout dimensions or offsets are invalid",
        ),
      )
    }
    bits = bits + field.bit_size * field.count
    if bits > 65536 ||
      field.usages.length() > 1024 ||
      field.flags < 0 ||
      field.flags > 255 {
      return Err(
        diagnostic(
          field.descriptor_offset,
          "invalid_layout",
          "Layout exceeds supported limits",
        ),
      )
    }
  }
  if !found {
    Err(
      diagnostic(0, "unknown_report", "No report with the selected kind and ID"),
    )
  } else if (layout.has_report_ids && (report_id < 1 || report_id > 255)) ||
    (!layout.has_report_ids && report_id != 0) {
    Err(diagnostic(0, "invalid_layout", "Report ID disagrees with layout mode"))
  } else {
    Ok((bits + 7) / 8 + (if layout.has_report_ids { 1 } else { 0 }))
  }
}

///|
/// Decodes a wire report. Input length must exactly match the declared report.
/// Constant fields are omitted; array values index usages from Logical Minimum.
/// Out-of-range values are retained, with is_null set only for Null State fields.
pub fn decode_report(
  layout : Layout,
  kind : ReportKind,
  bytes : Bytes,
) -> Result[DecodedReport, Diagnostic] {
  let report_id = if layout.has_report_ids {
    if bytes.is_empty() {
      return Err(diagnostic(0, "short_report", "Missing Report ID"))
    }
    bytes[0].to_int()
  } else {
    0
  }
  let length = match report_length(layout, kind, report_id) {
    Ok(length) => length
    Err(error) => return Err(error)
  }
  if bytes.length() != length {
    return Err(
      diagnostic(
        bytes.length(),
        "report_length",
        "Wire report length does not match the descriptor",
      ),
    )
  }
  let prefix_bits = if layout.has_report_ids { 8 } else { 0 }
  let values : Array[DecodedValue] = []
  for field_index = 0
      field_index < layout.fields.length()
      field_index = field_index + 1 {
    let field = layout.fields[field_index]
    if field.kind != kind ||
      field.report_id != report_id ||
      (field.flags & 1) != 0 {
      continue
    }
    for element_index = 0
        element_index < field.count
        element_index = element_index + 1 {
      let offset = field.bit_offset + element_index * field.bit_size
      let value = match
        extract_bits(
          bytes,
          prefix_bits + offset,
          field.bit_size,
          signed=field.logical_min < 0,
        ) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let in_logical_range = value >= field.logical_min &&
        value <= field.logical_max
      let is_array = (field.flags & 2) == 0
      let usage = if is_array {
        let index = value - field.logical_min
        if in_logical_range &&
          index >= 0 &&
          index < field.usages.length().to_int64() {
          field.usages.get(index.to_int())
        } else {
          None
        }
      } else if element_index < field.usages.length() {
        field.usages.get(element_index)
      } else {
        field.usages.last()
      }
      values.push({
        field_index,
        element_index,
        bit_offset: offset,
        value,
        usage,
        is_array,
        in_logical_range,
        is_null: !in_logical_range && (field.flags & 64) != 0,
      })
    }
  }
  Ok({ kind, report_id, values, })
}
