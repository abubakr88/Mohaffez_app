import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';
import {
  countsTowardTeacherRating,
  normalizeTeacherRating,
} from '../notifications/teacherRatingPolicy';

type Aggregate = {
  sum: number;
  count: number;
};

type TeacherBackup = {
  id: string;
  rating: unknown;
  reviewCount: unknown;
  ratingSum: unknown;
  ratingScale: unknown;
  ratingPolicyVersion: unknown;
};

function argumentValue(name: string): string | null {
  const prefix = `--${name}=`;
  const argument = process.argv.find((value) => value.startsWith(prefix));
  return argument?.slice(prefix.length).trim() || null;
}

function requiredArgument(name: string): string {
  const value = argumentValue(name);
  if (!value) {
    throw new Error(`Missing required argument --${name}=...`);
  }
  return value;
}

function safeFilePart(value: string): string {
  return value.replace(/[^a-zA-Z0-9_-]/g, '_');
}

async function main(): Promise<void> {
  const shouldApply = process.argv.includes('--apply');
  const projectId = requiredArgument('project');
  const serviceAccountPath =
    argumentValue('service-account') ??
    path.resolve(process.cwd(), 'serviceAccountKey.json');

  if (!fs.existsSync(serviceAccountPath)) {
    throw new Error(`Service account file not found: ${serviceAccountPath}`);
  }

  const serviceAccount = JSON.parse(
    fs.readFileSync(serviceAccountPath, 'utf8'),
  ) as admin.ServiceAccount & { project_id?: string };
  const credentialProjectId =
    serviceAccount.projectId ?? serviceAccount.project_id;
  if (credentialProjectId !== projectId) {
    throw new Error(
      `Project mismatch: requested ${projectId}, credential is for ${credentialProjectId ?? 'unknown'}`,
    );
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId,
  });
  const db = admin.firestore();

  const [teachersSnapshot, currentRatingsSnapshot] = await Promise.all([
    db.collection('users').where('role', '==', 'mohaffez').get(),
    db.collection('hafizSessions').where('teacherRatingScale', '==', 5).get(),
  ]);

  const aggregates = new Map<string, Aggregate>();
  let excludedTechnicalRatings = 0;
  let invalidCurrentRatings = 0;

  for (const sessionDoc of currentRatingsSnapshot.docs) {
    const data = sessionDoc.data() as Record<string, unknown>;
    if (!countsTowardTeacherRating(data)) {
      if (data.teacherRatingReason === 'technical_only') {
        excludedTechnicalRatings++;
      } else {
        invalidCurrentRatings++;
      }
      continue;
    }

    const teacherId =
      typeof data.mohaffezId === 'string' ? data.mohaffezId.trim() : '';
    const rating = normalizeTeacherRating(data);
    if (!teacherId || rating == null) {
      invalidCurrentRatings++;
      continue;
    }

    const aggregate = aggregates.get(teacherId) ?? { sum: 0, count: 0 };
    aggregate.sum += rating;
    aggregate.count++;
    aggregates.set(teacherId, aggregate);
  }

  const backups: TeacherBackup[] = teachersSnapshot.docs.map((teacherDoc) => {
    const data = teacherDoc.data();
    return {
      id: teacherDoc.id,
      rating: data.rating ?? null,
      reviewCount: data.reviewCount ?? null,
      ratingSum: data.ratingSum ?? null,
      ratingScale: data.ratingScale ?? null,
      ratingPolicyVersion: data.ratingPolicyVersion ?? null,
    };
  });

  const teachersWithCurrentRatings = teachersSnapshot.docs.filter(
    (teacherDoc) => (aggregates.get(teacherDoc.id)?.count ?? 0) > 0,
  ).length;

  console.log(JSON.stringify({
    mode: shouldApply ? 'apply' : 'dry-run',
    projectId,
    teachersFound: teachersSnapshot.size,
    explicitV2SessionRatings: currentRatingsSnapshot.size,
    countedV2Ratings: [...aggregates.values()].reduce(
      (total, aggregate) => total + aggregate.count,
      0,
    ),
    excludedTechnicalRatings,
    invalidCurrentRatings,
    teachersWithCurrentRatings,
    teachersResetToNew: teachersSnapshot.size - teachersWithCurrentRatings,
  }, null, 2));

  if (!shouldApply) {
    console.log(
      'Dry run only. Re-run with --apply after reviewing this summary.',
    );
    return;
  }

  const backupDirectory = path.resolve(
    process.cwd(),
    'migration_backups',
  );
  fs.mkdirSync(backupDirectory, { recursive: true });
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupPath = path.join(
    backupDirectory,
    `teacher-ratings-before-v2-${safeFilePart(projectId)}-${timestamp}.json`,
  );
  fs.writeFileSync(
    backupPath,
    JSON.stringify({
      projectId,
      createdAt: new Date().toISOString(),
      teachers: backups,
    }, null, 2),
    'utf8',
  );

  const writer = db.bulkWriter();
  for (const teacherDoc of teachersSnapshot.docs) {
    const aggregate = aggregates.get(teacherDoc.id) ?? { sum: 0, count: 0 };
    const rating = aggregate.count > 0
      ? Math.round((aggregate.sum / aggregate.count) * 10) / 10
      : 0;

    writer.update(teacherDoc.ref, {
      rating,
      reviewCount: aggregate.count,
      ratingSum: aggregate.sum,
      ratingScale: 5,
      ratingPolicyVersion: 2,
      ratingMigratedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await writer.close();

  console.log(`Migration applied. Backup written to ${backupPath}`);
}

void main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
