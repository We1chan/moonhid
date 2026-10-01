///|
pub(all) enum ReportKind {
  Input
  Output
  Feature
} derive(Debug, Eq)

///|
pub extend ReportKind with @debug.Debug::{to_repr}

///|
pub extend ReportKind with Eq::{equal, not_equal}

///|
pub(all) struct Usage {
  page : Int
  id : Int
} derive(Debug, Eq)

///|
pub extend Usage with @debug.Debug::{to_repr}

///|
pub extend Usage with Eq::{equal, not_equal}

///|
/// Collections are stored in descriptor order. Parent indices form a tree.
pub(all) struct Collection {
  descriptor_offset : Int
  end_offset : Int
  collection_type : Int
  usage : Usage?
  parent_index : Int?
} derive(Debug, Eq)

///|
pub extend Collection with @debug.Debug::{to_repr}

///|
pub extend Collection with Eq::{equal, not_equal}

///|
/// bit_offset excludes an optional Report ID prefix byte. Padding is retained.
pub(all) struct Field {
  descriptor_offset : Int
  kind : ReportKind
  report_id : Int
  bit_offset : Int
  bit_size : Int
  count : Int
  flags : Int
  logical_min : Int64
  logical_max : Int64
  physical_min : Int64?
  physical_max : Int64?
  unit : Int64?
  unit_exponent : Int?
  collection_index : Int?
  usages : Array[Usage]
} derive(Debug, Eq)

///|
pub extend Field with @debug.Debug::{to_repr}

///|
pub extend Field with Eq::{equal, not_equal}

///|
pub(all) struct Layout {
  fields : Array[Field]
  collections : Array[Collection]
  has_report_ids : Bool
} derive(Debug, Eq)

///|
pub extend Layout with @debug.Debug::{to_repr}

///|
pub extend Layout with Eq::{equal, not_equal}

///|
priv struct GlobalState {
  page : Int
  logical_min : Int64
  logical_max_unsigned : Int64
  logical_max_signed : Int64
  physical_min : Int64?
  physical_max_unsigned : Int64?
  physical_max_signed : Int64?
  unit : Int64?
  unit_exponent : Int?
  size : Int
  count : Int
  report_id : Int
}

///|
fn usage_value(item : Item, page : Int) -> Usage {
  let value = item_unsigned(item)
  if item.data.length() == 4 {
    { page: (value >> 16).to_int(), id: (value & 65535L).to_int(), }
  } else {
    { page, id: value.to_int(), }
  }
}

