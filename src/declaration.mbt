///|
let declaration_tags : Array[(String, Int, Int)] = [
  ("usage_page", 1, 0),
  ("logical_minimum", 1, 1),
  ("logical_maximum", 1, 2),
  ("physical_minimum", 1, 3),
  ("physical_maximum", 1, 4),
  ("unit_exponent", 1, 5),
  ("unit", 1, 6),
  ("report_size", 1, 7),
  ("report_id", 1, 8),
  ("report_count", 1, 9),
  ("push", 1, 10),
  ("pop", 1, 11),
  ("usage", 2, 0),
  ("usage_minimum", 2, 1),
  ("usage_maximum", 2, 2),
  ("designator_index", 2, 3),
  ("designator_minimum", 2, 4),
  ("designator_maximum", 2, 5),
  ("string_index", 2, 7),
  ("string_minimum", 2, 8),
  ("string_maximum", 2, 9),
  ("delimiter", 2, 10),
  ("input", 0, 8),
  ("output", 0, 9),
  ("collection", 0, 10),
  ("feature", 0, 11),
]

///|
priv struct DeclarationContext {
  builder : DescriptorBuilder
  sources : Array[(Int, Int, String)]
  saved : Array[(Int64, Int64)]
  mut logical_min : Int64
  mut physical_min : Int64
  mut count : Int
  mut active : Int
  mut error : Diagnostic?
}

///|
fn DeclarationContext::reject(
  self : DeclarationContext,
  path : String,
  message : String,
  code? : String = "declaration_value",
) -> Unit {
  if self.error is None {
    self.error = Some(diagnostic(self.active, code, "\{path}: \{message}"))
  }
}

///|
fn DeclarationContext::object(
  self : DeclarationContext,
  value : Json,
  path : String,
) -> Map[String, Json] {
  match value {
    Object(object) => object
    _ => {
      self.reject(path, "Expected an object")
      Map([])
    }
  }
}

///|
fn DeclarationContext::array(
  self : DeclarationContext,
  value : Json,
  path : String,
) -> Array[Json] {
  match value {
    Array(items) => items
    _ => {
      self.reject(path, "Expected an array")
      []
    }
  }
}

///|
fn DeclarationContext::number(
  self : DeclarationContext,
  value : Json,
  path : String,
) -> Int64 {
  let integer = match value {
    Number(number, ..) if !number.is_nan() &&
      !number.is_inf() &&
      number >= -2147483648.0 &&
      number <= 4294967295.0 &&
      number.to_int64().to_double() == number => number.to_int64()
    String(text) if text.has_prefix("0x") || text.has_prefix("-0x") =>
      @string.parse_int64(text, base=16) catch {
        _ => {
          self.reject(path, "Invalid hexadecimal integer")
          return 0L
        }
      }
    _ => {
      self.reject(path, "Expected a 32-bit integer or 0x string")
      return 0L
    }
  }
  if integer < -2147483648L || integer > 4294967295L {
    self.reject(path, "Integer exceeds the signed/unsigned 32-bit domain")
  }
  integer
}

///|
fn DeclarationContext::flags(
  self : DeclarationContext,
  value : Json,
  path : String,
) -> Int64 {
  guard value is Array(names) else { return self.number(value, path) }
  let tokens : Array[(String, Int, Bool)] = [
    ("data", 1, false),
    ("constant", 1, true),
    ("array", 2, false),
    ("variable", 2, true),
    ("absolute", 4, false),
    ("relative", 4, true),
    ("no_wrap", 8, false),
    ("wrap", 8, true),
    ("linear", 16, false),
    ("non_linear", 16, true),
    ("preferred_state", 32, false),
    ("no_preferred_state", 32, true),
    ("no_null_state", 64, false),
    ("null_state", 64, true),
    ("non_volatile", 128, false),
    ("volatile", 128, true),
    ("bit_field", 256, false),
    ("buffered_bytes", 256, true),
  ]
  let seen : Map[Int, Bool] = Map([])
  let mut flags = 0
  for index, name in names {
    let entry_path = "\{path}[\{index}]"
    let token = match name {
      String(text) => tokens.iter().find_first(entry => entry.0 == text)
      _ => None
    }
    match token {
      Some((_, bit, enabled)) => {
        if seen.get(bit) is Some(previous) && previous != enabled {
          self.reject(entry_path, "Conflicting flag names")
        }
        seen.set(bit, enabled)
        if enabled {
          flags = flags | bit
        }
      }
      None => self.reject(entry_path, "Unknown Main flag name")
    }
  }
  flags.to_int64()
}

