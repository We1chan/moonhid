///|
/// Integer values use the field's signedness; Raw values are packed LSB-first.
pub(all) enum ReportValue {
  Integer(Int64)
  Raw(Bytes)
} derive(Debug, Eq)

///|
pub extend ReportValue with @debug.Debug::{to_repr}

///|
pub extend ReportValue with Eq::{equal, not_equal}

///|
fn validate_wire(
  layout : Layout,
  kind : ReportKind,
  bytes : Bytes,
) -> Result[Int, Diagnostic] {
  let id = if layout.has_report_ids {
    if bytes.is_empty() {
      return Err(diagnostic(0, "short_report", "Missing Report ID"))
    }
    bytes[0].to_int()
  } else {
    0
  }
  let length = match report_length(layout, kind, id) {
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
  Ok(id)
}

///|
fn integer_fits(value : Int64, width : Int, signed : Bool) -> Bool {
  let minimum = if signed { -(1L << (width - 1)) } else { 0L }
  let maximum = if signed {
    (1L << (width - 1)) - 1L
  } else {
    (1L << width) - 1L
  }
  value >= minimum && value <= maximum
}

///|
fn raw_fits(bytes : Bytes, width : Int) -> Bool {
  if bytes.length() != (width + 7) / 8 {
    return false
  }
  let remainder = width % 8
  remainder == 0 || bytes[bytes.length() - 1].to_int() >> remainder == 0
}

///|
fn put_integer(
  target : FixedArray[Byte],
  offset : Int,
  width : Int,
  value : Int64,
) -> Unit {
  let start_byte = offset / 8
  let start_bit = offset % 8
  for bit = 0; bit < width; bit = bit + 1 {
    let position = start_bit + bit
    let mask = 1 << (position % 8)
    let previous = target[start_byte + position / 8].to_int()
    let next = if ((value >> bit) & 1L) != 0 {
      previous | mask
    } else {
      previous & (255 ^ mask)
    }
    target[start_byte + position / 8] = next.to_byte()
  }
}

///|
fn put_raw(
  target : FixedArray[Byte],
  offset : Int,
  width : Int,
  bytes : Bytes,
) -> Unit {
  let start_byte = offset / 8
  let start_bit = offset % 8
  for bit = 0; bit < width; bit = bit + 1 {
    let position = start_bit + bit
    let mask = 1 << (position % 8)
    let previous = target[start_byte + position / 8].to_int()
    let next = if ((bytes[bit / 8].to_int() >> (bit % 8)) & 1) != 0 {
      previous | mask
    } else {
      previous & (255 ^ mask)
    }
    target[start_byte + position / 8] = next.to_byte()
  }
}

///|
fn writable_value(
  field : Field,
  value : ReportValue,
  allow_out_of_range : Bool,
) -> Result[Unit, Diagnostic] {
  match value {
    Integer(value) => {
      if field.bit_size > 32 {
        return Err(
          diagnostic(
            field.descriptor_offset,
            "value_type",
            "Fields wider than 32 bits require Raw bytes",
          ),
        )
      }
      if !integer_fits(value, field.bit_size, field.logical_min < 0) {
        return Err(
          diagnostic(
            field.descriptor_offset,
            "value_range",
            "Value does not fit the field's width and signedness",
          ),
        )
      }
      if !allow_out_of_range &&
        (field.flags & 64) == 0 &&
        (value < field.logical_min || value > field.logical_max) {
        return Err(
          diagnostic(
            field.descriptor_offset,
            "logical_range",
            "Value is outside the field's logical range",
          ),
        )
      }
    }
    Raw(bytes) => {
      if field.bit_size <= 32 {
        return Err(
          diagnostic(
            field.descriptor_offset,
            "value_type",
            "Fields of 1..32 bits require Integer values",
          ),
        )
      }
      if !raw_fits(bytes, field.bit_size) {
        return Err(
          diagnostic(
            field.descriptor_offset,
            "value_range",
            "Raw bytes must match the field width with zero trailing high bits",
          ),
        )
      }
    }
  }
  Ok(())
}

///|
fn put_value(
  target : FixedArray[Byte],
  offset : Int,
  width : Int,
  value : ReportValue,
) -> Unit {
  match value {
    Integer(value) => put_integer(target, offset, width, value)
    Raw(bytes) => put_raw(target, offset, width, bytes)
  }
}

///|
/// Encodes every non-Constant element in descriptor order, then element order.
/// Constant and unused final bits are zero. Null State accepts representable
/// out-of-range values; allow_out_of_range permits replay of other invalid data.
pub fn encode_report(
  layout : Layout,
  kind : ReportKind,
  report_id : Int,
  values : Array[ReportValue],
  allow_out_of_range? : Bool = false,
) -> Result[Bytes, Diagnostic] {
  let length = match report_length(layout, kind, report_id) {
    Ok(length) => length
    Err(error) => return Err(error)
  }
  let mut expected = 0
  for field in layout.fields {
    if field.kind == kind &&
      field.report_id == report_id &&
      (field.flags & 1) == 0 {
      expected = expected + field.count
    }
  }
  if values.length() != expected {
    return Err(
      diagnostic(
        0,
        "value_count",
        "Expected \{expected} non-Constant values, received \{values.length()}",
      ),
    )
  }
  let target : FixedArray[Byte] = FixedArray::make(length, 0)
  let prefix = if layout.has_report_ids { 8 } else { 0 }
  if layout.has_report_ids {
    target[0] = report_id.to_byte()
  }
  let mut index = 0
  for field in layout.fields {
    if field.kind != kind ||
      field.report_id != report_id ||
      (field.flags & 1) != 0 {
      continue
    }
    for element = 0; element < field.count; element = element + 1 {
      let value = values[index]
      match writable_value(field, value, allow_out_of_range) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      put_value(
        target,
        prefix + field.bit_offset + element * field.bit_size,
        field.bit_size,
        value,
      )
      index = index + 1
    }
  }
  Ok(Bytes::from_array(target.exact_view()))
}

///|
fn selected_field(
  layout : Layout,
  kind : ReportKind,
  id : Int,
  field_index : Int,
  element_index : Int,
) -> Result[Field, Diagnostic] {
  if field_index < 0 || field_index >= layout.fields.length() {
    return Err(
      diagnostic(0, "field_index", "Field index is outside the layout"),
    )
  }
  let field = layout.fields[field_index]
  if field.kind != kind || field.report_id != id {
    return Err(
      diagnostic(
        field.descriptor_offset,
        "field_report",
        "Field belongs to another report kind or ID",
      ),
    )
  }
  if element_index < 0 || element_index >= field.count {
    return Err(
      diagnostic(
        field.descriptor_offset,
        "element_index",
        "Element index is outside Report Count",
      ),
    )
  }
  if (field.flags & 1) != 0 {
    return Err(
      diagnostic(
        field.descriptor_offset,
        "constant_field",
        "Constant fields are not data values",
      ),
    )
  }
  Ok(field)
}

///|
/// Reads one data element using global layout field and within-field indices.
pub fn read_field(
  layout : Layout,
  kind : ReportKind,
  bytes : Bytes,
  field_index : Int,
  element_index : Int,
) -> Result[ReportValue, Diagnostic] {
  let id = match validate_wire(layout, kind, bytes) {
    Ok(id) => id
    Err(error) => return Err(error)
  }
  let field = match
    selected_field(layout, kind, id, field_index, element_index) {
    Ok(field) => field
    Err(error) => return Err(error)
  }
  let offset = (if layout.has_report_ids { 8 } else { 0 }) +
    field.bit_offset +
    element_index * field.bit_size
  if field.bit_size > 32 {
    match extract_bytes(bytes, offset, field.bit_size) {
      Ok(raw) => Ok(Raw(raw))
      Err(error) => Err(error)
    }
  } else {
    match
      extract_bits(bytes, offset, field.bit_size, signed=field.logical_min < 0) {
      Ok(value) => Ok(Integer(value))
      Err(error) => Err(error)
    }
  }
}

///|
/// Returns a new report with one element replaced, preserving all other bits.
pub fn write_field(
  layout : Layout,
  kind : ReportKind,
  bytes : Bytes,
  field_index : Int,
  element_index : Int,
  value : ReportValue,
  allow_out_of_range? : Bool = false,
) -> Result[Bytes, Diagnostic] {
  let id = match validate_wire(layout, kind, bytes) {
    Ok(id) => id
    Err(error) => return Err(error)
  }
  let field = match
    selected_field(layout, kind, id, field_index, element_index) {
    Ok(field) => field
    Err(error) => return Err(error)
  }
  match writable_value(field, value, allow_out_of_range) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let target = FixedArray::makei(bytes.length(), i => bytes[i])
  let offset = (if layout.has_report_ids { 8 } else { 0 }) +
    field.bit_offset +
    element_index * field.bit_size
  put_value(target, offset, field.bit_size, value)
  Ok(Bytes::from_array(target.exact_view()))
}

///|
/// Finds all Variable elements with a Usage in one report; Arrays use selectors.
/// Repeated Usages intentionally return multiple references.
pub fn find_fields(
  layout : Layout,
  kind : ReportKind,
  report_id : Int,
  usage : Usage,
) -> Result[Array[FieldRef], Diagnostic] {
  match report_length(layout, kind, report_id) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let refs : Array[FieldRef] = []
  for field_index = 0
      field_index < layout.fields.length()
      field_index = field_index + 1 {
    let field = layout.fields[field_index]
    if field.kind == kind &&
      field.report_id == report_id &&
      (field.flags & 3) == 2 {
      for element_index = 0
          element_index < field.count
          element_index = element_index + 1 {
        if field_usage(field, element_index) == Some(usage) {
          refs.push({ field_index, element_index, })
        }
      }
    }
  }
  Ok(refs)
}

///|
pub(all) struct FieldRef {
  field_index : Int
  element_index : Int
} derive(Debug, Eq)

///|
pub extend FieldRef with @debug.Debug::{to_repr}

///|
pub extend FieldRef with Eq::{equal, not_equal}

///|
/// Converts an Array Usage to its logical selector, without expanding ranges.
pub fn array_selector(
  field : Field,
  usage : Usage,
) -> Result[Int64, Diagnostic] {
  if (field.flags & 3) != 0 {
    return Err(
      diagnostic(
        field.descriptor_offset,
        "value_type",
        "Usage selectors require a Data Array field",
      ),
    )
  }
  if !valid_usage_spans(field.usage_spans) ||
    field.flags < 0 ||
    field.flags > 255 ||
    field.bit_size < 1 ||
    field.bit_size > 32 ||
    field.logical_max < field.logical_min ||
    field.logical_min < -2147483648L ||
    field.logical_min > 2147483647L ||
    !integer_fits(field.logical_min, field.bit_size, field.logical_min < 0) ||
    !integer_fits(field.logical_max, field.bit_size, field.logical_min < 0) {
    return Err(
      diagnostic(
        field.descriptor_offset,
        "invalid_layout",
        "Invalid Array dimensions, flags, Usage spans or logical range",
      ),
    )
  }
  let mut index = 0L
  for span in field.usage_spans {
    if span.page == usage.page && usage.id >= span.min && usage.id <= span.max {
      let value = field.logical_min + index + (usage.id - span.min).to_int64()
      if value > field.logical_max {
        return Err(
          diagnostic(
            field.descriptor_offset,
            "logical_range",
            "Usage selector is outside the logical range",
          ),
        )
      }
      return Ok(value)
    }
    index = index + (span.max - span.min + 1).to_int64()
  }
  Err(
    diagnostic(
      field.descriptor_offset,
      "unknown_usage",
      "Usage is absent from the Array field",
    ),
  )
}
