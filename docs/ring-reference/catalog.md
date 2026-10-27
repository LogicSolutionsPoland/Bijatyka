# Ring reference movement catalog — 27 October 2026

Source: user attachment `walka Bijatyka`, 720×720, 60000/1001 fps, 2,930 video frames, 48.882 s video (48.948 s container/audio). SHA-256 is retained in `tools/ring_reference/motions.json`. Times are elapsed seconds in this attachment, **not** time in an original film. A = dark hair, large central chest tattoo, black shorts with white piping/knee support. B = lighter hair, black shorts with red side panels. These are visual labels, not identities.

Method: reviewed the entire montage on timestamped 4 fps contact sheets; inspected the principal exchanges at 10 fps (10.45–13.15, 23.45–26.15, 28.45–32.35, 39.70–41.90, 43.15–44.30). Boundaries below are approximate to 0.10 s, not automated action segmentation. No pose-estimation or mocap system was used. Cuts, held frames, motion blur, crops and occlusion prevent exhaustive recovery of joint motion. Camera movement, audience and overlays are excluded.

Classification: **R** = manually reconstructed reference clip; **P** = partial action/transition cataloged only; **O** = observed static pose, not an extracted full action. Every reconstructed clip is an approximation in depth. Contact means estimated fullest extension, not proof of physical impact. No unambiguous isolated uppercut or separate backward/lateral locomotion cycle could be established.