///|
fn DeclarationContext::emit(
  self : DeclarationContext,
  type_code : Int,
  tag : Int,
  value : Int64,
  size : Int?,
  path : String,
) -> Unit {
  if self.error is Some(_) {
    return
  }
  self.sources.push((self.builder.length, self.active, path))
  let empty = (type_code == 1 && (tag == 10 || tag == 11)) ||
    (type_code == 0 && tag == 12)
  if size is Some(width) {
    let valid = if width == 0 {
      value == 0L
    } else {
      integer_fits(value, width * 8, value < 0L)
    }
    if !valid {
      self.reject(path, "Value does not fit the requested raw item size")
      return
    }
    self.builder.append(
      type_code,
      tag,
      Bytes::makei(width, i => ((value >> (8 * i)) & 255L).to_byte()),
    )
    |> ignore
  } else if empty {
    self.builder.append(type_code, tag, b"") |> ignore
  } else if type_code == 1 && (tag == 2 || tag == 4) {
    self.builder.maximum_item(
      tag,
      if tag == 2 {
        self.logical_min
      } else {
        self.physical_min
      },
      value,
    )
    |> ignore
  } else if type_code == 1 && tag == 5 {
    self.builder.unit_exponent(value.to_int()) |> ignore
  } else {
    self.builder.short_item(
      type_code,
      tag,
      value,
      signed=type_code == 1 && (tag == 1 || tag == 3),
    )
    |> ignore
  }
  if self.builder.error is Some(error) {
    self.reject(
      path,
      "\{error.code}: \{error.message}",
      code=if error.code == "descriptor_limit" {
        "declaration_limit"
      } else {
        "declaration_value"
      },
    )
    return
  }
  if type_code == 1 {
    if tag == 1 || tag == 3 {
      let item = self.builder.items[self.builder.items.length() - 1]
      if tag == 1 {
        self.logical_min = item_signed(item)
      } else {
        self.physical_min = item_signed(item)
      }
    } else if tag == 10 {
      if self.saved.length() >= 64 {
        self.reject(path, "Global stack exceeds 64", code="declaration_limit")
      } else {
        self.saved.push((self.logical_min, self.physical_min))
      }
    } else if tag == 11 {
      match self.saved.pop() {
        Some((logical, physical)) => {
          self.logical_min = logical
          self.physical_min = physical
        }
        None => self.reject(path, "global_stack: Pop without Push")
      }
    }
  }
}

///|
fn DeclarationContext::visit(
  self : DeclarationContext,
  items : Array[Json],
  path : String,
  depth : Int,
) -> Unit {
  for position, entry in items {
    if self.error is Some(_) {
      return
    }
    let index = self.count
    self.active = index
    self.count += 1
    let node_path = "\{path}[\{position}]"
    if self.count > 65536 {
      self.reject(
        node_path,
        "More than 65536 declaration items",
        code="declaration_limit",
      )
      return
    }
    let object = self.object(entry, node_path)
    let mut name = ""
    let mut value = Json::null()
    for key, item in object {
      if key == "size" || key == "items" {
        continue
      }
      if name != "" ||
        (
          !declaration_tags.any(tag => tag.0 == key) &&
          key != "logical_range" &&
          key != "usage_range"
        ) {
        self.reject(
          "\{node_path}.\{key}",
          "Expected exactly one supported item key",
          code="declaration_key",
        )
        return
      }
      name = key
      value = item
    }
    if name == "" {
      self.reject(node_path, "Missing item key", code="declaration_key")
      return
    }
    let size = match object.get("size") {
      None => None
      Some(value) => {
        let width = self.number(value, "\{node_path}.size")
        if width != 0L && width != 1L && width != 2L && width != 4L {
          self.reject("\{node_path}.size", "Size must be 0, 1, 2 or 4")
          return
        }
        Some(width.to_int())
      }
    }
    let item_path = "\{node_path}.\{name}"
    if name != "collection" && object.contains("items") {
      self.reject(
        "\{node_path}.items",
        "Only Collection has child items",
        code="declaration_key",
      )
      return
    }
    if name == "logical_range" || name == "usage_range" {
      let range = self.array(value, item_path)
      if range.length() != 2 {
        self.reject(item_path, "Range needs two endpoints")
        return
      }
      let low = self.number(range[0], "\{item_path}[0]")
      let high = self.number(range[1], "\{item_path}[1]")
      if low > high {
        self.reject(item_path, "Range endpoints are reversed")
        return
      }
      let type_code = if name == "logical_range" { 1 } else { 2 }
      if type_code == 2 && (low < 0L || high > 65535L) {
        self.reject(item_path, "Usage range endpoints must fit 16 bits")
        return
      }
      self.emit(type_code, 1, low, size, "\{item_path}[0]")
      self.emit(type_code, 2, high, size, "\{item_path}[1]")
      continue
    }
    let (type_code, tag) = match
      declaration_tags.iter().find_first(tag => tag.0 == name) {
      Some((_, type_code, tag)) => (type_code, tag)
      None => {
        self.reject(item_path, "Unknown item", code="declaration_key")
        return
      }
    }
    let mut actual_size = size
    let number = if name == "push" || name == "pop" {
      if value != Json(true) {
        self.reject(item_path, "Push/Pop value must be true")
      }
      0L
    } else if type_code == 0 && (tag == 8 || tag == 9 || tag == 11) {
      self.flags(value, item_path)
    } else if name == "usage" && value is Object(_) {
      let usage = self.object(value, item_path)
      for key, _ in usage {
        if key != "page" && key != "id" {
          self.reject(
            "\{item_path}.\{key}",
            "Unknown extended Usage key",
            code="declaration_key",
          )
        }
      }
      let page = self.number(
        usage.get("page").unwrap_or(Json::null()),
        "\{item_path}.page",
      )
      let id = self.number(
        usage.get("id").unwrap_or(Json::null()),
        "\{item_path}.id",
      )
      if page < 0L ||
        page > 65535L ||
        id < 0L ||
        id > 65535L ||
        (size is Some(width) && width != 4) {
        self.reject(item_path, "Extended Usage needs 16-bit page/id and size 4")
      }
      actual_size = Some(4)
      (page << 16) | id
    } else if name == "collection" {
      let names = [
        "physical", "application", "logical", "report", "named_array", "usage_switch",
        "usage_modifier",
      ]
      match value {
        String(text) if names.contains(text) =>
          names.search(text).unwrap().to_int64()
        _ => self.number(value, item_path)
      }
    } else {
      let number = self.number(value, item_path)
      if type_code == 2 &&
        tag <= 2 &&
        size is None &&
        (number < 0L || number > 65535L) {
        self.reject(
          item_path, "Plain Usage IDs must fit 16 bits; use extended Usage or explicit raw size",
        )
      }
      number
    }
    self.emit(type_code, tag, number, actual_size, item_path)
    if name == "collection" {
      if depth >= 64 {
        self.reject(
          item_path,
          "Collection depth exceeds 64",
          code="declaration_limit",
        )
        return
      }
      let children = self.array(
        object.get("items").unwrap_or(Json::null()),
        "\{node_path}.items",
      )
      self.visit(children, "\{node_path}.items", depth + 1)
      self.active = index
      self.emit(0, 12, 0L, None, item_path)
    }
  }
}

