///|
/// Extracts 1..32 bits, least significant bit first, including unaligned fields.
/// signed=true interprets the result as two's complement.
pub fn extract_bits(
  bytes : Bytes,
  bit_offset : Int32,
  bit_size : Int32,
  signed~ : Bool = false,
) -> Result[Int64, Diagnostic] {
  if bit_offset < 0 || bit_size < 1 || bit_size > 32 {
    return Err(
      diagnostic(0, "bit_range", "Offset must be nonnegative and width 1..32"),
    )
  }
  let start_byte = bit_offset / 8
  let start_bit = bit_offset % 8
  let end_byte = start_byte + (start_bit + bit_size + 7) / 8
  if end_byte > bytes.length() {
    return Err(
      diagnostic(
        start_byte, "short_report", "Report does not contain the requested bits",
      ),
    )
  }
  let mut value : Int64 = 0
  for i = 0; i < bit_size; i = i + 1 {
    let position = start_bit + i
    let bit = (bytes[start_byte + position / 8].to_int() >> (position % 8)) & 1
    value = value | (bit.to_int64() << i)
  }
  if signed && (value & (1L << (bit_size - 1))) != 0 {
    Ok(value - (1L << bit_size))
  } else {
    Ok(value)
  }
}

///|
/// Copies 1..65536 payload bits into LSB-first bytes; trailing high bits are zero.
pub fn extract_bytes(
  bytes : Bytes,
  bit_offset : Int32,
  bit_size : Int32,
) -> Result[Bytes, Diagnostic] {
  if bit_offset < 0 || bit_size < 1 || bit_size > 65536 {
    return Err(
      diagnostic(
        0, "bit_range", "Offset must be nonnegative and width 1..65536",
      ),
    )
  }
  let start_byte = bit_offset / 8
  let start_bit = bit_offset % 8
  let needed = (start_bit + bit_size + 7) / 8
  if start_byte > bytes.length() || needed > bytes.length() - start_byte {
    return Err(
      diagnostic(
        start_byte, "short_report", "Report does not contain the requested bits",
      ),
    )
  }
  let packed : FixedArray[Byte] = FixedArray::make((bit_size + 7) / 8, 0)
  for i = 0; i < bit_size; i = i + 1 {
    let source = start_bit + i
    let bit = (bytes[start_byte + source / 8].to_int() >> (source % 8)) & 1
    packed[i / 8] = (packed[i / 8].to_int() | (bit << (i % 8))).to_byte()
  }
  Ok(Bytes::from_array(packed.exact_view()))
}

///|
/// Replaces 1..32 bits in a copy, preserving every other bit. Never truncates.
pub fn insert_bits(
  bytes : Bytes,
  bit_offset : Int32,
  bit_size : Int32,
  value : Int64,
  signed~ : Bool = false,
) -> Result[Bytes, Diagnostic] {
  if bit_offset < 0 || bit_size < 1 || bit_size > 32 {
    return Err(
      diagnostic(0, "bit_range", "Offset must be nonnegative and width 1..32"),
    )
  }
  let start = bit_offset / 8
  let needed = (bit_offset % 8 + bit_size + 7) / 8
  if start > bytes.length() || needed > bytes.length() - start {
    return Err(
      diagnostic(
        start, "short_report", "Report does not contain the requested bits",
      ),
    )
  }
  if !integer_fits(value, bit_size, signed) {
    return Err(
      diagnostic(
        start, "value_range", "Value does not fit the requested width and signedness",
      ),
    )
  }
  let target = FixedArray::makei(bytes.length(), i => bytes[i])
  put_integer(target, bit_offset, bit_size, value)
  Ok(Bytes::from_array(target.exact_view()))
}

///|
/// Replaces packed LSB-first bits in a copy. Raw trailing high bits must be zero.
pub fn insert_bytes(
  bytes : Bytes,
  bit_offset : Int32,
  bit_size : Int32,
  value : Bytes,
) -> Result[Bytes, Diagnostic] {
  if bit_offset < 0 || bit_size < 1 || bit_size > 65536 {
    return Err(
      diagnostic(
        0, "bit_range", "Offset must be nonnegative and width 1..65536",
      ),
    )
  }
  let start = bit_offset / 8
  let needed = (bit_offset % 8 + bit_size + 7) / 8
  if start > bytes.length() || needed > bytes.length() - start {
    return Err(
      diagnostic(
        start, "short_report", "Report does not contain the requested bits",
      ),
    )
  }
  if !raw_fits(value, bit_size) {
    return Err(
      diagnostic(
        start, "value_range", "Raw bytes must match the width with zero trailing high bits",
      ),
    )
  }
  let target = FixedArray::makei(bytes.length(), i => bytes[i])
  put_raw(target, bit_offset, bit_size, value)
  Ok(Bytes::from_array(target.exact_view()))
}
