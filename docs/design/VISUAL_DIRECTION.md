# Psychosims visual direction

The October 2026 visual refresh gives the existing game a dramatic, painterly
noir presentation inspired by *Disco Elysium*. The reference is its
[official media gallery](https://discoelysium.com/media), reviewed on
2026-10-23. The project uses original generated illustrations; no artwork,
characters, logos or UI screenshots were copied from that gallery.

## Screen language

Use ink-dark surfaces, warm paper, ochre highlights, rust accents and muted teal
to connect the interface with the illustrations. Serif display typography gives
case titles and dialogue a literary voice; Roboto remains the practical face
for controls and supporting information. Patient information should read like
a human case dossier, with visible action choices and game state.

The drama comes from expressive paint, directional light, strong typography and
the patient's emotional presence. It must not obscure the existing rules or
make controls hard to find. Preserve readable contrast, keyboard focus, touch
targets, responsive reflow, text scaling and reduced-motion behavior. Essential
information stays in accessible text rather than being baked into an image.

## Original art

| Bundled file | Dimensions | Bytes | Use |
|---|---:|---:|---|
| [`clinic-noir.png`](../../app/assets/art/clinic-noir.png) | 1536 × 1024 | 2,928,344 | Office and coastal-city atmosphere. |
| [`restless-hour-portrait.png`](../../app/assets/art/restless-hour-portrait.png) | 1024 × 1536 | 3,293,845 | The Restless Hour patient presentation. |

Both PNGs were generated on 2026-10-23 with the built-in image generation tool
and visually inspected before inclusion. They contain no lettering. The
portrait is an original, anonymous artistic interpretation of the active
`poc-vexa-001` manifest: restless, easily activated, and explicitly not in
crisis. Its physical appearance does not add a name, biography, diagnosis or
clinical identity to the patient. The scenario, dialogue constraints and
deterministic mechanics remain the content authority.

The two images add **6,222,189 bytes**, about **6.22 MB**, to the initial static
download. This is an intentional quality and offline-download tradeoff. They
are bundled with the app and included in its generated static-cache inventory,
so no image CDN or art service is contacted at runtime. Wait for **Ready
offline** before testing a disconnected reload. Each changed asset participates
in build/cache versioning; existing browser-local game state remains separate
from the resource cache.

### Clinic illustration prompt

```text
Use case: stylized-concept.
Asset type: wide landscape atmospheric hero illustration for Psychosims, a fictional therapeutic conversation game; original artwork inspired by Disco Elysium's expressive oil-painted noir atmosphere, not a screenshot or existing game asset.
Scene: an empty, intimate old therapy office above a rainy coastal industrial city at dusk. Two mismatched worn chairs angled in conversation beside a small table, broad tall windows, a brass desk lamp casts a warm pool of light, rain-streaked glass and distant cranes and block-like waterfront buildings. Sense of charged silence before an important conversation; humane, emotionally dramatic, curious rather than threatening. No people.
Style: confident expressive oil painting, sculptural impasto and scraping, rough charcoal underdrawing visible, gestural fractured planes of pigment, painterly lost edges, atmospheric fine-art game concept illustration. Distinct designed shapes, powerful oblique window light and diagonal composition, beautiful texture. Sophisticated palette: near-black ink, ash grey, old parchment, burnt ochre, iron rust orange, restrained oxidized teal. Luminous ochre window reflection against deep teal shadows.
Composition: landscape wide 3:2 or wider, 1536px wide approximately. A complete illustration edge to edge; middle and lower portion retains quieter dark areas suitable behind UI copy, memorable architectural silhouettes and light in upper right. Do not add text, letters, logos, lettering, symbols, watermarks, UI, borders, split panels or existing game characters. No horror, gore, weapons, photorealism or glossy 3D. The office must feel inviting enough for a human conversation, not abandoned or filthy.
```

### Patient portrait prompt

```text
Use case: stylized-concept.
Asset type: original tall patient dossier portrait for Psychosims, a fictional therapeutic conversation game. A new fictional character, not any existing Disco Elysium character; use the game's expressive painterly noir sensibility as a broad art direction.
Subject: an androgynous adult, late thirties in visual age, short irregular dark hair, warm medium olive complexion, plain worn teal crewneck under a simple charcoal jacket. Three-quarter head and shoulders composition. An alert searching glance slightly off-camera, slight tension around eyes and parted mouth as if thoughts are running faster than words; grounded and dignified, vulnerable and resolute, fully human. They are restless, not in crisis; do not signal a diagnosis, violence, villainy, madness or horror. Keep face recognizable and sympathetic rather than grotesque. No props.
Style: bold expressive oil portrait with rough charcoal underdrawing, thick angular impasto knife strokes, broken planes of paint, edges dissolving into loose directional gestural marks. Fine-art narrative game character art, emotionally arresting with painterly abstraction around a convincingly human face; no photo finish or glossy3D.
Backdrop: abstract ash parchment and ink charcoal, sweeping fractured rust orange strokes on one side and muted oxidized teal on the other, suggesting restless thought through gestural paint, not literal symbols. Directional warm ochre light brushes one side of face against cool slate shadows. Palette harmonizes with dark noir office art: ink, ash, ochre, rust, desaturated teal.
Composition: vertical approximately1024x1536, head centered in upper middle with shoulders in lower portion, enough breathing room above hair, no crop through face, no decorative frame, full bleed painterly background. Strong thumbnail silhouette, subtle asymmetry. No text, letters, symbols, labels, UI, logos, watermark, existing game character features, blood, injuries, weapons, medical equipment, nightmare imagery.
```

## Local typography and notices

`NotoSerif-Regular.ttf`, `NotoSerif-Bold.ttf` and
`NotoSansSymbols-Regular.ttf` are copied without modification
from the workstation's installed `/usr/share/fonts/truetype/noto/` files. The
upstream copyright and SIL Open Font License 1.1 text are preserved from the
installed Debian package's copyright file in
[`NotoSerif_LICENSE.txt`](../../app/assets/fonts/NotoSerif_LICENSE.txt).
These local files require no online font request. Noto Sans Symbols is the
explicit local fallback for symbols used by browser controls; production
playtests assert that no requested font returns 404.

Existing bundled Roboto Regular, Medium and Bold remain available under their
preserved [Apache 2.0 notice](../../app/assets/fonts/Roboto_LICENSE.txt).
The production artifact must retain the font license assets and Flutter's
generated dependency notices. See [LICENSES](../../LICENSES.md) for the separate
package-inventory and license gates.
