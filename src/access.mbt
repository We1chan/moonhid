///|
/// One report of a layout, like the report lengths of HidP_GetCaps.
/// byte_length includes the Report ID prefix when the layout uses IDs, and
/// data_count is the number of values encode_report expects.
pub(all) struct ReportInfo {
  kind : ReportKind
  report_id : Int
  payload_bits : Int
  byte_length : Int
  data_count : Int
} derive(Debug, Eq)

///|
pub extend ReportInfo with @debug.Debug::{to_repr}

///|
pub extend ReportInfo with Eq::{equal, not_equal}

///|
/// Lists every report in Input, Output, Feature order, then by ascending ID.
pub fn list_reports(layout : Layout) -> Result[Array[ReportInfo], Diagnostic] {
  let reports : Array[ReportInfo] = []
  for kind in [Input, Output, Feature] {
    let ids : Array[Int] = []
    for field in layout.fields {
      if field.kind == kind && !ids.contains(field.report_id) {
        ids.push(field.report_id)
      }
    }
    ids.sort()
    for report_id in ids {
      let byte_length = match report_length(layout, kind, report_id) {
        Ok(length) => length
        Err(error) => return Err(error)
      }
      let mut payload_bits = 0
      let mut data_count = 0
      for field in layout.fields {
        if field.kind == kind && field.report_id == report_id {
          payload_bits = payload_bits + field.bit_size * field.count
          if (field.flags & 1) == 0 {
            data_count = data_count + field.count
          }
        }
      }
      reports.push({ kind, report_id, payload_bits, byte_length, data_count, })
    }
  }
  Ok(reports)
}

///|
/// A representable value outside the logical range, trying 0, then the
/// field type's minimum, then its maximum. None when the range fills the width.
fn outside_value(field : Field) -> Int64? {
  if field.bit_size < 1 || field.bit_size > 32 {
    return None
  }
  let width = field.bit_size
  let low = if field.logical_min < 0 { -(1L << (width - 1)) } else { 0L }
  let high = if field.logical_min < 0 {
    (1L << (width - 1)) - 1L
  } else {
    (1L << width) - 1L
  }
  for candidate in [0L, low, high] {
    if candidate < field.logical_min || candidate > field.logical_max {
      return Some(candidate)
    }
  }
  None
}

///|
/// The Usage an Array value selects. Out-of-range values, values past the
/// Usage list and Usage ID 0 ("no event" on every page) select nothing.
fn array_usage(field : Field, value : Int64) -> Usage? {
  if value < field.logical_min || value > field.logical_max {
    return None
  }
  let index = value - field.logical_min
  if index >= usage_count(field.usage_spans).to_int64() {
    return None
  }
  match usage_at(field.usage_spans, index.to_int(), false) {
    Some(usage) if usage.id != 0 => Some(usage)
    _ => None
  }
}

///|
/// The value written to an empty Array element: 0 when it selects nothing,
/// otherwise a representable out-of-range value.
fn array_empty_value(field : Field) -> Int64? {
  if array_usage(field, 0L) is None {
    Some(0L)
  } else {
    outside_value(field)
  }
}

///|
/// Data Variable controls with Logical 0..1, such as buttons and LEDs.
fn is_switch(field : Field) -> Bool {
  (field.flags & 3) == 2 &&
  field.bit_size <= 32 &&
  field.logical_min == 0L &&
  field.logical_max == 1L
}

///|
fn get_integer(
  source : FixedArray[Byte],
  offset : Int,
  width : Int,
  signed : Bool,
) -> Int64 {
  let mut value = 0L
  for bit = 0; bit < width; bit = bit + 1 {
    let position = offset + bit
    if ((source[position / 8].to_int() >> (position % 8)) & 1) != 0 {
      value = value | (1L << bit)
    }
  }
  if signed && ((value >> (width - 1)) & 1L) != 0 {
    value - (1L << width)
  } else {
    value
  }
}

