// Tests for Paymob iframe redirect URL parsing.
//
// Covers checklist A2: the WebView intercepts Paymob's redirect and must
// correctly distinguish ?success=true from ?success=false.
//
// Critical: the OLD implementation used `url.contains('success')` which
// matched BOTH success=true AND success=false, falsely treating failed
// payments as succeeded. These tests guard against any regression.
//
// Run: flutter test test/services/paymob_callback_parser_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_finder_app/services/paymob_callback_parser.dart';

void main() {
  group('Paymob callback parsing — success vs failure', () {
    test('?success=true → success', () {
      final r = parsePaymobCallback(
        'https://mohafezy.com/payment/return?success=true&id=123',
      );
      expect(r, PaymobCallbackResult.success);
    });

    test('?success=false → failure (the regression we are guarding against)', () {
      // This is the critical case. The OLD substring matcher would have
      // returned `success` here because the URL CONTAINS the word "success".
      // The new parser correctly returns `failure`.
      final r = parsePaymobCallback(
        'https://mohafezy.com/payment/return?success=false&id=123',
      );
      expect(r, PaymobCallbackResult.failure);
    });

    test('?success=TRUE (uppercase) → success (case-insensitive)', () {
      final r = parsePaymobCallback(
        'https://mohafezy.com/payment/return?success=TRUE',
      );
      expect(r, PaymobCallbackResult.success);
    });

    test('?success=False (mixed case) → failure', () {
      final r = parsePaymobCallback(
        'https://mohafezy.com/payment/return?success=False',
      );
      expect(r, PaymobCallbackResult.failure);
    });
  });

  group('Paymob callback parsing — non-callback URLs', () {
    test('iframe load URL (no success param) → unknown', () {
      final r = parsePaymobCallback('https://accept.paymob.com/api/acceptance/iframes/123');
      expect(r, PaymobCallbackResult.unknown);
    });

    test('Random URL → unknown', () {
      final r = parsePaymobCallback('https://google.com');
      expect(r, PaymobCallbackResult.unknown);
    });

    test('Malformed URL → unknown (defensive, never throws)', () {
      final r = parsePaymobCallback('not a real url at all');
      expect(r, PaymobCallbackResult.unknown);
    });

    test('Empty string → unknown', () {
      final r = parsePaymobCallback('');
      expect(r, PaymobCallbackResult.unknown);
    });
  });

  group('Paymob callback parsing — edge cases that broke the old matcher', () {
    test('?success=false with many other params → failure', () {
      final r = parsePaymobCallback(
        'https://mohafezy.com/payment/return'
        '?success=false&id=999&pending=false&order=123&amount_cents=10000',
      );
      expect(r, PaymobCallbackResult.failure);
    });

    test('URL with literal "success" in path but no query param → unknown', () {
      // Old `contains('success')` would have matched this. New parser does not.
      final r = parsePaymobCallback('https://example.com/payment/success-page');
      expect(r, PaymobCallbackResult.unknown);
    });

    test('?success= (empty value) → unknown, not success', () {
      final r = parsePaymobCallback('https://mohafezy.com/payment/return?success=');
      expect(r, PaymobCallbackResult.unknown);
    });

    test('?success=yes (non-boolean value) → unknown, not success', () {
      final r = parsePaymobCallback('https://mohafezy.com/payment/return?success=yes');
      expect(r, PaymobCallbackResult.unknown);
    });
  });
}
