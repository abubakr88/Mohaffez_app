// Pure helper: given a session doc + an optional lookup callback for the
// linked sessionRequest, decide whether the session belongs to a bundle and
// resolve its subscription id. Extracted from the cancellation trigger so it
// can be unit-tested without Firestore.

export interface BundleDetectionInput {
  subscriptionId?: string | null;
  paymentType?: string | null;
  paymentMethod?: string | null;
  requestId?: string | null;
}

export interface BundleDetectionResult {
  isBundle: boolean;
  subscriptionId: string | null;
}

/**
 * Resolution order:
 *   1. session.subscriptionId (most reliable — stamped on new bundle sessions)
 *   2. paymentType === 'bundle' or paymentMethod === 'subscription' signals
 *      → if present, lookup linked sessionRequest for its subscriptionId
 *   3. Else: not a bundle.
 *
 * Returns isBundle=true with subscriptionId=null when the signal indicates a
 * bundle but no id can be resolved — caller should alert admin and skip the
 * standard refund path (it would charge the teacher unfairly).
 */
export async function detectBundleContext(
  session: BundleDetectionInput,
  lookupRequest?: (requestId: string) => Promise<{ subscriptionId?: string | null } | null>,
): Promise<BundleDetectionResult> {
  const directSubId = session.subscriptionId ?? null;
  if (directSubId) {
    return { isBundle: true, subscriptionId: directSubId };
  }
  const looksLikeBundle =
    session.paymentType === 'bundle' || session.paymentMethod === 'subscription';
  if (!looksLikeBundle) {
    return { isBundle: false, subscriptionId: null };
  }
  if (session.requestId && lookupRequest) {
    try {
      const req = await lookupRequest(session.requestId);
      if (req?.subscriptionId) {
        return { isBundle: true, subscriptionId: req.subscriptionId };
      }
    } catch (_err) { /* fall through */ }
  }
  return { isBundle: true, subscriptionId: null };
}