///|
/// Like HidP_InitializeReportForID: Null State Variables get a null value,
/// Array elements get their empty value, and all other bits are zero.
/// Without a representable null value a field stays zero (lint null_without_room).
pub fn new_report(
  layout : Layout,
  kind : ReportKind,
  report_id : Int,
) -> Result[Bytes, Diagnostic] {
  let length = match report_length(layout, kind, report_id) {
    Ok(length) => length
    Err(error) => return Err(error)
  }
  let target : FixedArray[Byte] = FixedArray::make(length, 0)
  let prefix = if layout.has_report_ids { 8 } else { 0 }
  if layout.has_report_ids {
    target[0] = report_id.to_byte()
  }
  for field in layout.fields {
    if field.kind != kind ||
      field.report_id != report_id ||
      (field.flags & 1) != 0 ||
      field.bit_size > 32 {
      continue
    }
    let initial = if (field.flags & 2) == 0 {
      array_empty_value(field)
    } else if (field.flags & 64) != 0 {
      outside_value(field)
    } else {
      None
    }
    if initial is Some(value) && value != 0L {
      for element = 0; element < field.count; element = element + 1 {
        put_integer(
          target,
          prefix + field.bit_offset + element * field.bit_size,
          field.bit_size,
          value,
        )
      }
    }
  }
  Ok(Bytes::from_array(target.exact_view()))
}

///|
fn unique_reference(
  layout : Layout,
  kind : ReportKind,
  report_id : Int,
  usage : Usage,
) -> Result[FieldRef, Diagnostic] {
  let refs = match find_fields(layout, kind, report_id, usage) {
    Ok(refs) => refs
    Err(error) => return Err(error)
  }
  match refs {
    [reference] => Ok(reference)
    [] =>
      Err(
        diagnostic(
          0, "unknown_usage", "Usage is not a Data Variable element of this report; Array Usages use active_usages and set_usages",
        ),
      )
    _ =>
      Err(
        diagnostic(
          layout.fields[refs[0].field_index].descriptor_offset,
          "ambiguous_usage",
          "Usage matches \{refs.length()} elements; select one with find_fields and read_field or write_field",
        ),
      )
  }
}

///|
/// Reads the single Data Variable element with this Usage, like HidP_GetUsageValue.
/// Repeated Usages return ambiguous_usage; use find_fields and read_field.
pub fn get_usage_value(
  layout : Layout,
  kind : ReportKind,
  bytes : Bytes,
  usage : Usage,
) -> Result[ReportValue, Diagnostic] {
  let id = match validate_wire(layout, kind, bytes) {
    Ok(id) => id
    Err(error) => return Err(error)
  }
  match unique_reference(layout, kind, id, usage) {
    Ok(reference) =>
      read_field(
        layout,
        kind,
        bytes,
        reference.field_index,
        reference.element_index,
      )
    Err(error) => Err(error)
  }
}

///|
/// Writes the single Data Variable element with this Usage into a copy,
/// like HidP_SetUsageValue. Range rules match write_field.
pub fn set_usage_value(
  layout : Layout,
  kind : ReportKind,
  bytes : Bytes,
  usage : Usage,
  value : ReportValue,
  allow_out_of_range? : Bool = false,
) -> Result[Bytes, Diagnostic] {
  let id = match validate_wire(layout, kind, bytes) {
    Ok(id) => id
    Err(error) => return Err(error)
  }
  match unique_reference(layout, kind, id, usage) {
    Ok(reference) =>
      write_field(
        layout,
        kind,
        bytes,
        reference.field_index,
        reference.element_index,
        value,
        allow_out_of_range~,
      )
    Err(error) => Err(error)
  }
}