///|
/// Compiles declaration schema v1, validates with the existing builder/compiler.
/// Errors use zero-based preorder declaration item indices and JSON paths.
pub fn descriptor_from_declaration(text : String) -> Result[Bytes, Diagnostic] {
  if text.length() > 8388608 {
    return Err(
      diagnostic(
        0, "declaration_limit", "$: Declaration text exceeds 8388608 UTF-16 code units",
      ),
    )
  }
  let json = @json.parse(text) catch {
    _ =>
      return Err(
        diagnostic(
          0, "declaration_json", "$: Invalid JSON or JSON nesting limit exceeded",
        ),
      )
  }
  let context : DeclarationContext = {
    builder: DescriptorBuilder::new(),
    sources: [],
    saved: [],
    logical_min: 0L,
    physical_min: 0L,
    count: 0,
    active: 0,
    error: None,
  }
  let object = context.object(json, "$")
  for key, _ in object {
    if key != "version" && key != "items" {
      context.reject("$.\{key}", "Unknown document key", code="declaration_key")
    }
  }
  match object.get("version") {
    Some(Number(version, ..)) if version == 1.0 => ()
    _ => context.reject("$.version", "Declaration version must be the number 1")
  }
  let items = context.array(
    object.get("items").unwrap_or(Json::null()),
    "$.items",
  )
  context.visit(items, "$.items", 0)
  if context.error is Some(error) {
    return Err(error)
  }
  match context.builder.build() {
    Ok(bytes) => Ok(bytes)
    Err(error) => {
      let mut index = 0
      let mut path = "$.items"
      for (offset, source_index, source_path) in context.sources {
        if offset <= error.offset {
          index = source_index
          path = source_path
        }
      }
      Err(
        diagnostic(
          index,
          "declaration_value",
          "\{path}: \{error.code}: \{error.message}",
        ),
      )
    }
  }
}

///|
/// Exports supported descriptor bytes with explicit raw widths for exact replay.
/// The declaration schema is independent from display JSON schema v2.
pub fn declaration_from_descriptor(bytes : Bytes) -> Result[Json, Diagnostic] {
  match compile_descriptor(bytes) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let items = match parse_items(bytes) {
    Ok(items) => items
    Err(error) => return Err(error)
  }
  let root : Array[Json] = []
  let stack : Array[Array[Json]] = [root]
  for item in items {
    if item.type_code == 0 && item.tag == 12 {
      stack.pop() |> ignore
      continue
    }
    let name = match
      declaration_tags
      .iter()
      .find_first(entry => entry.1 == item.type_code && entry.2 == item.tag) {
      Some((name, _, _)) => name
      None =>
        return Err(
          diagnostic(
            item.offset,
            "unsupported_item",
            "Item has no declaration representation",
          ),
        )
    }
    let object : Map[String, Json] = Map([])
    object.set(
      name,
      if name == "push" || name == "pop" {
        Json(true)
      } else {
        number64(item_unsigned(item))
      },
    )
    object.set("size", Json(item.data.length()))
    let current = stack[stack.length() - 1]
    if name == "collection" {
      let children : Array[Json] = []
      object.set("items", Json::array(children))
      current.push(Json::object(object))
      stack.push(children)
    } else {
      current.push(Json::object(object))
    }
  }
  Ok({ "version": 1, "items": Json::array(root) })
}
