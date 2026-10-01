///|
/// Extracts 1..32 bits, least significant bit first, including unaligned fields.
/// signed=true interprets the result as two's complement.
pub fn extract_bits(
  bytes : Bytes,
  bit_offset : Int,
  bit_size : Int,
  signed? : Bool = false,
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
  bit_offset : Int,
  bit_size : Int,
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
