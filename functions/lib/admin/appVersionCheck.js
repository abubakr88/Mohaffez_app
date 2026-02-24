"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkAppVersion = void 0;
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
function parseVersion(version) {
    return version
        .split('.')
        .map((p) => parseInt(p, 10))
        .map((n) => (Number.isFinite(n) ? n : 0));
}
function compareVersions(a, b) {
    var _a, _b;
    const av = parseVersion(a);
    const bv = parseVersion(b);
    const len = av.length > bv.length ? av.length : bv.length;
    for (let i = 0; i < len; i += 1) {
        const ai = (_a = av[i]) !== null && _a !== void 0 ? _a : 0;
        const bi = (_b = bv[i]) !== null && _b !== void 0 ? _b : 0;
        if (ai > bi)
            return 1;
        if (ai < bi)
            return -1;
    }
    return 0;
}
/**
 * input: { currentVersion: string }
 * output: { status: 'ok' } | { status: 'recommended', version: string } | { status: 'required', version: string }
 */
exports.checkAppVersion = functions.https.onCall(async (data) => {
    var _a, _b, _c, _d, _e;
    const currentVersion = (_b = (_a = data === null || data === void 0 ? void 0 : data.currentVersion) === null || _a === void 0 ? void 0 : _a.trim()) !== null && _b !== void 0 ? _b : '0.0.0';
    const doc = await admin_1.db.collection('systemConfig').doc('global').get();
    const cfg = (_c = doc.data()) !== null && _c !== void 0 ? _c : {};
    const forceUpdateVersion = (_d = cfg.forceUpdateVersion) !== null && _d !== void 0 ? _d : '1.0.0';
    const recommendedUpdateVersion = (_e = cfg.recommendedUpdateVersion) !== null && _e !== void 0 ? _e : '1.0.0';
    if (compareVersions(currentVersion, forceUpdateVersion) < 0) {
        return { status: 'required', version: forceUpdateVersion };
    }
    if (compareVersions(currentVersion, recommendedUpdateVersion) < 0) {
        return { status: 'recommended', version: recommendedUpdateVersion };
    }
    return { status: 'ok' };
});
//# sourceMappingURL=appVersionCheck.js.map