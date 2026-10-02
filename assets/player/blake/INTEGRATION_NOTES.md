# Blake and medieval sword

`blake_player.tscn` is the non-destructive player visual used by `demo/demo_player.gd`.
The original GLBs are byte-identical copies of the supplied Downloads assets.

The character has 78 imported bones, seven skinned mesh parts and 18 clips.
Its exported skin shares inverse bind matrices across meshes with incompatible
coordinate spaces, causing severe stretching in a direct Godot import. The visual
script creates corrected instance meshes and skins, preserving triangle geometry,
UVs, materials, bone names, animation tracks and vertex weights. The main body is
normalized from its centimeter coordinates; four small facial meshes are fitted
around the rig's mouth and eyes. Two facial surfaces have corrected winding, and
tangents are regenerated. These small facial fits are approximate, not an offline
re-export of the original model. The source gun and magazine are hidden.

The existing downloaded Modular Character Controller ActionPlayer/ActionNode
scripts dispatch presentation requests only. No addon files or project plugin
settings are changed, and the gameplay controller is preserved. The addon documents
support through Godot 4.6.1; its used action scripts were tested in this project's
Godot 4.7.2 runtime.

The sword uses its original material and texture. BoneAttachment3D follows
`hand_R_028`; a grip offset aligns its handle and scales the complete sword to 60%.
Idle, run, hand_attack and dead are the supplied clips used during gameplay.
There is no dedicated sword slash/grip clip: hand_attack is a generic unarmed
attack adapted visually by holding the sword. The original instantaneous radial
Space damage, range, cooldown, stats and inheritance calculations are unchanged.

Godot MCP checks: normal attack 120 -> 100 enemy HP, upgraded attack 120 -> 98;
movement 3 units in 0.5 seconds at speed 6; right-hand attachment positional error
0 during idle/attack/run; imported animation playback and visual death; fresh
launch; mesh validator clean for 10 surfaces; no new editor errors after cursor 41.
Close-up camera and fill light used for screenshots were runtime-only.
