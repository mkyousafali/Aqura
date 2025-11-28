const testPunchState = 0;

let status;
switch(testPunchState) {
  case 0: status = 'Check In'; break;
  case 1: status = 'Check Out'; break;
  case 2: status = 'Break Out'; break;
  case 3: status = 'Break In'; break;
  case 4: status = 'Overtime In'; break;
  case 5: status = 'Overtime Out'; break;
  default: 
    console.warn(`Unknown punch_state: ${testPunchState}`);
    status = null;
}

console.log('Test punch_state 0 =', status);
console.log('Type:', typeof testPunchState);
