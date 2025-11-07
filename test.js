const { add } = require('./index');

if (add(1,2) !== 3) {
  console.error('add() failed');
  process.exit(1);
}
console.log('ok');
