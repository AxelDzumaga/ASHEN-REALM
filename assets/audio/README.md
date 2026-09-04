# Ashen Realm audio placeholders

Stage 10 uses original procedural PCM effects generated at runtime by
`res://scripts/audio/audio_manager.gd`. No downloaded or copyrighted audio is
included.

The generated sounds are temporary references for UI click, dice, attacks,
healing, upgrades, equipment, loot, combat entry, boss entry, victory and
defeat. Future production audio can replace the generated `AudioStreamWAV`
entries inside `AudioManager` while preserving the public `Sfx` identifiers and
all gameplay call sites.

The project buses are `Master`, `Music` and `SFX`. There is no music asset yet.

Stage 51 keeps those provisional streams and adds a semantic event layer in
`AudioManager`. Logical callers emit events such as contact, critical, guard,
Boss phase and loot; the manager owns priority, short dedupe windows and a
small deterministic pitch cycle. No global random source or external asset is
used.

Music states (`LOBBY`, `BOARD`, `COMBAT`, `BOSS`, `RESULTS`) are accepted even
without tracks and degrade to silence. Production streams can be registered in
the central state map later without adding paths to scene scripts.
