///|
test "CSV quoted headers CRLF escaped quotes and multiline fields" {
  let values = @moonmatrixprofile.parse_csv(
    "\"label\",\"signal\"\r\n\"line\nwith\"\"quote\",1.5\r\nx,2e1\r\nx,\r\n", "signal",
  ).unwrap()
  assert_eq(values.length(), 3)
  assert_eq(values[0], 1.5)
  assert_eq(values[1], 20.0)
  assert_true(values[2] != values[2])
}

///|
test "CSV refuses ambiguous malformed records" {
  assert_true(@moonmatrixprofile.parse_csv("x,x\n1,2", "x") is Err(_))
  assert_true(@moonmatrixprofile.parse_csv("x,y\n1", "x") is Err(_))
  assert_true(@moonmatrixprofile.parse_csv("x\n\"1\"oops", "x") is Err(_))
  assert_true(@moonmatrixprofile.parse_csv("x\n\"1", "x") is Err(_))
  assert_true(@moonmatrixprofile.parse_csv("x\nhello", "x") is Err(_))
  assert_true(@moonmatrixprofile.parse_csv("x\n1e999", "x") is Err(_))
}

///|
test "JSON uses numeric scalars and null not Option enum encoding" {
  let wire = @moonmatrixprofile.analyze_json(
    "{\"series\":[1,2,3],\"window\":3}",
  )
  assert_true(wire.contains("\"distances\":[null]"))
  assert_true(wire.contains("\"indices\":[null]"))
  assert_true(@moonmatrixprofile.analyze_json("{").contains("E_JSON"))
  assert_true(
    @moonmatrixprofile.analyze_json("{\"series\":[1,true,3]}").contains(
      "E_INPUT",
    ),
  )
}