///|
/// Usages that are on, like HidP_GetUsagesEx: Logical 0..1 Variable controls
/// holding 1 and the Usages selected by Array elements. Each Usage is listed
/// once, in field and element order.
pub fn active_usages(
  layout : Layout,
  kind : ReportKind,
  bytes : Bytes,
) -> Result[Array[Usage], Diagnostic] {
  let id = match validate_wire(layout, kind, bytes) {
    Ok(id) => id
    Err(error) => return Err(error)
  }
  let prefix = if layout.has_report_ids { 8 } else { 0 }
  let active : Array[Usage] = []
  let seen : Map[Int64, Bool] = Map([])
  for field in layout.fields {
    if field.kind != kind ||
      field.report_id != id ||
      (field.flags & 1) != 0 ||
      field.bit_size > 32 {
      continue
    }
    let is_array = (field.flags & 2) == 0
    if !is_array && !is_switch(field) {
      continue
    }
    for element = 0; element < field.count; element = element + 1 {
      let value = match
        extract_bits(
          bytes,
          prefix + field.bit_offset + element * field.bit_size,
          field.bit_size,
          signed=field.logical_min < 0,
        ) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let usage = if is_array {
        array_usage(field, value)
      } else if value == 1L {
        field_usage(field, element)
      } else {
        None
      }
      if usage is Some(usage) {
        let key = (usage.page.to_int64() << 16) | usage.id.to_int64()
        if !seen.contains(key) {
          seen[key] = true
          active.push(usage)
        }
      }
    }
  }
  Ok(active)
}

///|
/// Turns Usages on in a copy, like HidP_SetUsages. A Logical 0..1 Variable
/// control is set to 1; otherwise the Usage's selector goes into the first
/// empty element of an Array that lists it (array_full when none is empty).
/// Usages that are already on are left as they are.
pub fn set_usages(
  layout : Layout,
  kind : ReportKind,
  bytes : Bytes,
  usages : Array[Usage],
) -> Result[Bytes, Diagnostic] {
  change_usages(layout, kind, bytes, usages, true)
}

///|
/// Turns Usages off in a copy, like HidP_UnsetUsages. Variable controls are
/// set to 0 and matching Array elements get the empty value. Usages that are
/// already off are left as they are.
pub fn clear_usages(
  layout : Layout,
  kind : ReportKind,
  bytes : Bytes,
  usages : Array[Usage],
) -> Result[Bytes, Diagnostic] {
  change_usages(layout, kind, bytes, usages, false)
}

