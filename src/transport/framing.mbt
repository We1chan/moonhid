///|
/// WebHID carries Report ID separately from the payload.
pub(all) struct WebFrame {
  report_id : Int
  payload : Bytes
} derive(Eq, @debug.Debug)

///|
pub extend WebFrame with Eq::{equal, not_equal}

///|
pub extend WebFrame with @debug.Debug::{to_repr}

///|
fn checked(
  layout : @hid.Layout,
  kind : @hid.ReportKind,
  wire : Bytes,
) -> Result[Int, @hid.Diagnostic] {
  match @hid.decode_report(layout, kind, wire) {
    Ok(report) => Ok(report.report_id)
    Err(error) => Err(error)
  }
}

///|
pub fn to_webhid(
  layout : @hid.Layout,
  kind : @hid.ReportKind,
  wire : Bytes,
) -> Result[WebFrame, @hid.Diagnostic] {
  let id = match checked(layout, kind, wire) {
    Ok(id) => id
    Err(error) => return Err(error)
  }
  Ok({
    report_id: id,
    payload: if layout.has_report_ids {
      wire[1:].to_owned()
    } else {
      wire
    },
  })
}

///|
pub fn from_webhid(
  layout : @hid.Layout,
  kind : @hid.ReportKind,
  frame : WebFrame,
) -> Result[Bytes, @hid.Diagnostic] {
  if frame.report_id < 0 ||
    frame.report_id > 255 ||
    (!layout.has_report_ids && frame.report_id != 0) {
    return Err({
      offset: 0,
      code: "transport_id",
      message: "WebHID Report ID must match the layout framing",
    })
  }
  let wire = if layout.has_report_ids {
    Bytes::make(1, frame.report_id.to_byte()) + frame.payload
  } else {
    frame.payload
  }
  match checked(layout, kind, wire) {
    Ok(_) => Ok(wire)
    Err(error) => Err(error)
  }
}

///|
/// HIDAPI Input reads already use core wire framing; Output/Feature buffers
/// always include a Report ID byte (zero for an unnumbered report).
pub fn to_hidapi(
  layout : @hid.Layout,
  kind : @hid.ReportKind,
  wire : Bytes,
) -> Result[Bytes, @hid.Diagnostic] {
  match checked(layout, kind, wire) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  Ok(
    if !layout.has_report_ids && kind != @hid.Input {
      b"\x00" + wire
    } else {
      wire
    },
  )
}

///|
pub fn from_hidapi(
  layout : @hid.Layout,
  kind : @hid.ReportKind,
  buffer : Bytes,
) -> Result[Bytes, @hid.Diagnostic] {
  let wire = if !layout.has_report_ids && kind != @hid.Input {
    if buffer.is_empty() || buffer[0] != b'\x00' {
      return Err({
        offset: 0,
        code: "transport_id",
        message: "Unnumbered HIDAPI Output/Feature needs a zero ID prefix",
      })
    }
    buffer[1:].to_owned()
  } else {
    buffer
  }
  match checked(layout, kind, wire) {
    Ok(_) => Ok(wire)
    Err(error) => Err(error)
  }
}
