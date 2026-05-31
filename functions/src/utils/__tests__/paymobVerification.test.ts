// Tests for Paymob webhook HMAC verification.
//
// Covers checklist A2: webhook signature integrity + replay safety.
// Run: npm test

import { describe, it, expect } from 'vitest';
import * as crypto from 'crypto';
import {
  buildPaymobHmacString,
  verifyPaymobHmacWithSecret,
} from '../paymobVerification';

const TEST_SECRET = 'test_hmac_secret_do_not_use_in_prod';

// A realistic successful-payment callback object (sample from Paymob docs).
const SUCCESS_TXN = {
  amount_cents: 10000,
  created_at: '2026-05-23T10:00:00Z',
  currency: 'EGP',
  error_occured: false,
  has_parent_transaction: false,
  id: 123456,
  integration_id: 99999,
  is_3d_secure: true,
  is_auth: false,
  is_capture: false,
  is_refunded: false,
  is_standalone_payment: true,
  is_voided: false,
  order: { id: 78901 },
  owner: 555,
  pending: false,
  source_data: { pan: '2346', sub_type: 'MasterCard', type: 'card' },
  success: true,
};

function signWith(obj: typeof SUCCESS_TXN, secret: string): string {
  return crypto
    .createHmac('sha512', secret)
    .update(buildPaymobHmacString(obj))
    .digest('hex');
}

describe('Paymob HMAC — valid signatures pass', () => {
  it('correctly signed successful payment → valid', () => {
    const sig = signWith(SUCCESS_TXN, TEST_SECRET);
    expect(verifyPaymobHmacWithSecret(SUCCESS_TXN, sig, TEST_SECRET)).toBe(true);
  });

  it('correctly signed failed payment → valid (signature passes; success flag is data)', () => {
    const failTxn = { ...SUCCESS_TXN, success: false };
    const sig = signWith(failTxn, TEST_SECRET);
    expect(verifyPaymobHmacWithSecret(failTxn, sig, TEST_SECRET)).toBe(true);
  });
});

describe('Paymob HMAC — tampered payloads fail', () => {
  it('amount tampered → invalid (attacker tries to change payment value)', () => {
    const sig = signWith(SUCCESS_TXN, TEST_SECRET);
    const tampered = { ...SUCCESS_TXN, amount_cents: 1 }; // attacker reduces amount
    expect(verifyPaymobHmacWithSecret(tampered, sig, TEST_SECRET)).toBe(false);
  });

  it('success flag flipped false→true → invalid (most critical attack)', () => {
    // An attacker intercepts a failed payment and flips success to true
    const failTxn = { ...SUCCESS_TXN, success: false };
    const sig = signWith(failTxn, TEST_SECRET);
    const tampered = { ...failTxn, success: true };
    expect(verifyPaymobHmacWithSecret(tampered, sig, TEST_SECRET)).toBe(false);
  });

  it('order id swapped → invalid (attacker tries to attribute payment to another order)', () => {
    const sig = signWith(SUCCESS_TXN, TEST_SECRET);
    const tampered = { ...SUCCESS_TXN, order: { id: 99999 } };
    expect(verifyPaymobHmacWithSecret(tampered, sig, TEST_SECRET)).toBe(false);
  });

  it('transaction id changed → invalid', () => {
    const sig = signWith(SUCCESS_TXN, TEST_SECRET);
    const tampered = { ...SUCCESS_TXN, id: 999999999 };
    expect(verifyPaymobHmacWithSecret(tampered, sig, TEST_SECRET)).toBe(false);
  });

  it('currency changed EGP→USD → invalid', () => {
    const sig = signWith(SUCCESS_TXN, TEST_SECRET);
    const tampered = { ...SUCCESS_TXN, currency: 'USD' };
    expect(verifyPaymobHmacWithSecret(tampered, sig, TEST_SECRET)).toBe(false);
  });
});

describe('Paymob HMAC — wrong secret fails', () => {
  it('signature from a different secret → invalid', () => {
    const attackerSig = signWith(SUCCESS_TXN, 'wrong_secret');
    expect(verifyPaymobHmacWithSecret(SUCCESS_TXN, attackerSig, TEST_SECRET)).toBe(false);
  });

  it('empty secret → invalid (refuse to verify against blank)', () => {
    const anySig = signWith(SUCCESS_TXN, TEST_SECRET);
    expect(verifyPaymobHmacWithSecret(SUCCESS_TXN, anySig, '')).toBe(false);
  });
});

describe('Paymob HMAC — malformed signatures fail', () => {
  it('empty signature → invalid', () => {
    expect(verifyPaymobHmacWithSecret(SUCCESS_TXN, '', TEST_SECRET)).toBe(false);
  });

  it('garbage hex → invalid', () => {
    expect(verifyPaymobHmacWithSecret(SUCCESS_TXN, 'not_a_real_hmac', TEST_SECRET)).toBe(false);
  });

  it('truncated signature → invalid', () => {
    const sig = signWith(SUCCESS_TXN, TEST_SECRET);
    expect(verifyPaymobHmacWithSecret(SUCCESS_TXN, sig.slice(0, 64), TEST_SECRET)).toBe(false);
  });
});

describe('Paymob HMAC string — field order and defaults', () => {
  // Critical: Paymob's documented order. If anyone reorders these fields,
  // verification will silently fail for ALL real webhooks.

  it('field order matches Paymob spec', () => {
    const minimal: Parameters<typeof buildPaymobHmacString>[0] = {
      amount_cents: 100,
      created_at: 'X',
      currency: 'EGP',
      id: 1,
      integration_id: 2,
      order: { id: 3 },
      owner: 4,
      source_data: { pan: '1234', sub_type: 'V', type: 'card' },
      success: true,
    };
    // Expected concatenation per Paymob's documented order
    const expected = '100' + 'X' + 'EGP'
      + 'false' + 'false'                // error_occured, has_parent_transaction
      + '1' + '2'                        // id, integration_id
      + 'false' + 'false' + 'false'      // is_3d_secure, is_auth, is_capture
      + 'false' + 'false' + 'false'      // is_refunded, is_standalone_payment, is_voided
      + '3' + '4' + 'false'              // order.id, owner, pending
      + '1234' + 'V' + 'card'            // source_data.pan/sub_type/type
      + 'true';                          // success
    expect(buildPaymobHmacString(minimal)).toBe(expected);
  });

  it('missing source_data → defaults to NA / NA / NA', () => {
    const obj = { amount_cents: 100, success: false };
    const str = buildPaymobHmacString(obj);
    expect(str).toContain('NANANA'); // three NA defaults concatenated
  });

  it('missing booleans default to "false" (not empty string)', () => {
    const obj = { amount_cents: 100 };
    const str = buildPaymobHmacString(obj);
    // 10 boolean fields default to 'false':
    // error_occured, has_parent_transaction, is_3d_secure, is_auth, is_capture,
    // is_refunded, is_standalone_payment, is_voided, pending, success.
    expect((str.match(/false/g) || []).length).toBe(10);
  });
});
