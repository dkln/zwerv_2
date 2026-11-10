"""The style profiles of the music (one module per style, docs/MUZIEK.md "Stijlprofielen").

A profile holds what makes a style: tempo, key and mode, the chord plans per section (as Roman
numerals, so a new key is one line), the motif, the instrument patches (FM, PSG, DAC drums),
the drum kit, and per piece its variations (PIECES). style.py loads the active one
(ACTIVE_STYLE there, or the environment variable ZWERVR_MUZIEK_STIJL) and every piece reads
its parameters from it; the composing (the arrangement, the melodies) stays per piece.

A new style: copy synthwave_rpg.py to stijlen/<name>.py, change it, set ACTIVE_STYLE, render
(tools/megadrive/render.sh). The skill .claude/skills/muziek-prompt/SKILL.md describes how a
pasted Suno/Udio/Gemini description becomes a profile.
"""
