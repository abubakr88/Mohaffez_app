// Parser for Paymob iframe redirect URLs intercepted by the WebView.
//
// Paymob's "Transaction Response Callback URL" is hit with query params
// like `?success=true&id=12345&...` (or `success=false`). The WebView
// catches this URL before it loads and uses the parsed result to show
// the right UI to the user.
//
// IMPORTANT: this is for UI only. The authoritative payment state always
// comes from the backend webhook → Firestore. Never debit/credit based
// on the URL alone — it is client-side and trivially spoofable.

enum PaymobCallbackResult {
  success,
  failure,
  unknown,
}

/// Parses a redirect URL Paymob sends after the iframe finishes.
/// Returns the outcome based on the `success` query parameter.
///
/// Examples:
///   https://mohafezy.com/payment/return?success=true&id=123  → success
///   https://mohafezy.com/payment/return?success=false&id=123 → failure
///   https://accept.paymob.com/...                            → unknown
PaymobCallbackResult parsePaymobCallback(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return PaymobCallbackResult.unknown;
  final success = uri.queryParameters['success']?.toLowerCase();
  if (success == 'true') return PaymobCallbackResult.success;
  if (success == 'false') return PaymobCallbackResult.failure;
  return PaymobCallbackResult.unknown;
}
