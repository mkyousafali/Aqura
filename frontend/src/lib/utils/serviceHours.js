// Service schedules use Saudi local time, independent of the customer's timezone.
export function isServiceAvailable(branch, serviceType, now = new Date()) {
  if (!['delivery', 'pickup'].includes(serviceType)) return false;
  if (!branch[`${serviceType}_service_enabled`]) return false;
  if (branch[`${serviceType}_is_24_hours`] === true) return true;

  const parseTime = (value) => {
    const match = /^(\d{2}):(\d{2})(?::\d{2})?$/.exec(value || '');
    if (!match || Number(match[1]) > 23 || Number(match[2]) > 59) return null;
    return Number(match[1]) * 60 + Number(match[2]);
  };
  const start = parseTime(branch[`${serviceType}_start_time`]);
  const end = parseTime(branch[`${serviceType}_end_time`]);
  if (start === null || end === null || start === end) return false;

  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Riyadh', hour: '2-digit', minute: '2-digit', hourCycle: 'h23'
  }).formatToParts(now);
  const current = Number(parts.find((part) => part.type === 'hour').value) * 60
    + Number(parts.find((part) => part.type === 'minute').value);
  return start < end
    ? current >= start && current < end
    : current >= start || current < end;
}
