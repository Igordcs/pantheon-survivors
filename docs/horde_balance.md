# Horde and boss balance

The ten-minute run uses a threat budget rather than one independent random roll per spawn. Each enemy has a spawn weight, threat cost, group range and optional simultaneous cap. Boss encounters pause the horde clock, so their duration does not consume normal progression time. Regular spawning resumes during non-final boss fights, using the current horde phase, but remains disabled during the final encounter. Enemies summoned directly by a final boss attack are still allowed.

## Enemy roster

| Enemy | Role | HP | Speed | Damage | XP | Rarity / debut |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| Bat | Swarm | 12 | 140 | 5 | 4 | Common, 00:00 |
| Draugr | Basic melee | 24 | 115 | 8 | 7 | Common, 00:00 |
| Harpy | Fast flanker | 30 | 140 | 10 | 10 | Uncommon, 01:00 |
| Arcane Slime | Ranged | 26 | 65 | 8 projectile | 12 | Uncommon, 02:00 |
| Healer Slime | Support | 45 | 60 | 5 | 18 | Rare, 03:00 |
| Medusa | Ranged control | 55 | 75 | 10 projectile + slow | 20 | Rare, 03:00 |
| Mummy | Heavy ranged | 70 | 60 | 14 projectile | 22 | Rare, 05:00 |
| Cyclops | Heavy melee | 130 | 50 | 22 | 30 | Very rare, 05:00 |
| Orc | Tank | 180 | 45 | 26 | 35 | Very rare, 06:30 |
| Minotaur | Charger / elite event | 260 | 70 | 30 / 40 charge | 60 | Event, 07:30 |

## Timeline

| Time | Pressure change |
| --- | --- |
| 00:00–01:00 | Bat and Draugr introduction, cap 25 |
| 01:00–02:00 | Harpies and a bat swarm event, cap 40 |
| 02:00–03:00 | Ranged Slimes and a ranged surround event, cap 55 |
| 03:00 | King Slime encounter |
| 03:00–05:00 | Medusa and Healer Slime, cap 80 |
| 05:00–06:30 | Mummy and Cyclops, cap 110 |
| 06:30 | Random medium boss: Orc Warlord or Cerberus |
| 06:30–08:00 | Orcs join, first Minotaur event at 07:30, cap 150 |
| 08:00–10:00 | Full roster and final swarm, cap 220 |
| 10:00 | Random final boss: Corrupted Treant or Jormungandr |

## Bosses

| Boss | HP | Speed | Damage | Difficulty | Main behavior | Result |
| --- | ---: | ---: | --- | --- | --- | --- |
| King Slime | 1,500 | Stationary | 18 | 2/5 | Frontal strike and ranged/support Slime summons | Chest, then resume |
| Orc Warlord | 4,000 | 65 | 25 contact / 32 charge | 4/5 | Targeted charge, Orc summons and faster phase two | Chest, then resume |
| Cerberus | 3,600 | 72 | 24 contact / 28 breath / 38 leap | 4/5 | Three infernal breath cones and a targeted crushing leap | Chest, then resume |
| Corrupted Treant | 8,000 | 38 | 30 contact / 38 eruption | 5/5 | Slow pursuit, targeted ground eruptions, Bat summons and faster phase two | Chest, then victory |
| Jormungandr | 9,500 | 58 | 30 contact / 45 bite / 14 impact / 8 poison tick / 12 magic | 5/5 | Emerging bite, poison spit and a radial magic barrage | Chest, then victory |

## Boss selection

Bosses are selected once when the run starts. The 03:00 slot currently contains only King Slime. The 06:30 medium slot has equal weight for Orc Warlord and Cerberus. The 10:00 final slot has equal weight for Corrupted Treant and Jormungandr. New bosses can be added to a slot through `BossCandidateData` without changing the encounter flow.

`RunManager.boss_selection_seed` controls the selection sequence. A value of `0` creates a random seed and prints it to the console; a manually configured value reproduces the same choices for tests and balancing sessions.

During every boss warning, regular spawning is stopped and the active horde is reduced. When a non-final boss becomes active, spawning resumes with the current wave configuration while the horde clock remains paused. For the final boss, the active regular horde is cleared and spawning stays stopped until the run ends. This restriction only applies to `EnemySpawner`; minions created by a boss-specific attack remain part of that boss fight.

## Boss attack rules

### King Slime — early boss

- **Frontal strike:** King Slime faces the player and displays a rectangular warning in that direction for 1.5 seconds. The dangerous area then activates for 0.5 seconds and deals damage on contact.
- **Slime summons:** while waiting for its next strike, it summons either a Ranged Slime or a Healer Slime at a random position around itself every four seconds.
- King Slime remains stationary during the fight. Its pressure comes from controlling the space in front of it while summoned enemies accumulate.

### Orc Warlord — medium boss

- **Targeted charge:** the player's position is captured when the warning begins. After 0.95 seconds, the Warlord charges toward that position at high speed and deals damage if it reaches the player.
- **Orc summons:** it summons a Tank Orc periodically, initially every nine seconds.
- Orc Warlord continually chases the player between attacks. Below half health, attack cooldowns and summon intervals become 28% and 25% shorter, respectively.

### Cerberus — medium boss

- **Three infernal breaths:** Cerberus stops and telegraphs three separate fire cones. The cones point in neighboring directions while keeping gaps between them, so positioning in the safe space avoids damage. Damage is applied once when the telegraph resolves.
- **Crushing leap:** the player's position is captured when the attack starts and marked on the ground. After the warning, Cerberus leaps to that position and deals circular area damage. Moving outside the marked radius avoids the hit.
- Outside attack wind-ups and recovery, Cerberus continually moves toward the player. Below half health, its chase speed increases slightly.

### Corrupted Treant — final boss

- **Targeted ground eruption:** the player's position is captured and marked with a circular warning for 1.2 seconds. The marked area then erupts, dealing damage within a 135-pixel radius.
- **Bat summons:** it periodically summons a Bat, initially every 7.5 seconds. These minions are part of the boss's own kit and remain enabled during the final fight.
- Corrupted Treant plays its ground emergence animation once when it spawns, then keeps the fully emerged frame while slowly pursuing the player. Below half health, attack cooldowns and summon intervals become 28% and 25% shorter, respectively.

### Jormungandr — final boss

- **Emerging bite:** a circular ground mark appears at the player's captured position. Jormungandr emerges at that point after the warning and deals circular area damage.
- **Poison spit:** Jormungandr launches three visible arcing projectiles around the player's captured position. Their impact points are distributed across a 130-pixel radius to keep the spits farther apart. Each impact deals direct damage at close range and creates a temporary poison puddle with a 92-pixel radius that deals damage at fixed intervals.
- **Radial magic barrage:** after a circular warning around the boss, Jormungandr releases 36 magic projectiles simultaneously. One projectile is fired every 10 degrees, covering the full 360-degree area around it. Each projectile deals 12 damage and disappears after traveling 720 pixels.
- Outside attack wind-ups and recovery, Jormungandr continually moves toward the player. Below half health, its chase speed increases slightly.

The telegraphs are intentionally separate from damage resolution: warning shapes are safe until their attack resolves, and poison puddles are temporary hazards rather than permanent map obstacles.

Balance values are intentionally isolated between `EnemyData` combat resources and `EnemySpawnEntry` horde configuration. This allows tuning enemy combat without accidentally changing its frequency, and vice versa.
