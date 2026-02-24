import * as functions from 'firebase-functions';

import { db } from '../utils/admin';

function parseVersion(version: string): number[] {
  return version
    .split('.')
    .map((p) => parseInt(p, 10))
    .map((n) => (Number.isFinite(n) ? n : 0));
}

function compareVersions(a: string, b: string): number {
  const av = parseVersion(a);
  const bv = parseVersion(b);
  const len = av.length > bv.length ? av.length : bv.length;

  for (let i = 0; i < len; i += 1) {
    const ai = av[i] ?? 0;
    const bi = bv[i] ?? 0;
    if (ai > bi) return 1;
    if (ai < bi) return -1;
  }

  return 0;
}

/**
 * input: { currentVersion: string }
 * output: { status: 'ok' } | { status: 'recommended', version: string } | { status: 'required', version: string }
 */
export const checkAppVersion = functions.https.onCall(async (data) => {
  const currentVersion = (data?.currentVersion as string | undefined)?.trim() ?? '0.0.0';
  const doc = await db.collection('systemConfig').doc('global').get();
  const cfg = doc.data() ?? {};

  const forceUpdateVersion = (cfg.forceUpdateVersion as string | undefined) ?? '1.0.0';
  const recommendedUpdateVersion = (cfg.recommendedUpdateVersion as string | undefined) ?? '1.0.0';

  if (compareVersions(currentVersion, forceUpdateVersion) < 0) {
    return { status: 'required', version: forceUpdateVersion };
  }

  if (compareVersions(currentVersion, recommendedUpdateVersion) < 0) {
    return { status: 'recommended', version: recommendedUpdateVersion };
  }

  return { status: 'ok' };
});
