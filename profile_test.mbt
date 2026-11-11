///|
test "repeated shape has zero distance and separated neighbour" {
  let p = @moonmatrixprofile.matrix_profile(
    [0.0, 1.0, 0.0, -1.0, 0.0, 1.0, 0.0, -1.0],
    4,
  ).unwrap()
  assert_true(p.distances[0].unwrap() < 1.0e-8)
  assert_eq(p.indices[0], Some(4))
  assert_eq(@moonmatrixprofile.motifs(p, 1).unwrap().length(), 1)
}

///|
test "AB join is directional and permits identical windows" {
  let p = @moonmatrixprofile.ab_join(
    [1.0, 3.0, 2.0],
    [9.0, 1.0, 3.0, 2.0, 8.0],
    3,
  ).unwrap()
  assert_eq(p.distances.length(), 1)
  assert_true(p.distances[0].unwrap() < 1.0e-8)
  assert_eq(p.indices[0], Some(1))
  assert_true(@moonmatrixprofile.motifs(p, 1) is Err(_))
}

///|
test "all excluded is None distinct from invalid" {
  let p = @moonmatrixprofile.matrix_profile([1.0, 2.0, 3.0], 3).unwrap()
  assert_eq(p.indices[0], None)
  assert_eq(p.distances[0], None)
  assert_eq(p.valid[0], true)
}

///|
test "constant semantics" {
  let d = @moonmatrixprofile.distance_profile([2.0, 2.0, 2.0], [
    9.0, 9.0, 9.0, 1.0, 3.0,
  ]).unwrap()
  assert_eq(d[0], Some(0.0))
  assert_true((d[1].unwrap() - 3.0.sqrt()).abs() < 1.0e-10)
}

///|
test "invalid windows cannot contaminate other distances" {
  let d = @moonmatrixprofile.distance_profile([0.0, 1.0, 0.0], [
    @double.not_a_number, 0.0, 1.0, 0.0,
  ]).unwrap()
  assert_eq(d[0], None)
  assert_true(d[1].unwrap() < 1.0e-8)
}

///|
test "bad requests fail before work" {
  assert_true(@moonmatrixprofile.matrix_profile([], 3) is Err(_))
  assert_true(@moonmatrixprofile.matrix_profile([1.0, 2.0, 3.0], 2) is Err(_))
  assert_true(
    @moonmatrixprofile.matrix_profile([1.0, 2.0, 3.0], 3, exclusion_zone=-1)
    is Err(_),
  )
  assert_true(
    @moonmatrixprofile.matrix_profile([1.0, 2.0, 3.0, 4.0], 3, max_pairs=1)
    is Err(_),
  )
}
