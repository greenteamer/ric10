// Numeric helpers missing from the standard library

let isInteger = (n: float): bool => Float.isFinite(n) && Math.floor(n) == n
