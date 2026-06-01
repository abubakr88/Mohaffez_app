# Sound effects

`SoundService` ([lib/services/sound_service.dart](../../lib/services/sound_service.dart))
plays these files for reward/quiz feedback. **Drop the real audio files here with
the exact names below.** Until they're added, playback fails silently (the app
still works, just without sound).

Use short, royalty-free clips (≈0.3–1.5s, mono, 44.1 kHz). `.mp3` is preferred
(`audioplayers` supports `.mp3`, `.wav`, `.ogg`).

| File | When it plays | Suggested feel |
|---|---|---|
| `clap.mp3` | Correct answer / achievement-style win | short crowd clap / cheer |
| `try_again.mp3` | Wrong answer | gentle, non-punishing "boop" |
| `tap.mp3` | Selecting a game / option | soft UI click |
| `level_up.mp3` | Student level / XP tier up | rising sparkle/fanfare |
| `badge.mp3` | New achievement unlocked | bright chime |
| `complete.mp3` | Quiz session finished | celebratory flourish |

Good free sources: mixkit.co, freesound.org, pixabay.com/sound-effects.

> The folder is declared in `pubspec.yaml` under `assets:` as `assets/sounds/`,
> so any file placed here is bundled automatically — no per-file pubspec edits.
