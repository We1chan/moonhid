///|
/// Warning identifies a likely mapping/structure problem; Info is advisory.
pub(all) enum LintLevel {
  Warning
  Info
} derive(Debug, Eq)

///|
pub extend LintLevel with @debug.Debug::{to_repr}

///|
pub extend LintLevel with Eq::{equal, not_equal}

///|
/// offset is a descriptor item byte offset; field_index indexes Layout.fields.
/// Codes and levels are documented in docs/lint.md. Messages are explanatory.
pub(all) struct Lint {
  offset : Int
  code : String
  level : LintLevel
  message : String
  field_index : Int?
} derive(Debug, Eq)

///|
pub extend Lint with @debug.Debug::{to_repr}

///|
pub extend Lint with Eq::{equal, not_equal}

///|
// Only raw Maximum encodings are absent from Field. Minimum values and all
// semantic/local/collection state come from the existing compiler.
priv struct LintGlobals {
  logical_max : Item?
  physical_max : Item?
}

///|
fn lint_report_key(field : Field) -> Int {
  let kind = match field.kind {
    Input => 0
    Output => 1
    Feature => 2
  }
  kind * 256 + field.report_id
}

///|
// A nested Application is an ancestor, but is not a top-level Application.
fn lint_application(layout : Layout, field : Field) -> (Bool, Int?) {
  let mut index = field.collection_index
  let mut has_application = false
  let mut top_application = None
  while index is Some(i) {
    let collection = layout.collections[i]
    if collection.collection_type == 1 {
      has_application = true
      if collection.parent_index is None {
        top_application = Some(i)
      }
    }
    index = collection.parent_index
  }
  (has_application, top_application)
}

///|
fn lint_maximum(
  item : Item?,
  minimum_nonnegative : Bool,
  name : String,
  code : String,
  field_index : Int,
  seen : Map[Int, Bool],
  lints : Array[Lint],
) -> Unit {
  if minimum_nonnegative && item is Some(maximum) {
    let signed = item_signed(maximum)
    if signed < 0 && !seen.contains(maximum.offset) {
      seen[maximum.offset] = true
      let suggestion = if maximum.data.length() < 4 {
        "A wider short item can make the positive extent explicit."
      } else {
        "No wider short item exists; check the intended unsigned extent."
      }
      lints.push({
        offset: maximum.offset,
        code,
        level: Info,
        message: "\{name} Maximum encodes unsigned \{item_unsigned(maximum)} or signed \{signed} with a nonnegative minimum. \{suggestion}",
        field_index: Some(field_index),
      })
    }
  }
}

///|
fn lint_encodings(
  items : Array[Item],
  fields : Array[Field],
  lints : Array[Lint],
) -> Unit {
  let mut globals : LintGlobals = { logical_max: None, physical_max: None, }
  let stack : Array[LintGlobals] = []
  let seen : Map[Int, Bool] = Map([])
  let mut field_index = 0
  for item in items {
    if item.type_code == 1 {
      match item.tag {
        2 => globals = { ..globals, logical_max: Some(item), }
        4 => globals = { ..globals, physical_max: Some(item), }
        10 => stack.push(globals)
        11 =>
          match stack.pop() {
            Some(saved) => globals = saved
            None => () // compile_descriptor already checked balanced Push/Pop.
          }
        _ => ()
      }
    } else if item.type_code == 0 &&
      (item.tag == 8 || item.tag == 9 || item.tag == 11) {
      let field = fields[field_index]
      if (field.flags & 1) == 0 {
        lint_maximum(
          globals.logical_max,
          field.logical_min >= 0,
          "Logical",
          "logical_max_sign",
          field_index,
          seen,
          lints,
        )
        lint_maximum(
          globals.physical_max,
          field.physical_min is Some(minimum) && minimum >= 0,
          "Physical",
          "physical_max_sign",
          field_index,
          seen,
          lints,
        )
      }
      field_index = field_index + 1
    }
  }
}

