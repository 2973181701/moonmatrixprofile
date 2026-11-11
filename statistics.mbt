///|
// Condition each series before dot products. Invalid values become zero only
// for recurrence arithmetic; every window containing them remains invalid.
fn prepare(input : Array[Double], m : Int32) -> Result[Prepared, ProfileError] {
  let mut anchor = 0.0
  for x in input {
    if finite(x) {
      anchor = x
      break
    }
  }
  let mut scale = 0.0
  let mut direct = true
  for x in input {
    if finite(x) {
      let delta = x - anchor
      if !finite(delta) {
        direct = false
      }
      if finite(delta) {
        scale = scale.max(delta.abs())
      }
    }
  }
  if !direct {
    scale = 0.0
    for x in input {
      if finite(x) {
        scale = scale.max(x.abs())
      }
    }
  }
  if scale == 0.0 {
    scale = 1.0
  }
  let values = input.map(fn(x) {
    if !finite(x) {
      0.0
    } else if direct {
      (x - anchor) / scale
    } else {
      x / scale - anchor / scale
    }
  })
  let count = input.length() - m + 1
  let means = Array::make(count, 0.0)
  let sigmas = Array::make(count, 0.0)
  let valid = Array::make(count, true)
  let constant = Array::make(count, true)
  for i = 0; i < count; i = i + 1 {
    let mut mean = 0.0
    let mut variance = 0.0
    for k = 0; k < m; k = k + 1 {
      if !finite(input[i + k]) {
        valid[i] = false
      }
      if input[i + k] != input[i] {
        constant[i] = false
      }
      let delta = values[i + k] - mean
      mean = mean + delta / (k + 1).to_double()
      variance = variance + delta * (values[i + k] - mean)
    }
    means[i] = mean
    sigmas[i] = (variance.max(0.0) / m.to_double()).sqrt()
    if valid[i] && !constant[i] && sigmas[i] == 0.0 {
      return Err(
        problem(
          "E_RANGE", "dynamic range collapses a nonconstant window; split or rescale input",
        ),
      )
    }
  }
  Ok({ values, means, sigmas, valid, constant, })
}

///|
fn dot(
  a : Array[Double],
  i : Int32,
  b : Array[Double],
  j : Int32,
  m : Int32,
) -> Double {
  let mut sum = 0.0
  let mut correction = 0.0
  for k = 0; k < m; k = k + 1 {
    let term = a[i + k] * b[j + k] - correction
    let next = sum + term
    correction = next - sum - term
    sum = next
  }
  sum
}

///|
fn direct_distance(
  a : Prepared,
  i : Int32,
  b : Prepared,
  j : Int32,
  m : Int32,
) -> Double {
  if a.constant[i] && b.constant[j] {
    return 0.0
  }
  if a.constant[i] || b.constant[j] {
    return m.to_double().sqrt()
  }
  let mut sum = 0.0
  for k = 0; k < m; k = k + 1 {
    let za = (a.values[i + k] - a.means[i]) / a.sigmas[i]
    let zb = (b.values[j + k] - b.means[j]) / b.sigmas[j]
    let delta = za - zb
    sum = sum + delta * delta
  }
  sum.sqrt()
}

///|
fn distance(
  a : Prepared,
  i : Int32,
  b : Prepared,
  j : Int32,
  m : Int32,
  product : Double,
) -> Double {
  if a.constant[i] && b.constant[j] {
    return 0.0
  }
  if a.constant[i] || b.constant[j] {
    return m.to_double().sqrt()
  }
  let covariance = product / m.to_double() - a.means[i] * b.means[j]
  let rho = covariance / a.sigmas[i] / b.sigmas[j]
  let square = 2.0 * m.to_double() * (1.0 - rho)
  // Re-centre poorly conditioned/near-identical pairs instead of subtracting
  // nearly equal numbers. The fallback has an explicit O(window) cost.
  if !finite(square) ||
    square < 1.0e-7 * m.to_double() ||
    a.sigmas[i] < 1.0e-6 ||
    b.sigmas[j] < 1.0e-6 {
    direct_distance(a, i, b, j, m)
  } else {
    square.max(0.0).sqrt()
  }
}
