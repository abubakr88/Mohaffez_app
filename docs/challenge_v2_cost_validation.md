# Challenge V2 Firebase cost validation

Measured on the Firestore Emulator with 10 questions on 2026-07-28.

## Result

| Flow | Reads | Writes | Callable invocations |
|---|---:|---:|---:|
| Fixed student practice | 0 | 0 | 0 |
| Generated Quran bank browsing/suggestion | 0 | 0 | 0 |
| Legacy bank + student open + unlock listener | 21 | — | 0 |
| V2 bank + final submission | 3 | 2 | 1 |
| Generated publish + objective submission | 4 | 3 | 2 |
| Five legacy per-question toggles | — | 5 | 0 |
| V2 batched bank save | — | 1 | 0 |
| Optional oral review batch | 1 | 1 | 1 |

Measured read reduction: **85.7%**.

Publishing a session challenge normally performs three reads (session, bank,
and the open-challenge query) and two writes (public session data and private
answer key). Closing an older challenge adds one write only when one exists.

Generated Quran questions use the materialized publish path. It omits the bank
read, so publishing performs two reads (session and open-challenge query) and
two writes. Final submission adds two reads and one write, for a complete
objective flow of four reads and three writes. The custom bank is loaded lazily
only when the teacher opens its section.

## Production bundle measurement

Measured before and after the generated Quran bank on 2026-07-29:

| Artifact | Before | After | Increase |
|---|---:|---:|---:|
| Web `main.dart.js` | 6,866,009 bytes | 6,891,146 bytes | 24.5 KB raw |
| Quran per-surah assets | — | 1.292 MB raw / 0.329 MB gzip | 0.329 MB compressed |
| Web code + compressed Quran assets | — | — | **0.353 MB** |
| Production Android AAB | 63,107,119 bytes | 63,593,062 bytes | **0.463 MB** |

Both compressed measurements remain below the 0.5 MB acceptance limit.
The Quran text is split across 114 assets; Web loads only selected surahs plus
one distractor surah instead of embedding the full text in `main.dart.js`.

## Reproduce

Build the functions and run the measurement while the Firestore Emulator is
available:

```powershell
cd functions
npm run build
cd ..
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:GCLOUD_PROJECT='demo-mohaffez'
node functions/lib/scripts/measureChallengeV2Cost.js
```

The script fails if the measured reduction is below 70%.

## Cost guarantees in the implementation

- The three practice questions are app-local and never call Firebase.
- The question bank uses one document read and one explicit batched save.
- The generated Quran bank is app-local and does not read or write Firestore.
- New materialized publishes skip the student-bank document read.
- The student home derives challenge access from its existing session stream.
- Student answers remain in `SharedPreferences` until the final submit.
- Final submission is one callable with two transactional reads and one write.
- Teacher review submits all pending verdicts in one callable/read/write.
- Public session data never contains correct answers or reference answers.