| ID | Time (s); duration | Fighter | Motion and start → end | Joints | Foot contact / transfer | Loop; gameplay application | Result |
|---|---|---|---|---|---|---|---|
| 01 | 0.00–1.10; 1.10 | A | Low relaxed guard, small hand/shoulder gesture; upright → upright | Shoulders, elbows, wrists, head | Feet cropped; cannot infer exact transfer | No; ambient stance | P; no complete gait |
| 02 | 2.90–4.60; 1.70 | B | Forward crouch → upright, both fists raised overhead | Pelvis, spine, shoulders, elbows, knees | Extends legs; feet partly cropped | No; taunt/emote | R `arms_raised_taunt`; guard endpoints adapted |
| 03 | 4.60–6.10; 1.50 | B | Raised arms → loose crossing arm gestures and lowered hands | Shoulders, elbows, torso | Lower legs absent | No; taunt continuation | P; not counted as punches at an opponent |
| 04 | 6.25–7.10; 0.85 | A | Low hands → fists in front of chest/chin | Shoulders, elbows, wrists | Feet cropped; base inferred | No; combat preparation | R `guard_raise` uses 6.50–7.10 |
| 05 | 7.20–7.80; 0.60 | A | Brief overhead double-hand feint/gesture → guard | Shoulders, elbows | Feet cropped | No; preparation variant | P; distinct from an impact block |
| 06 | 7.75–8.15; 0.40 | A | Settled upright guard held | Pelvis, spine, arms | Feet cropped | Static loop; reusable guard | R `guard_hold`, static pose; loop not recovered bounce |
| 07 | 9.25–10.35; 1.10 | A/B | Distant positioning in wide shot | Whole body, poorly resolved | Too small to resolve contacts | No; locomotion reference only | P |
| 08 | 10.45–10.80; 0.35 | B | Low open guard → slight forward shuffle/brace | Pelvis, knees, shoulders | Split base; short approach | No; approach/guard transition | P; not a walk cycle |
| 09 | 10.75–11.55; 0.80 | A | Chamber → high lateral/roundhouse-like kick → plant | Pelvis, support hip/ankle, striking hip/knee/ankle, counterbalancing arms | Single support then replant; heel pivot partly obscured | No; high kick | R `right_high_kick`; anatomical side tentative; left version is a declared mirror |
| 10 | 10.85–11.55; 0.70 | B | Guard → bent-knee duck with torso roll → rise | Knees, hips, spine, head | Wide base; weight lowers then shifts across | No; evasive reference | R `duck_roll`; no new dodge control |
| 11 | 11.65–11.95; 0.30 | B | Short lead-side straight extension → retraction | Shoulder, elbow, torso | Partial forward shift | No; punch corroboration | P; blurred/partly hidden |
| 12 | 12.00–12.35; 0.35 | B | Opposite short punch/arm extension → guard | Shoulder, elbow, torso | Feet visible intermittently | No; combination fragment | P; do not assert exact jab/cross classification |
| 13 | 12.35–13.10; 0.75 | A | Bent torso → forward collapse onto canvas | Hips, spine, knees, shoulders | Loses upright support; hands/torso land | No; defeat transition | P; collision/fall not reconstructed |
| 14 | 13.20–14.65; 1.45 | B | Raised leg → downward foot drive → foot lowers | Hip, knee, ankle; raised arms | One planted leg, raised leg descends toward floor | No; ground-target attack reference | R `downward_stamp`, 13.55–14.65; approach outside clip |
| 15 | 14.65–15.55; 0.90 | B | Raised arm → downward punch-like arm drive → partial return | Spine, shoulder, elbow | Stable split base; bends forward | No; ground-target punch reference | R `downward_punch`; no new damage/action |
| 16 | 16.45–18.35; 1.90 | B | Both arms raise/lower/re-raise while turning | Pelvis, spine, shoulders, elbows | Short pivot/steps; feet cropped | No; taunt corroboration | P; repeats gesture family 02 |
| 17 | 21.70–23.30; 1.60 | A | Curled on canvas, head down, fist near face | Spine, neck, elbow | Torso/forearms on floor | Static hold; downed pose | O; entry/exit unseen, no fabricated fall/recovery |
| 18 | 23.45–23.95; 0.50 | B | Split stance → step into opponent | Pelvis, hips, knees, ankles | Lead foot plants, rear foot follows | No; short approach | R `step_in`; visual root displacement only, reference library |
| 19 | 23.55–23.95; 0.40 | B | Lead-side short straight → retract | Torso, shoulder, elbow, wrist | Forward loading with lead step | No; existing left punch | R `lead_straight`; guard endpoints inferred |
| 20 | 23.55–24.15; 0.60 | A | Raised hand intercepts/parries near face | Shoulder, elbow, wrist | Wide planted base | No; defense fragment | P; cannot establish full block cycle/contact |
| 21 | 24.05–24.45; 0.40 | B | Rear-side bent-arm lateral punch → follow-through | Pelvis, spine, shoulder, elbow | Turns through split base | No; existing right punch | R `rear_hook`; inferred depth and return to guard |
| 22 | 24.45–25.10; 0.65 | B | Broad overhand/looping swing during turn | Pelvis, shoulders, elbow | Steps/pivots around A | No; combination fragment | P; occluded contact |
| 23 | 24.65–25.30; 0.65 | A | Forward bend and pivot out of exchange → turning stance | Pelvis, spine, hips, knees, ankles | Steps around planted lead side | No; pivot/exit reference | R `pivot_exit`; root yaw/displacement approximate |
| 24 | 25.30–26.10; 0.80 | B | Turning high leg sweep/kick behind A → plant | Pelvis, hip, knee, ankle | One-leg support, pivot then plant | No; alternate kick reference | P; contact/limb partly hidden; no invented separate kick |
| 25 | 25.35–26.10; 0.75 | A | Turn away and stagger toward ropes | Pelvis, spine, legs, arms | Several short corrective steps | No; stagger | P; root path uncalibrated |
| 26 | 26.25–27.65; 1.40 | A | Upper body meets ropes → bends forward and recoils | Spine, neck, shoulders | Feet off-camera; rope supports body | No; hit reaction reference | R `rope_recoil`, 26.25–27.00; unsupported rope context prevents default Hit replacement |
| 27 | 27.75–28.45; 0.70 | A | Distant hunched stance → reapproach/guard | Spine, hips, arms | Partly occluded | No; recovery fragment | P |
| 28 | 28.55–29.15; 0.60 | B | Knee lift with close bent-arm swing | Hip, knee, torso, shoulder | One-leg loading, contact hidden by A | No; knee/combination fragment | P; not a clean reconstructable knee strike |
| 29 | 28.85–29.45; 0.60 | A/B | Alternating short hooks/hand checks at close range | Torso, shoulders, elbows | Wide base; partly cropped | No; combination reference | P; exact hand contacts/side uncertain |
| 30 | 29.45–29.75; 0.30 | B | Short straight/bent-arm extension → reload | Shoulder, elbow, torso | Wide base | No; punch corroboration | P |
| 31 | 29.75–30.35; 0.60 | B | Hand arcs above head then downward across centerline | Spine, pelvis, shoulder, elbow | Loads rear side then rotates/leans forward | No; optional overhand variant | R `overhand`; not assigned a new button |
| 32 | 29.95–30.55; 0.60 | A | Ducks under arm then returns upright | Knees, hips, spine, head | Lowers weight in wide base | No; evasion corroboration | P; overlaps reconstructed duck family |
| 33 | 30.55–31.30; 0.75 | A/B | Short arm exchanges with B knee lift/turn | Torso, arms, hip/knee | Transfers toward a turn | No; combination transition | P; cut/blur and occlusion |
| 34 | 31.30–32.35; 1.05 | A | Chamber/takeoff → airborne turning high kick → landing | Whole body | Both feet airborne, then plants and bends knees | No; aerial reference | P airborne segment; R `kick_landing`, 31.95–32.35 only; no exact airborne reconstruction |
| 35 | 32.40–33.30; 0.90 | A | Crouched landing image held/repeated with overlay | Knees, pelvis, spine | Wide grounded pose | No; landing corroboration | O; repeated edited frames do not define new motion |
| 36 | 33.45–35.10; 1.65 | A/B | A airborne sideways/spinning kick over B duck; A falls/rolls as B rises | Whole body | A airborne then ground; B two-foot crouch | No; aerial/fall reference | P; entry cut and crossing bodies; do not synthesize interaction/root trajectory |
| 37 | 35.10–35.65; 0.55 | A/B | Held/repeated fall/rise image | Whole body | Mixed floor/support | No | O; edited freeze |
| 38 | 35.75–37.35; 1.60 | A | Jumping turning kick → landing near B | Whole body | Airborne then single-foot landing | No; aerial reference | P; no calibrated root motion or impact |
| 39 | 37.35–38.10; 0.75 | A/B | Held landing/evade image | Whole body | Grounded | No | O; repeated edited frames |
| 40 | 39.75–40.35; 0.60 | B | Raised hand/looping arm extension near A | Shoulder, elbow, torso | Feet cropped | No; punch/gesture fragment | P; contact off-camera |
| 41 | 40.35–40.90; 0.55 | A | Torso shifts sideways/down under B arm | Spine, pelvis, neck | Feet off-camera; small weight shift inferred | No; slip reference | R `body_slip`; not a locomotion cycle |
| 42 | 40.90–41.35; 0.45 | B | Short bent-arm swing across A → guard | Torso, shoulder, elbow | Feet cropped | No; hook corroboration | P |
| 43 | 41.35–42.15; 0.80 | A | Head/shoulder recoil and grimace | Neck, upper spine, shoulders | Lower body absent | No; hit-reaction fragment | P; no facial rig reconstruction |
| 44 | 42.15–43.05; 0.90 | A | Repeated near-static grimace frame | Face, neck | Not visible | No | O; edited hold |
| 45 | 43.15–44.25; 1.10 | A/B | Turning airborne kick/duck, then B counter arm swing toward bent A | Whole body | Jump/support then landing; bodies cross | No; aerial and counter fragments | P; cut changes angle; no reliable independent full clip |
| 46 | 44.25–45.60; 1.35 | A | Supine on canvas; repeated image | Spine, hips, limbs | Back on floor | Static; downed pose | O; no visible fall transition |
| 47 | 45.60–46.85; 1.25 | A | Close-up head lift/open mouth | Head, neck, jaw | Not visible | No; expression | P; no facial animation extraction |
| 48 | 46.85–48.88; 2.03 | A | Near-static close-up repeated/held | Face, neck | Not visible | No | O; edited hold |

