# Horde and boss balance

The ten-minute run uses a threat budget rather than one independent random roll per spawn. Each enemy has a spawn weight, threat cost, group range and optional simultaneous cap. Boss encounters pause the horde clock, so their duration does not consume normal progression time.

## Enemy roster

| Enemy | Role | HP | Speed | Damage | XP | Rarity / debut |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| Bat | Swarm | 12 | 155 | 5 | 4 | Common, 00:00 |
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
| 06:30 | Orc Warlord encounter |
| 06:30–08:00 | Orcs join, first Minotaur event at 07:30, cap 150 |
| 08:00–10:00 | Full roster and final swarm, cap 220 |
| 10:00 | Corrupted Treant final encounter |

## Bosses

| Boss | HP | Difficulty | Main behavior | Result |
| --- | ---: | --- | --- | --- |
| King Slime | 1,500 | 2/5 | Telegraph slam and Slime summons | Chest, then resume |
| Orc Warlord | 4,000 | 4/5 | Telegraph charge, Orc summons, faster phase two | Chest, then resume |
| Corrupted Treant | 8,000 | 5/5 | Targeted ground eruptions, summons, faster phase two | Chest, then victory |

Balance values are intentionally isolated between `EnemyData` combat resources and `EnemySpawnEntry` horde configuration. This allows tuning enemy combat without accidentally changing its frequency, and vice versa.
