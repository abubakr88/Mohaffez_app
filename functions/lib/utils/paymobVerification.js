"use strict";
var _a;
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyPaymobHmac = verifyPaymobHmac;
const crypto = require("crypto");
const functions = require("firebase-functions");
const PAYMOB_HMAC_SECRET = ((_a = functions.config().paymob) === null || _a === void 0 ? void 0 : _a.hmac_secret) || '';
function verifyPaymobHmac(obj, receivedHmac) {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s, _t, _u, _v, _w, _x, _y, _z;
    if (!PAYMOB_HMAC_SECRET) {
        functions.logger.error('PAYMOB_HMAC_SECRET not configured');
        return false;
    }
    const hmacString = [
        ((_a = obj.amount_cents) === null || _a === void 0 ? void 0 : _a.toString()) || '',
        ((_b = obj.created_at) === null || _b === void 0 ? void 0 : _b.toString()) || '',
        ((_c = obj.currency) === null || _c === void 0 ? void 0 : _c.toString()) || '',
        ((_d = obj.error_occured) === null || _d === void 0 ? void 0 : _d.toString()) || 'false',
        ((_e = obj.has_parent_transaction) === null || _e === void 0 ? void 0 : _e.toString()) || 'false',
        ((_f = obj.id) === null || _f === void 0 ? void 0 : _f.toString()) || '',
        ((_g = obj.integration_id) === null || _g === void 0 ? void 0 : _g.toString()) || '',
        ((_h = obj.is_3d_secure) === null || _h === void 0 ? void 0 : _h.toString()) || 'false',
        ((_j = obj.is_auth) === null || _j === void 0 ? void 0 : _j.toString()) || 'false',
        ((_k = obj.is_capture) === null || _k === void 0 ? void 0 : _k.toString()) || 'false',
        ((_l = obj.is_refunded) === null || _l === void 0 ? void 0 : _l.toString()) || 'false',
        ((_m = obj.is_standalone_payment) === null || _m === void 0 ? void 0 : _m.toString()) || 'false',
        ((_o = obj.is_voided) === null || _o === void 0 ? void 0 : _o.toString()) || 'false',
        ((_q = (_p = obj.order) === null || _p === void 0 ? void 0 : _p.id) === null || _q === void 0 ? void 0 : _q.toString()) || '',
        ((_r = obj.owner) === null || _r === void 0 ? void 0 : _r.toString()) || '',
        ((_s = obj.pending) === null || _s === void 0 ? void 0 : _s.toString()) || 'false',
        ((_u = (_t = obj.source_data) === null || _t === void 0 ? void 0 : _t.pan) === null || _u === void 0 ? void 0 : _u.toString()) || 'NA',
        ((_w = (_v = obj.source_data) === null || _v === void 0 ? void 0 : _v.sub_type) === null || _w === void 0 ? void 0 : _w.toString()) || 'NA',
        ((_y = (_x = obj.source_data) === null || _x === void 0 ? void 0 : _x.type) === null || _y === void 0 ? void 0 : _y.toString()) || 'NA',
        ((_z = obj.success) === null || _z === void 0 ? void 0 : _z.toString()) || 'false',
    ].join('');
    const calculatedHmac = crypto
        .createHmac('sha512', PAYMOB_HMAC_SECRET)
        .update(hmacString)
        .digest('hex');
    return calculatedHmac === receivedHmac;
}
//# sourceMappingURL=paymobVerification.js.map