# Look previews

Concept screens for the working title Holdings. They show the mood in Appendix B of `docs/BRIEF.md`, in a current mobile-game direction: soft 3D isometric towns and a plain app interface. They are not the in-game art. Replacing code-drawn shapes with finished Blender art is still on the Later list in `docs/DECISIONS.md`.

The playable Harborview town is still four streets of five plots, with the names in `docs/REFERENCE.md`. These pictures are looser than that grid.

| File | Screen |
|---|---|
| `world-map.jpg` | The island. Harborview, Ironridge, and Greenvale, with daily change, a fragility meter, and a rumor mark on Ironridge. |
| `harborview-day.jpg` | Harborview by day. Harbor, lighthouse, four street labels, car-wash foam, a filling parking lot, For Sale plots, ownership colors, floating earnings, Rita buying. |
| `harborview-night.jpg` | The same town when the phone is in dark mode. Headlights, a lit car wash, a lighthouse beam. |
| `plot-panel.jpg` | A selected empty plot on The Docks, with the buy sheet. |
| `ironridge.jpg` | The mining town: headframe, ore carts, workers' diner, a high fragility meter. |
| `greenvale.jpg` | The farming valley: fields, a grain silo, a farm stand, a low fragility meter. |
| `standings.jpg` | The five solo players. Bots are labelled Bot. |

## Numbers on the pictures

Picture labels, not tuning values, except these two, which match Appendix A at traffic 55 and a street multiplier of 1:

- 660 cars a day is 55 × 12, before the ±9% display noise.
- The $3,210 price is the land price `(900 + 55 × 42)`.

Cash, net worth, street percentages, fragility fills, and the standings are only there so the screens read as a game. Do not copy them into `tuning.dart`.
