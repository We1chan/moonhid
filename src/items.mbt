///|
/// A raw short or long HID item. type_code: 0 Main, 1 Global, 2 Local, 3 reserved.
pub(all) struct Item {
  offset : Int
  type_code : Int
  tag : Int
  data : Bytes
  is_long : Bool
} derive(Debug, Eq)

///|
pub extend Item with @debug.Debug::{to_repr}

///|
pub extend Item with Eq::{equal, not_equal}

///|
/// Tokenizes at most 65536 bytes without reading beyond a truncated item.
/// Long items are preserved; their semantics are not interpreted here.
pub fn parse_items(bytes : Bytes) -> Result[Array[Item], Diagnostic] {
  if bytes.length() > 65536 {
    return Err(
      diagnostic(0, "descriptor_limit", "Descriptor exceeds 65536 bytes"),
    )
  }
  let items : Array[Item] = []
  let mut offset = 0
  while offset < bytes.length() {
    let prefix = bytes[offset].to_int()
    let is_long = prefix == 0xfe
    let header = if is_long { 3 } else { 1 }
    if bytes.length() - offset < header {
      return Err(
        diagnostic(offset, "truncated_item", "Incomplete long item header"),
      )
    }
    let size = if is_long {
      bytes[offset + 1].to_int()
    } else if (prefix & 3) == 3 {
      4
    } else {
      prefix & 3
    }
    if bytes.length() - offset - header < size {
      return Err(
        diagnostic(offset, "truncated_item", "Incomplete item payload"),
      )
    }
    items.push({
      offset,
      type_code: if is_long {
        3
      } else {
        (prefix >> 2) & 3
      },
      tag: if is_long {
        bytes[offset + 2].to_int()
      } else {
        prefix >> 4
      },
      data: bytes
      .exact_view(start=offset + header, end=offset + header + size)
      .to_owned(),
      is_long,
    })
    offset = offset + header + size
  }
  Ok(items)
}

///|
/// Serializes raw items without interpreting semantics; offsets are ignored.
/// Retains short-item payload widths and long-item bytes for lossless round trips.
pub fn serialize_items(items : Array[Item]) -> Result[Bytes, Diagnostic] {
  if items.length() > 65536 {
    return Err(diagnostic(0, "descriptor_limit", "More than 65536 items"))
  }
  let output : Array[Byte] = []
  for index = 0; index < items.length(); index = index + 1 {
    let item = items[index]
    let size = item.data.length()
    let size_code = match size {
      0 => 0
      1 => 1
      2 => 2
      4 => 3
      _ => -1
    }
    if (
        item.is_long &&
        (item.type_code != 3 || item.tag < 0 || item.tag > 255 || size > 255)
      ) ||
      (
        !item.is_long &&
        (
          item.type_code < 0 ||
          item.type_code > 3 ||
          item.tag < 0 ||
          item.tag > 15 ||
          size_code < 0
        )
      ) {
      return Err(
        diagnostic(
          index, "invalid_item", "Invalid item type, tag or payload width",
        ),
      )
    }
    let prefix = (item.tag << 4) | (item.type_code << 2) | size_code
    if !item.is_long && prefix == 0xfe {
      return Err(
        diagnostic(
          index, "invalid_item", "Short-item prefix collides with the long-item marker",
        ),
      )
    }
    let header_size = if item.is_long { 3 } else { 1 }
    if header_size + size > 65536 - output.length() {
      return Err(
        diagnostic(index, "descriptor_limit", "Descriptor exceeds 65536 bytes"),
      )
    }
    if item.is_long {
      output.push(0xfe)
      output.push(size.to_byte())
      output.push(item.tag.to_byte())
    } else {
      output.push(prefix.to_byte())
    }
    for byte in item.data {
      output.push(byte)
    }
  }
  Ok(Bytes::from_array(output))
}
