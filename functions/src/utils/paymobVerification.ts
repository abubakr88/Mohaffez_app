import * as crypto from 'crypto';
import * as functions from 'firebase-functions';

const PAYMOB_HMAC_SECRET = functions.config().paymob?.hmac_secret || '';

interface PaymobVerificationObject {
  amount_cents?: number;
  created_at?: string;
  currency?: string;
  error_occured?: boolean;
  has_parent_transaction?: boolean;
  id?: number;
  integration_id?: number;
  is_3d_secure?: boolean;
  is_auth?: boolean;
  is_capture?: boolean;
  is_refunded?: boolean;
  is_standalone_payment?: boolean;
  is_voided?: boolean;
  order?: { id?: number };
  owner?: number;
  pending?: boolean;
  source_data?: {
    pan?: string;
    sub_type?: string;
    type?: string;
  };
  success?: boolean;
}

export function verifyPaymobHmac(
  obj: PaymobVerificationObject,
  receivedHmac: string
): boolean {
  if (!PAYMOB_HMAC_SECRET) {
    functions.logger.error('PAYMOB_HMAC_SECRET not configured');
    return false;
  }

  const hmacString = [
    obj.amount_cents?.toString() || '',
    obj.created_at?.toString() || '',
    obj.currency?.toString() || '',
    obj.error_occured?.toString() || 'false',
    obj.has_parent_transaction?.toString() || 'false',
    obj.id?.toString() || '',
    obj.integration_id?.toString() || '',
    obj.is_3d_secure?.toString() || 'false',
    obj.is_auth?.toString() || 'false',
    obj.is_capture?.toString() || 'false',
    obj.is_refunded?.toString() || 'false',
    obj.is_standalone_payment?.toString() || 'false',
    obj.is_voided?.toString() || 'false',
    obj.order?.id?.toString() || '',
    obj.owner?.toString() || '',
    obj.pending?.toString() || 'false',
    obj.source_data?.pan?.toString() || 'NA',
    obj.source_data?.sub_type?.toString() || 'NA',
    obj.source_data?.type?.toString() || 'NA',
    obj.success?.toString() || 'false',
  ].join('');

  const calculatedHmac = crypto
    .createHmac('sha512', PAYMOB_HMAC_SECRET)
    .update(hmacString)
    .digest('hex');

  return calculatedHmac === receivedHmac;
}