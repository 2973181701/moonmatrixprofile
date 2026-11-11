///|
// RFC 4180-style records: quoted commas/newlines, escaped quotes and CRLF.
fn csv_rows(text : String) -> Result[Array[Array[String]], ProfileError] {
  if text.length() > 8000000 {
    return Err(problem("E_LIMIT", "CSV exceeds 8 million UTF-16 code units"))
  }
  let rows : Array[Array[String]] = []
  let mut row : Array[String] = []
  let field : Array[Char] = []
  let mut quoted = false
  let mut closed = false
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if quoted {
      if ch == '"' {
        if i + 1 < chars.length() && chars[i + 1] == '"' {
          field.push('"')
          i = i + 1
        } else {
          quoted = false
          closed = true
        }
      } else {
        field.push(ch)
      }
    } else if ch == ',' || ch == '\n' || ch == '\r' {
      row.push(String::from_array(field))
      field.clear()
      closed = false
      if row.length() > 256 {
        return Err(problem("E_CSV", "CSV has more than 256 columns"))
      }
      if ch != ',' {
        rows.push(row)
        row = []
        if rows.length() > 100001 {
          return Err(problem("E_LIMIT", "CSV exceeds 100000 data rows"))
        }
        if ch == '\r' && i + 1 < chars.length() && chars[i + 1] == '\n' {
          i = i + 1
        }
      }
    } else if closed {
      return Err(problem("E_CSV", "unexpected text after closing quote"))
    } else if ch == '"' {
      if field.length() != 0 {
        return Err(problem("E_CSV", "quote inside unquoted field"))
      }
      quoted = true
    } else {
      field.push(ch)
    }
    i = i + 1
  }
  if quoted {
    return Err(problem("E_CSV", "unterminated quoted field"))
  }
  if field.length() > 0 || row.length() > 0 || closed {
    row.push(String::from_array(field))
    rows.push(row)
    if row.length() > 256 {
      return Err(problem("E_CSV", "CSV has more than 256 columns"))
    }
    if rows.length() > 100001 {
      return Err(problem("E_LIMIT", "CSV exceeds 100000 data rows"))
    }
  }
  Ok(rows)
}

///|
/// Read a named CSV column. The first record is a header. Empty/NA/NaN/null
/// cells are missing samples; wholly empty records are skipped. No interpolation.
pub fn parse_csv(
  text : String,
  column : String,
) -> Result[Array[Double], ProfileError] {
  let rows = match csv_rows(text) {
    Err(e) => return Err(e)
    Ok(r) => r
  }
  if rows.length() == 0 {
    return Err(problem("E_CSV", "CSV is empty"))
  }
  let mut selected = -1
  for i, header in rows[0] {
    let name = header.trim().to_owned()
    if name == column || (i == 0 && name == "\u{feff}" + column) {
      if selected >= 0 {
        return Err(problem("E_CSV", "selected column is duplicated"))
      }
      selected = i
    }
  }
  if selected < 0 {
    return Err(problem("E_CSV", "selected column was not found"))
  }
  let values : Array[Double] = []
  for i = 1; i < rows.length(); i = i + 1 {
    let row = rows[i]
    if row.length() == 1 && row[0].trim().length() == 0 {
      continue
    }
    if row.length() != rows[0].length() {
      return Err(problem("E_CSV", "row \{i + 1} has a different column count"))
    }
    let cell = row[selected].trim().to_owned()
    if cell == "" || cell == "NA" || cell == "NaN" || cell == "null" {
      values.push(@double.not_a_number)
    } else {
      let parsed = @json.parse(cell) catch {
        _ =>
          return Err(
            problem(
              "E_CSV",
              "row \{i + 1} is not a number in the selected column",
            ),
          )
      }
      guard parsed is Number(value, ..) else {
        return Err(problem("E_CSV", "row \{i + 1} is not a JSON-format number"))
      }
      if !finite(value) {
        return Err(problem("E_CSV", "row \{i + 1} has an infinite value"))
      }
      values.push(value)
    }
  }
  Ok(values)
}
