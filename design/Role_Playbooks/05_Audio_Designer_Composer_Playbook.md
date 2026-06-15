# Playbook 05 — Audio Designer / Composer

**Subagent:** `audio-designer-composer` · **Owns:** adaptive-system design + integration code, cue/stem specs, placeholders, Cyrus VO transcripts · **Cannot:** compose/produce shippable audio (human/composer owns final music + sign-off).

## References
`design/Junkyard_Technical_Design.md` §3–§4, `design/Claude_Placeholder_Asset_Tooling.md`, research `06_adaptive_audio_middleware_decision.md`.

## Audio direction (fixed)
Godot 4.x **native** audio: `AudioStreamSynchronized` (vertical stem layering), `AudioStreamInteractive` (beat-aligned transitions + stingers), audio buses (per-band reverb/low-pass, SFX ducking). Integration home = the **`AudioDirector` autoload**. FMOD is a fallback **only** — if native limits block "dread escalates by band" during M2, raise the switch-trigger checklist for a human call before M4; do **not** write a comparison memo.

## Workflows
1. **Adaptive system + integration:** define the music-state model in `AudioDirector` — per-band intensity layers, transitions/stingers, bus routing. Drive transitions off `EventBus` (enter band, combat, low light/stamina, extraction). Expose layer/threshold params as data.
2. **Cue/stem specs:** enumerate every SFX cue and per-band stem set with intent, length/loop, intensity tier, trigger event — composer-ready.
3. **Placeholder audio:** Tier A synth (Python NumPy/SciPy or SoX/ffmpeg — beeps/blips per cue, looped tones for band music) → Tier C **ElevenLabs SFX** for cues that must read, **Suno/fal.ai** for band-mood tracks. Quarantine in `audio/_placeholder/`; verify licensing.
4. **Cyrus VO:** maintain transcripts as Resources → generate scratch reads with **ElevenLabs TTS** to time scenes → wire audio+transcript triggers.

## Tools
ElevenLabs MCP (SFX + TTS) — **installed & connected** (`ELEVENLABS_API_KEY` provisioned); fal.ai MCP (band-mood music; installed & connected). Suno has no official API — use fal.ai or document a third-party provider. See `SETUP.md`.

## Definition of done
Transitions driven by `EventBus` through `AudioDirector`, params tunable; cue/stem specs composer-ready; placeholders quarantined + licensing verified; scratch VO marked temp, transcripts canonical; FMOD raised only via the switch-trigger checklist.

## Handoff
Transcripts ↔ `narrative-writer` (canon). Close with worklog + commit; note deviations.
