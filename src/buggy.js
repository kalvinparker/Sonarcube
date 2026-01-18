// Deliberate issues for Sonar demo

function unused(a, b) {
  // unused variables and no return
}

function complex(n) {
  if (n == 0) return 1;
  if (n == 1) return 1;
  let result = 1;
  for (let i = 0; i < n; i++) {
    if (i % 2 === 0) result += i;
    else result -= i;
    if (i === 10) {
      // deep nesting
      for (let j = 0; j < 5; j++) {
        result += j;
      }
    }
  }
  return result;
}

module.exports = { unused, complex }
