import { describe, expect, it } from "vitest";
import { getDeviceLoginRoute, getMobileRouteGuardTarget, isMobileDevice } from "./deviceRouting";

const desktop = { userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64)", viewportWidth: 1440, coarsePointer: false };
const phone = { userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", viewportWidth: 390, coarsePointer: true };

describe("device routing", () => {
  it("detects mobile user agents and responsive mobile widths", () => {
    expect(isMobileDevice(phone)).toBe(true);
    expect(isMobileDevice({ ...desktop, viewportWidth: 600 })).toBe(true);
    expect(isMobileDevice(desktop)).toBe(false);
  });

  it("keeps an unauthenticated mobile-interface refresh in mobile login", () => {
    expect(getDeviceLoginRoute("/mobile-interface/tasks", phone)).toBe("/mobile-interface/login");
  });

  it("blocks direct desktop login and desktop routes on mobile", () => {
    expect(getMobileRouteGuardTarget("/login/employee", false, phone)).toBe("/login");
    expect(getMobileRouteGuardTarget("/desktop-interface", false, phone)).toBe("/login");
    expect(getMobileRouteGuardTarget("/desktop-interface", true, phone)).toBe("/mobile-interface");
  });

  it("preserves desktop routing on desktop devices", () => {
    expect(getDeviceLoginRoute("/desktop-interface", desktop)).toBe("/login/employee?mode=desktop");
    expect(getMobileRouteGuardTarget("/desktop-interface", true, desktop)).toBeNull();
  });
});
