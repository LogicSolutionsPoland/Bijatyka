# Player animation retargeting

The player keeps the Thornbound model and its 21-bone skeleton. Selected clips from the supplied Quaternius Universal Animation Library and KayKit Character Animations 1.1 packs are retargeted to that rig at player initialization; the source mannequins are hidden and freed after their clips are copied.

## Bound clips

- UAL Punch_Jab and Punch_Cross drive the left and right punch actions.
- KayKit Melee_Unarmed_Attack_Kick drives left and right kicks, with the left side mirrored across the character's centerline.
- KayKit Melee_Unarmed_Idle supplies the combat guard idle.
- UAL Walk_Loop, Sprint_Loop, and Spell_Simple_Shoot supply walking, sprinting, and spell casts.
- KayKit Jump_Full_Short is retimed to the current jump's approximately 0.68-second airtime.

The authored UAL jab/cross hand reach peaks near 23%/30% of their source clips, and the KayKit kick reach peaks near 45%. The retargeter maps those contact poses to the existing punch/kick windup boundaries, so damage and hit timing stay in sync with gameplay.

## Retarget mapping

Only the target rig's existing root, hips, torso, head, arms, and legs receive animation tracks. UAL's 65-joint rig and KayKit's 23-joint rig remain source assets; extra fingers, toes, accessory bones, and root translation are excluded. A one-time contact-pose check rejects a clip set that would strike backward, allowing the existing forward-facing fallback clips to remain available.

The player inputs, attack damage, range, cooldown/recovery profile, movement speed, jump physics, and dash behavior are unchanged.