///|
fn lint_field(field : Field, index : Int, lints : Array[Lint]) -> Unit {
  // Constant/padding fields have no control Usage or meaningful logical range.
  if (field.flags & 1) != 0 {
    return
  }
  if (field.flags & 64) != 0 && field.bit_size <= 32 {
    let minimum = if field.logical_min < 0 {
      -(1L << (field.bit_size - 1))
    } else {
      0L
    }
    let maximum = if field.logical_min < 0 {
      (1L << (field.bit_size - 1)) - 1
    } else {
      (1L << field.bit_size) - 1
    }
    if field.logical_min == minimum && field.logical_max == maximum {
      lints.push({
        offset: field.descriptor_offset,
        code: "null_without_room",
        level: Warning,
        message: "Null State is set, but the logical range fills all \{field.bit_size}-bit values",
        field_index: Some(index),
      })
    }
  }
  let usages = usage_count(field.usage_spans)
  if usages == 0 {
    lints.push({
      offset: field.descriptor_offset,
      code: "missing_usage",
      level: Warning,
      message: "Data field has no primary Usage; a host may ignore it as padding",
      field_index: Some(index),
    })
  } else if (field.flags & 2) != 0 {
    if usages > field.count {
      lints.push({
        offset: field.descriptor_offset,
        code: "usage_count",
        level: Warning,
        message: "\{usages} primary Usages exceed Report Count \{field.count}; extra Usages have no Variable element",
        field_index: Some(index),
      })
    } else if usages > 1 && usages < field.count {
      lints.push({
        offset: field.descriptor_offset,
        code: "usage_count",
        level: Info,
        message: "\{usages} primary Usages for \{field.count} Variable elements; the last Usage repeats",
        field_index: Some(index),
      })
    }
  } else {
    let selectors = field.logical_max - field.logical_min + 1
    if usages.to_int64() != selectors {
      lints.push({
        offset: field.descriptor_offset,
        code: "usage_count",
        level: Warning,
        message: "\{usages} primary Usages for \{selectors} logical Array selectors; inspect the intended mapping",
        field_index: Some(index),
      })
    }
  }
}

///|
fn lint_layout(layout : Layout, lints : Array[Lint]) -> Unit {
  let last_fields : Map[Int, Int] = Map([])
  let owners : Map[Int, Array[Int]] = Map([])
  let unnumbered_conflicts : Map[Int, Bool] = Map([])
  for i = 0; i < layout.fields.length(); i = i + 1 {
    let field = layout.fields[i]
    let key = lint_report_key(field)
    last_fields[key] = i
    lint_field(field, i, lints)
    let (has_application, top_application) = lint_application(layout, field)
    if (field.flags & 1) == 0 && !has_application {
      lints.push({
        offset: field.descriptor_offset,
        code: "field_outside_application",
        level: Warning,
        message: "Data field has no Application Collection ancestor",
        field_index: Some(i),
      })
    }
    // Padding also contributes to a report: it must stay in that report's TLC.
    if top_application is Some(application) {
      let applications = owners.get_or_default(key, [])
      if !applications.contains(application) {
        if !applications.is_empty() {
          if field.report_id == 0 {
            unnumbered_conflicts[application] = true
          } else {
            lints.push({
              offset: field.descriptor_offset,
              code: "report_id_shared_across_applications",
              level: Warning,
              message: "\{report_kind_name(field.kind)} Report ID \{field.report_id} spans different top-level Application Collections",
              field_index: Some(i),
            })
          }
        }
        applications.push(application)
        owners[key] = applications
      }
    }
  }
  for i = 0; i < layout.fields.length(); i = i + 1 {
    let field = layout.fields[i]
    if last_fields[lint_report_key(field)] == i {
      let bits = field.bit_offset + field.bit_size * field.count
      if bits % 8 != 0 {
        lints.push({
          offset: field.descriptor_offset,
          code: "unaligned_report",
          level: Info,
          message: "\{report_kind_name(field.kind)} Report ID \{field.report_id} has \{bits} payload bits; pad \{8 - bits % 8} bits with zero to finish the wire byte",
          field_index: Some(i),
        })
      }
    }
  }
  let mut applications = 0
  for collection in layout.collections {
    if collection.usage is None {
      lints.push({
        offset: collection.descriptor_offset,
        code: "collection_without_usage",
        level: Warning,
        message: "Collection has no primary Usage",
        field_index: None,
      })
    }
  }
  for i = 0; i < layout.collections.length(); i = i + 1 {
    let collection = layout.collections[i]
    if collection.parent_index is None && collection.collection_type == 1 {
      applications = applications + 1
      if applications > 1 && !layout.has_report_ids {
        let conflict = unnumbered_conflicts.contains(i)
        lints.push({
          offset: collection.descriptor_offset,
          code: "multiple_applications_without_report_id",
          level: if conflict {
            Warning
          } else {
            Info
          },
          message: if conflict {
            "Unnumbered reports of the same kind span top-level Application Collections; assign separate Report IDs"
          } else {
            "Multiple top-level Application Collections have no Report IDs; check report routing if adding reports of the same kind"
          },
          field_index: None,
        })
      }
    }
  }
}

///|
/// Compiles first and returns the identical Diagnostic on failure. Lints never
/// change the layout. Results sort by offset, then code; repeated Maximum items
/// and each later application/report pair produce at most one matching lint.
pub fn lint_descriptor(bytes : Bytes) -> Result[Array[Lint], Diagnostic] {
  let layout = match compile_descriptor(bytes) {
    Ok(layout) => layout
    Err(error) => return Err(error)
  }
  let items = match parse_items(bytes) {
    Ok(items) => items
    Err(error) => return Err(error)
  }
  let lints : Array[Lint] = []
  lint_encodings(items, layout.fields, lints)
  lint_layout(layout, lints)
  lints.sort_by((a, b) => {
    let offset = a.offset.compare(b.offset)
    if offset == 0 {
      a.code.compare(b.code)
    } else {
      offset
    }
  })
  Ok(lints)
}
