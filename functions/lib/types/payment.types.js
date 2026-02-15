"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.serverTimestamp = void 0;
const admin_1 = require("../utils/admin");
const serverTimestamp = () => admin_1.default.firestore.FieldValue.serverTimestamp();
exports.serverTimestamp = serverTimestamp;
//# sourceMappingURL=payment.types.js.map