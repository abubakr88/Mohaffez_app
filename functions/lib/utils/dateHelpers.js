"use strict";
// WHY: Centralize ISO-week date helpers to avoid copy-paste drift between
// directPayment.ts, confirmFreeSession.ts, and confirmSubscriptionSession.ts.
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseFlutterDate = parseFlutterDate;
exports.getWeekNumber = getWeekNumber;
exports.getWeekStart = getWeekStart;
exports.getWeekEnd = getWeekEnd;
exports.getNextMonday = getNextMonday;
/**
 * FIX (Bug 6): Parse Flutter ISO strings without timezone as UTC to prevent
 * server-local shift. new Date("2026-03-08T10:00:00") is interpreted as LOCAL
 * time on Node.js, which shifts the stored Timestamp by the server's UTC offset.
 * Centralised here so directPayment.ts, confirmFreeSession.ts, and
 * confirmSubscriptionSession.ts all share one canonical implementation.
 */
function parseFlutterDate(iso) {
    // If the string already carries a timezone indicator, parse as-is
    if (iso.endsWith("Z") || /[+-]\d{2}:\d{2}$/.test(iso)) {
        return new Date(iso);
    }
    // No timezone → treat as UTC by appending Z
    return new Date(iso + "Z");
}
function getWeekNumber(date) {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    const dayNum = d.getUTCDay() || 7;
    d.setUTCDate(d.getUTCDate() + 4 - dayNum);
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return Math.ceil(((d.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
}
function getWeekStart(date) {
    const d = new Date(date);
    const day = d.getDay();
    d.setDate(d.getDate() - (day === 0 ? -6 : 1));
    d.setHours(0, 0, 0, 0);
    return d;
}
function getWeekEnd(date) {
    const ws = getWeekStart(date);
    ws.setDate(ws.getDate() + 6);
    ws.setHours(23, 59, 59, 999);
    return ws;
}
function getNextMonday(date) {
    // FIX BUG-NEW-1
    const d = new Date(date);
    const day = d.getDay(); // 0=Sun … 6=Sat
    const daysToMonday = day === 0 ? 1 : (8 - day) % 7 || 7;
    d.setDate(d.getDate() + daysToMonday);
    d.setHours(12, 0, 0, 0);
    return d;
}
//# sourceMappingURL=dateHelpers.js.map