# XP progression

Player level requirements use a gradual curve instead of a fixed increase. The requirement for the next level is calculated from the current level:

```text
required XP = base + linear growth × level index + acceleration × level index²
```

The level index starts at zero for the first level-up. Default tuning values are:

- Base requirement: 30 XP
- Linear growth: 8 XP per level
- Acceleration: 0.75

| Current level | XP required for next level |
| ---: | ---: |
| 1 | 30 |
| 2 | 39 |
| 3 | 49 |
| 5 | 74 |
| 10 | 163 |
| 15 | 289 |
| 20 | 453 |
| 30 | 893 |

All three parameters are exported by `ExperienceComponent` and can be tuned from the Player scene Inspector. XP beyond a level threshold carries over to the next level.