///|
fn change_usages(
  layout : Layout,
  kind : ReportKind,
  bytes : Bytes,
  usages : Array[Usage],
  on : Bool,
) -> Result[Bytes, Diagnostic] {
  let id = match validate_wire(layout, kind, bytes) {
    Ok(id) => id
    Err(error) => return Err(error)
  }
  let target = FixedArray::makei(bytes.length(), i => bytes[i])
  let prefix = if layout.has_report_ids { 8 } else { 0 }
  for usage in usages {
    let switches : Array[(Field, Int)] = []
    let mut variable = false
    for field in layout.fields {
      if field.kind != kind || field.report_id != id || (field.flags & 3) != 2 {
        continue
      }
      for element = 0; element < field.count; element = element + 1 {
        if field_usage(field, element) == Some(usage) {
          variable = true
          if is_switch(field) {
            switches.push((field, element))
          }
        }
      }
    }
    if switches.length() > 1 {
      return Err(
        diagnostic(
          switches[0].0.descriptor_offset,
          "ambiguous_usage",
          "Usage matches \{switches.length()} elements; select one with find_fields and write_field",
        ),
      )
    }
    if switches is [(field, element)] {
      put_integer(
        target,
        prefix + field.bit_offset + element * field.bit_size,
        field.bit_size,
        if on {
          1L
        } else {
          0L
        },
      )
      continue
    }
    let mut handled = false
    let mut failure : Diagnostic? = None
    for field in layout.fields {
      if handled {
        break
      }
      if field.kind != kind ||
        field.report_id != id ||
        (field.flags & 3) != 0 ||
        field.bit_size > 32 {
        continue
      }
      let selector = match array_selector(field, usage) {
        Ok(selector) => selector
        Err({ code: "unknown_usage", .. }) => continue
        Err(error) => {
          if failure is None {
            failure = Some(error)
          }
          continue
        }
      }
      if array_usage(field, selector) is None {
        if failure is None {
          failure = Some(
            diagnostic(
              field.descriptor_offset,
              "unknown_usage",
              "Usage ID 0 marks an empty Array element",
            ),
          )
        }
        continue
      }
      let signed = field.logical_min < 0
      let empty = array_empty_value(field)
      if on {
        let mut free = -1
        for element = 0; element < field.count; element = element + 1 {
          let current = get_integer(
            target,
            prefix + field.bit_offset + element * field.bit_size,
            field.bit_size,
            signed,
          )
          if current == selector {
            handled = true
            break
          }
          if free < 0 && array_usage(field, current) is None {
            free = element
          }
        }
        if !handled && free >= 0 {
          put_integer(
            target,
            prefix + field.bit_offset + free * field.bit_size,
            field.bit_size,
            selector,
          )
          handled = true
        }
        if !handled && failure is None {
          failure = Some(
            diagnostic(
              field.descriptor_offset,
              "array_full",
              "Every Array element already holds a Usage",
            ),
          )
        }
      } else {
        let blank = match empty {
          Some(value) => value
          None =>
            return Err(
              diagnostic(
                field.descriptor_offset,
                "array_no_empty",
                "The Array's logical range leaves no value for an empty element",
              ),
            )
        }
        for element = 0; element < field.count; element = element + 1 {
          let offset = prefix + field.bit_offset + element * field.bit_size
          if get_integer(target, offset, field.bit_size, signed) == selector {
            put_integer(target, offset, field.bit_size, blank)
          }
        }
        handled = true
      }
    }
    if handled {
      continue
    }
    match failure {
      Some(error) => return Err(error)
      None =>
        return Err(
          if variable {
            diagnostic(
              0, "value_type", "Usage is a multi-value control; use set_usage_value",
            )
          } else {
            diagnostic(
              0, "unknown_usage", "Usage is neither an on/off control nor listed by an Array of this report",
            )
          },
        )
    }
  }
  Ok(Bytes::from_array(target.exact_view()))
}

///|
/// Reads one Usage as a physical quantity, like HidP_GetScaledUsageValue
/// followed by applying the Unit Exponent. See physical_value.
pub fn get_physical_value(
  layout : Layout,
  kind : ReportKind,
  bytes : Bytes,
  usage : Usage,
) -> Result[Double, Diagnostic] {
  let id = match validate_wire(layout, kind, bytes) {
    Ok(id) => id
    Err(error) => return Err(error)
  }
  let reference = match unique_reference(layout, kind, id, usage) {
    Ok(reference) => reference
    Err(error) => return Err(error)
  }
  let field = layout.fields[reference.field_index]
  match
    read_field(
      layout,
      kind,
      bytes,
      reference.field_index,
      reference.element_index,
    ) {
    Ok(Integer(value)) => physical_value(field, value)
    Ok(Raw(_)) =>
      Err(
        diagnostic(
          field.descriptor_offset,
          "value_type",
          "Fields wider than 32 bits have no physical scaling",
        ),
      )
    Err(error) => Err(error)
  }
}

///|
/// Writes a physical quantity to one Usage in a copy, like
/// HidP_SetScaledUsageValue. See logical_from_physical for rounding.
pub fn set_physical_value(
  layout : Layout,
  kind : ReportKind,
  bytes : Bytes,
  usage : Usage,
  physical : Double,
) -> Result[Bytes, Diagnostic] {
  let id = match validate_wire(layout, kind, bytes) {
    Ok(id) => id
    Err(error) => return Err(error)
  }
  let reference = match unique_reference(layout, kind, id, usage) {
    Ok(reference) => reference
    Err(error) => return Err(error)
  }
  match logical_from_physical(layout.fields[reference.field_index], physical) {
    Ok(logical) =>
      write_field(
        layout,
        kind,
        bytes,
        reference.field_index,
        reference.element_index,
        Integer(logical),
      )
    Err(error) => Err(error)
  }
}