///|
/// Compiles the supported HID subset. Unknown semantics are rejected explicitly.
/// Limits: 32 bits/value, 1024 values/Main item and 65536 bits/report.
pub fn compile_descriptor(bytes : Bytes) -> Result[Layout, Diagnostic] {
  let items = match parse_items(bytes) {
    Ok(items) => items
    Err(error) => return Err(error)
  }
  let fields : Array[Field] = []
  let collections : Array[Collection] = []
  let collection_stack : Array[Int] = []
  let offsets : Map[Int, Int] = Map([])
  let mut global : GlobalState = {
    page: 0,
    logical_min: 0,
    logical_max_unsigned: 0,
    logical_max_signed: 0,
    physical_min: None,
    physical_max_unsigned: None,
    physical_max_signed: None,
    unit: None,
    unit_exponent: None,
    size: 0,
    count: 0,
    report_id: 0,
  }
  let locals : Array[Usage] = []
  let mut range_min : Usage? = None
  let mut has_report_ids = false
  let stack : Array[GlobalState] = []
  for item in items {
    if item.is_long || item.type_code == 3 {
      return Err(
        diagnostic(
          item.offset,
          "unsupported_item",
          "Long and reserved items are not compiled",
        ),
      )
    }
    let value = item_unsigned(item)
    if item.type_code == 1 {
      match item.tag {
        0 => {
          if value > 65535 {
            return Err(
              diagnostic(
                item.offset,
                "usage_page",
                "Usage Page exceeds 16 bits",
              ),
            )
          }
          global = { ..global, page: value.to_int(), }
        }
        1 => global = { ..global, logical_min: item_signed(item), }
        2 =>
          global = {
            ..global,
            logical_max_unsigned: value,
            logical_max_signed: item_signed(item),
          }
        3 => global = { ..global, physical_min: Some(item_signed(item)), }
        4 =>
          global = {
            ..global,
            physical_max_unsigned: Some(value),
            physical_max_signed: Some(item_signed(item)),
          }
        5 => {
          let exponent = if value <= 15 {
            signed_nibble(value.to_int())
          } else {
            let signed = item_signed(item)
            if signed < -8 || signed > 7 {
              return Err(
                diagnostic(
                  item.offset,
                  "unit_exponent",
                  "Unit Exponent must encode -8..7",
                ),
              )
            }
            signed.to_int()
          }
          global = { ..global, unit_exponent: Some(exponent), }
        }
        6 => global = { ..global, unit: Some(value), }
        7 => {
          if value > 32 {
            return Err(
              diagnostic(
                item.offset,
                "report_size",
                "Report Size must be 0..32; zero cannot define a report",
              ),
            )
          }
          global = { ..global, size: value.to_int(), }
        }
        8 => {
          if item.data.length() != 1 || value < 1 || value > 255 {
            return Err(
              diagnostic(
                item.offset,
                "report_id",
                "Report ID must be a single byte in 1..255",
              ),
            )
          }
          has_report_ids = true
          global = { ..global, report_id: value.to_int(), }
        }
        9 => {
          if value < 1 || value > 1024 {
            return Err(
              diagnostic(
                item.offset,
                "report_count",
                "Report Count must be 1..1024",
              ),
            )
          }
          global = { ..global, count: value.to_int(), }
        }
        10 => {
          if !item.data.is_empty() || stack.length() >= 64 {
            return Err(
              diagnostic(
                item.offset,
                "global_stack",
                "Push payload or global stack depth exceeds 64",
              ),
            )
          }
          stack.push(global)
        }
        11 => {
          if !item.data.is_empty() {
            return Err(
              diagnostic(
                item.offset,
                "global_stack",
                "Pop cannot have a payload",
              ),
            )
          }
          global = match stack.pop() {
            Some(saved) => saved
            None =>
              return Err(
                diagnostic(
                  item.offset,
                  "global_stack",
                  "Global stack underflow",
                ),
              )
          }
        }
        _ =>
          return Err(
            diagnostic(
              item.offset,
              "unsupported_global",
              "Global item is not supported",
            ),
          )
      }
    } else if item.type_code == 2 {
      let usage = usage_value(item, global.page)
      match item.tag {
        0 => locals.push(usage)
        1 => {
          if range_min is Some(_) {
            return Err(
              diagnostic(item.offset, "usage_range", "Nested Usage Minimum"),
            )
          }
          range_min = Some(usage)
        }
        2 => {
          let minimum = match range_min {
            Some(minimum) => minimum
            None =>
              return Err(
                diagnostic(
                  item.offset,
                  "usage_range",
                  "Usage Maximum has no minimum",
                ),
              )
          }
          if minimum.page != usage.page ||
            minimum.id > usage.id ||
            usage.id - minimum.id >= 1024 {
            return Err(
              diagnostic(
                item.offset,
                "usage_range",
                "Invalid or oversized usage range",
              ),
            )
          }
          for id = minimum.id; id <= usage.id; id = id + 1 {
            locals.push({ page: usage.page, id, })
          }
          range_min = None
        }
        _ =>
          return Err(
            diagnostic(
              item.offset,
              "unsupported_local",
              "Local item semantics are not supported",
            ),
          )
      }
      if locals.length() > 1024 {
        return Err(
          diagnostic(item.offset, "usage_limit", "Too many local usages"),
        )
      }
    } else {
      if range_min is Some(_) {
        return Err(
          diagnostic(item.offset, "usage_range", "Unclosed usage range"),
        )
      }
      match item.tag {
        10 => {
          if item.data.length() > 1 ||
            collection_stack.length() >= 64 ||
            collections.length() >= 4096 {
            return Err(
              diagnostic(
                item.offset,
                "collection",
                "Invalid collection, depth exceeds 64 or more than 4096 collections",
              ),
            )
          }
          let index = collections.length()
          collections.push({
            descriptor_offset: item.offset,
            end_offset: -1,
            collection_type: value.to_int(),
            usage: locals.get(0),
            parent_index: collection_stack.last(),
          })
          collection_stack.push(index)
        }
        12 => {
          if !item.data.is_empty() || collection_stack.is_empty() {
            return Err(
              diagnostic(item.offset, "collection", "Unmatched End Collection"),
            )
          }
          match collection_stack.pop() {
            Some(index) =>
              collections[index] = {
                ..collections[index],
                end_offset: item.offset,
              }
            None => () // The empty stack is checked above.
          }
        }
        8 | 9 | 11 => {
          if (value & 256L) != 0 {
            return Err(
              diagnostic(
                item.offset,
                "buffered_bytes",
                "Buffered Bytes are not supported",
              ),
            )
          }
          if value > 255L {
            return Err(
              diagnostic(
                item.offset,
                "main_flags",
                "Reserved Main flags are not supported",
              ),
            )
          }
          if global.size == 0 || global.count == 0 {
            return Err(
              diagnostic(
                item.offset,
                "missing_dimensions",
                "Main item requires Report Size and Count",
              ),
            )
          }
          let kind = if item.tag == 8 {
            Input
          } else if item.tag == 9 {
            Output
          } else {
            Feature
          }
          if fields.length() >= 4096 {
            return Err(
              diagnostic(
                item.offset,
                "field_limit",
                "Descriptor exceeds 4096 Main report items",
              ),
            )
          }
          let cursor = item.tag * 256 + global.report_id
          let offset = offsets.get_or_default(cursor, 0)
          if offset + global.size * global.count > 65536 {
            return Err(
              diagnostic(
                item.offset,
                "report_limit",
                "Report exceeds 65536 bits",
              ),
            )
          }
          let maximum = if global.logical_min < 0 {
            global.logical_max_signed
          } else {
            global.logical_max_unsigned
          }
          let representable_min = if global.logical_min < 0 {
            -(1L << (global.size - 1))
          } else {
            0L
          }
          let representable_max = if global.logical_min < 0 {
            (1L << (global.size - 1)) - 1
          } else {
            (1L << global.size) - 1
          }
          if (value & 1L) == 0 &&
            (
              maximum < global.logical_min ||
              global.logical_min < representable_min ||
              maximum > representable_max
            ) {
            return Err(
              diagnostic(
                item.offset,
                "logical_range",
                "Logical range is invalid or exceeds Report Size",
              ),
            )
          }
          fields.push({
            descriptor_offset: item.offset,
            kind,
            report_id: global.report_id,
            bit_offset: offset,
            bit_size: global.size,
            count: global.count,
            flags: value.to_int(),
            logical_min: global.logical_min,
            logical_max: maximum,
            physical_min: global.physical_min,
            physical_max: if global.physical_min is Some(minimum) && minimum < 0 {
              global.physical_max_signed
            } else {
              global.physical_max_unsigned
            },
            unit: global.unit,
            unit_exponent: global.unit_exponent,
            collection_index: collection_stack.last(),
            usages: locals.copy(),
          })
          offsets[cursor] = offset + global.size * global.count
        }
        _ =>
          return Err(
            diagnostic(item.offset, "unsupported_main", "Unknown Main item"),
          )
      }
      locals.clear() // HID local state applies only to the next Main item.
    }
  }
  if !collection_stack.is_empty() {
    return Err(
      diagnostic(bytes.length(), "collection", "Collection is not closed"),
    )
  }
  if !stack.is_empty() {
    return Err(
      diagnostic(
        bytes.length(),
        "global_stack",
        "Global Push is not balanced by Pop",
      ),
    )
  }
  if range_min is Some(_) || !locals.is_empty() {
    return Err(
      diagnostic(
        bytes.length(),
        "dangling_local",
        "Local state has no following Main item",
      ),
    )
  }
  if has_report_ids && fields.any(field => field.report_id == 0) {
    return Err(
      diagnostic(
        0, "mixed_report_ids", "Unnumbered fields cannot be mixed with numbered reports",
      ),
    )
  }
  if fields.is_empty() {
    Err(diagnostic(0, "empty_layout", "Descriptor contains no report fields"))
  } else {
    Ok({ fields, collections, has_report_ids, })
  }
}