Excluded intervals show spectators, non-ring people, camera transitions or no useful fighter detail. No additional attacks are inferred across those cuts.

## Authored clips, duration and action mapping

The `.tres` clips retain **authored reference duration**, which can include an inferred guard/recovery endpoint. They are not frame-extracted animation data. `motions.json` preserves the selected source range and hand-authored target keys. The runtime attack copies retime the contact to the existing gameplay windup and recovery to the existing duration.

| Resource (both rigs) | Authored duration | Loop | Existing action / use |
|---|---:|---|---|
| guard_hold | 0.40 s | Static loop | Reference library only |
| guard_raise | 0.60 s | No | Reference library only |
| lead_straight | 0.52 s | No | Left punch, player/enemies/boss |
| rear_hook | 0.62 s | No | Right punch, player/enemies/boss |
| overhand | 0.65 s | No | Optional reference clip |
| duck_roll | 0.70 s | No | Optional reference clip; no new dodge mechanic |
| body_slip | 0.55 s | No | Optional reference clip |
| right_high_kick | 0.80 s | No | Right kick; approximate technique and tentative anatomical side |
| left_high_kick | 0.80 s | No | Left kick; mirrored game adaptation, not independently observed |
| downward_stamp | 1.10 s | No | Optional ground-target reference; existing collision/damage unchanged |
| downward_punch | 0.90 s | No | Optional reference; existing collision/damage unchanged |
| step_in | 0.50 s | No | Optional reference with visual pelvis/foot travel; not applied as physics root motion |
| pivot_exit | 0.65 s | No | Optional reference with visual yaw/translation; not physics root motion |
| rope_recoil | 0.75 s | No | Optional contextual reaction; imported Hit remains default |
| arms_raised_taunt | 1.60 s | No | Optional taunt; not attached to an attack |
| kick_landing | 0.40 s | No | Optional landing reference; existing jump/landing remains default |

Every optional clip is installed under `ring_reference/<resource>` on the actual player and detailed enemy/boss AnimationPlayers. Selection is available to future controllers without changing controls/AI now. Unsupported aerials, falls, a genuine uppercut, complete blocks, a separate cross, and complete backward/lateral gait cycles are **not** fabricated. Existing UAL clips, legacy `fight_animation.gd`, models and normal locomotion remain available.
