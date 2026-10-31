import { describe, expect, it } from 'vitest';
import { isServiceAvailable } from './serviceHours.js';

const branch = {
  pickup_service_enabled: true, pickup_is_24_hours: false,
  pickup_start_time: '06:00:00', pickup_end_time: '02:00:00'
};

describe('Saudi service hours', () => {
  it('opens at 6 AM and closes at 2 AM the following day in Saudi time', () => {
    expect(isServiceAvailable(branch, 'pickup', new Date('2026-10-31T02:59:00Z'))).toBe(false);
    expect(isServiceAvailable(branch, 'pickup', new Date('2026-10-31T03:00:00Z'))).toBe(true);
    expect(isServiceAvailable(branch, 'pickup', new Date('2026-10-31T10:59:00Z'))).toBe(true);
    expect(isServiceAvailable(branch, 'pickup', new Date('2026-10-31T11:00:00Z'))).toBe(true);
    expect(isServiceAvailable(branch, 'pickup', new Date('2026-10-31T22:59:00Z'))).toBe(true);
    expect(isServiceAvailable(branch, 'pickup', new Date('2026-10-31T23:00:00Z'))).toBe(false);
  });

  it('does not offer disabled, missing or invalid schedules', () => {
    expect(isServiceAvailable({ ...branch, pickup_service_enabled: false }, 'pickup')).toBe(false);
    expect(isServiceAvailable({ ...branch, pickup_start_time: null }, 'pickup')).toBe(false);
    expect(isServiceAvailable({ ...branch, pickup_end_time: '25:00' }, 'pickup')).toBe(false);
    expect(isServiceAvailable({ ...branch, pickup_end_time: '06:00' }, 'pickup')).toBe(false);
  });

  it('keeps explicit 24-hour and overnight service schedules working', () => {
    expect(isServiceAvailable({ ...branch, pickup_is_24_hours: true }, 'pickup')).toBe(true);
    const overnight = { ...branch, pickup_start_time: '20:00', pickup_end_time: '02:00' };
    expect(isServiceAvailable(overnight, 'pickup', new Date('2026-10-31T22:00:00Z'))).toBe(true);
    expect(isServiceAvailable(overnight, 'pickup', new Date('2026-10-31T23:00:00Z'))).toBe(false);
  });
});
