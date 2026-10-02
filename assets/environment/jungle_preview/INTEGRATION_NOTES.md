# Imported jungle arena

Source: `jungle_environment.glb`, unchanged SHA256
`02E8C7A99D1F896AA7E7B8177E7995EBAA8F1D3C3B3C1D3EFD5B75545520F5DD`.
Inspected in Godot 4.7.2 through MCP before integration: 85 meshes, 43,693
vertices, six material families (ground, plants, statues, temple, vines, water),
original albedo/normal/PBR textures, valid normals and no collision bodies.
Native bounds: position (-1817.748, 198.1925, -501.4975), size
(1937.113, 978.1188, 1429.324). Imported orientation is upright Y-up.

The reusable `jungle_environment_instance.tscn` instances the source at scale
0.024, position (20.380598, -8.500843, -5.115948), rotation zero. Its script only
changes instance presentation resources. It flattens the imported ground while
retaining original UVs and material, discards cliff/underside triangles and gives
overlapping terrain layers slight depth separation to prevent flicker. Ground X/Z
are widened by 1.5 independently of the decorations; final visual ground bounds
are approximately 69.497 x 0.034 x 51.159, at Y -0.049 to -0.015.

The existing 30 x 0.5 x 26 BoxShape3D at Y -0.25 remains the only arena floor
collision, with its top at Y zero. Decorations have no collision. All 83 decorative
meshes are grounded and placed outside the arena's sides or behind its rear edge;
water is moved to the right perimeter, centered at X 26. Gameplay and enemy spawn
coordinates are unchanged. No model instances are duplicated.

Original materials/textures remain; instance material tints mute bright greens.
Vegetation/vine shadows are disabled. The original directional light and camera
are preserved. A dark green background and moderate green ambient fill improve
readability without adding another light. The demo no longer generates visible
prototype floor/path, trees, pillars or stones. Original unused primitive helper
functions and all original asset folders are retained.

MCP staged functional checks:

- Shrine loads/rendering and actual Begin Generation button signal opens Room 1.
- 25 collision samples hit JungleFloor at Y zero; player movement works.
- Gorilla chases/attacks; Space reduces HP and bar by the inherited damage.
- Room 2 snake bite deals 12, HP/bar responds to Space; death advances to Room 3.
- Room 3 has two Jaguars; pounce deals 16, HP/bar responds, both deaths advance.
- Room 4 has Gorilla/two Snakes/Jaguar; chase/bite work, last surviving Jaguar
  keeps Room 4 open, final death advances to the Memory Tiger.
- Tiger chases; melee deals 20, one pounce deals 25, Memory Roar deals 18.
  Space reduces 300 -> 275 HP/bar with the user's level-5 Attack upgrade.
  Repeated Space attacks kill it, hide its boss UI and show demo completion.
- Sacrifice confirms/pays the unchanged reward and returns to the Shrine.
  Fresh Room 2 Sacrifice pays 10; Room 3 death pays 25 and returns to the Shrine.
  All saved Generation/Memory/upgrade values were restored after these tests.
- Final ground covers all 49 sampled arena points. Decoration AABB tests find no
  blockers on nine sampled camera-to-character sightlines. No decorative collider.
- Final validator checks 95 surfaces clean; no new editor errors and no runtime
  script/shader errors in the final game log. Existing OpenGL-driver warning falls
  back to ANGLE/Microsoft Basic Render Driver; no project setting was changed.

Performance: three-second MCP profiles on this software renderer averaged 28.13
ms/frame for temporary original prototype visuals and 36.66 ms/frame for the final
jungle. The first integration averaged 44.90 ms; disabling vegetation shadows and
removing the additional directional fill improved it. Physics averages ~0.29 ms.
The scene is playable but this machine does not meet a 60 FPS final-build target;
performance on hardware rendering has not been verified. Texture/render memory is
higher than the primitive prototype. Short staged profiles are not benchmarks.

Protected player, enemy, Shrine, inheritance and project setting files were hash
checked unchanged. Only demo world construction and the new environment wrapper
were edited; room/progression/completion logic was preserved.
