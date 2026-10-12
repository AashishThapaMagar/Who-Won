# Voice Studio

On character select, open **VOICE STUDIO** beneath either player's lock-in
button. Choose a slot, press **RECORD TAKE**, and speak. Recording ends at
the slot's limit, or press **STOP & SAVE** to finish early. Escape or Done
cancels an unfinished recording. Music is muted while recording.

Slots include:

- Each selected fighter's individual moves, using their actual move names.
- Taking a hit and landing a hit (unblocked contact only).
- Super, round victory and round defeat.
- General battle cries, preserving recordings from the earlier system.

Use the **RECORD CALL** shortcut in the studio to start recording a manual challenge
(up to 2.5 seconds). During a live fight, click the player's **CALL ENEMY**
button or press **T** for P1 / **U** for P2 in local versus. It plays the
assigned recording with a three-second cooldown. Calls wait during round
intros, replays, pauses and the move guide, and cannot interrupt a super or
result line. The button stays disabled until a callout is recorded.

Moves are assigned to both the player and the fighter, so a recording for
Agasthya's Flash jab does not play for another fighter's jab. Reactions, supers
and results belong to the player and can be reused with other fighters.
CPU-controlled fighters can also use the player-two voice pack.

Each slot holds up to eight takes. Playback varies the takes without
immediate repeats. Choose a take to preview its waveform and audio. **UNDO
LAST** removes only that slot's newest take. Full slots require removing a
take before recording another; older recordings are never silently evicted.

New takes have leading/trailing silence removed, short fades to prevent
clicks, and bounded volume normalization. Silent or very short takes are
rejected. Hit reactions are limited to 0.9 seconds, move lines to 1.6,
supers to 2.5, and victory/defeat to 3 seconds. This is not noise removal;
a quiet room and a nearby microphone give better results.

The input meter and timer run during recording. In-game playback has a
cooldown and avoids interrupting an existing combat line; supers and
results can replace one. Music dips while voices play. The studio has a
per-player volume slider and in-game voice toggle; voices also follow the
game's Sound Effects and Master Volume settings.

Recordings and voice preferences persist under `user://battle_cries/`.
Original general recordings retain their filenames. Specific slots use
separate files; removing a take in one slot leaves other slots untouched.

Validation uses synthetic audio, without opening the microphone:

```powershell
godot --headless --path . -s res://tests/voice_pack_test.gd
godot --headless --path . -s res://tests/voice_gameplay_test.gd
```
