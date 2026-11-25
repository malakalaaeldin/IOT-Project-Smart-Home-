---
name: Front-Desk Key Board
description: Calm Hills Villa run like a small hotel's reception, with every device a numbered brass tag on a walnut key board.
colors:
  plaster-0: "#f6f7f4"
  plaster-1: "#e4e7e2"
  plaster-2: "#d3d7d0"
  plaster-3: "#b4b9b1"
  plaster-4: "#6c7068"
  plaster-5: "#4e524b"
  plaster-6: "#1c1e1a"
  walnut-0: "#2a1e16"
  walnut-1: "#3a2a1f"
  walnut-2: "#4a382b"
  walnut-3: "#6e5a48"
  on-walnut: "#f1e9da"
  on-walnut-2: "#cdbca2"
  brass-hi: "#ecd08a"
  brass: "#c9a04e"
  brass-lo: "#8e6e2e"
  on-brass: "#2a1e16"
  felt: "#1e4a3b"
  felt-2: "#2b5e4c"
  felt-deep: "#163a2e"
  on-felt: "#e8f1ec"
  on-felt-2: "#b4cfc1"
  fire: "#b3261e"
  fire-hi: "#c4342b"
  fire-bg: "#fbe9e7"
typography:
  display:
    fontFamily: "Figtree, system-ui, -apple-system, Segoe UI, sans-serif"
    fontSize: "2.5rem"
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "-0.01em"
    fontFeature: "tnum"
  headline:
    fontFamily: "Figtree, system-ui, -apple-system, Segoe UI, sans-serif"
    fontSize: "1.375rem"
    fontWeight: 700
    lineHeight: 1.25
  title:
    fontFamily: "Figtree, system-ui, -apple-system, Segoe UI, sans-serif"
    fontSize: "1.1875rem"
    fontWeight: 600
    lineHeight: 1.2
  body:
    fontFamily: "Figtree, system-ui, -apple-system, Segoe UI, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.5
  body-sm:
    fontFamily: "Figtree, system-ui, -apple-system, Segoe UI, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 500
    lineHeight: 1.5
  label:
    fontFamily: "Archivo Narrow, Figtree, system-ui, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 600
    letterSpacing: "0.12em"
  tag-number:
    fontFamily: "Archivo Narrow, Figtree, system-ui, sans-serif"
    fontSize: "0.75rem"
    fontWeight: 600
    letterSpacing: "0.14em"
rounded:
  sm: "8px"
  tag: "10px"
  md: "12px"
  pill: "999px"
spacing:
  xs: "0.5rem"
  sm: "0.75rem"
  md: "1rem"
  board-gap: "1.125rem"
  lg: "1.5rem"
components:
  bar:
    backgroundColor: "{colors.walnut-0}"
    textColor: "{colors.on-walnut}"
    height: "4rem"
  bar-fire:
    backgroundColor: "{colors.fire}"
  pill-offline:
    backgroundColor: "{colors.walnut-2}"
    textColor: "{colors.on-walnut-2}"
    rounded: "{rounded.pill}"
    padding: "0.375rem 0.75rem"
  key-board:
    backgroundColor: "{colors.walnut-1}"
    rounded: "{rounded.md}"
    padding: "clamp(1rem, 2vw, 1.5rem)"
  tag-rest:
    backgroundColor: "{colors.walnut-2}"
    textColor: "{colors.on-walnut-2}"
    rounded: "{rounded.tag}"
    padding: "2.125rem 1rem 0.875rem"
    height: "9.5rem"
  tag-on:
    backgroundColor: "{colors.brass}"
    textColor: "{colors.on-brass}"
  tag-on-hover:
    backgroundColor: "{colors.brass-hi}"
  tag-alarm:
    backgroundColor: "{colors.fire}"
    textColor: "#ffffff"
  bell-mic:
    backgroundColor: "{colors.brass}"
    textColor: "{colors.on-brass}"
    rounded: "{rounded.pill}"
    size: "6rem"
  mode-switch:
    backgroundColor: "{colors.felt-deep}"
    textColor: "{colors.on-felt-2}"
    rounded: "{rounded.pill}"
    padding: "0.1875rem"
  mode-switch-selected:
    backgroundColor: "{colors.on-felt}"
    textColor: "{colors.felt}"
    rounded: "{rounded.pill}"
    padding: "0.375rem 0.75rem"
  voice-desk:
    backgroundColor: "{colors.felt}"
    textColor: "{colors.on-felt}"
    rounded: "{rounded.md}"
    padding: "1.25rem"
  ledger-user:
    backgroundColor: "{colors.on-felt}"
    textColor: "{colors.felt-deep}"
    rounded: "{rounded.tag}"
    padding: "0.5rem 0.75rem"
  ledger-agent:
    backgroundColor: "{colors.felt-2}"
    textColor: "{colors.on-felt}"
    rounded: "{rounded.tag}"
    padding: "0.5rem 0.75rem"
  reading-card:
    backgroundColor: "{colors.plaster-0}"
    textColor: "{colors.plaster-6}"
    rounded: "{rounded.md}"
    padding: "1.25rem 1.25rem 1.125rem"
  reading-card-fire:
    backgroundColor: "{colors.fire-bg}"
    textColor: "{colors.fire}"
  fire-banner:
    backgroundColor: "{colors.fire-bg}"
    padding: "0.875rem clamp(1rem, 3vw, 2rem)"
  button-primary:
    backgroundColor: "{colors.walnut-0}"
    textColor: "{colors.on-walnut}"
    rounded: "{rounded.sm}"
    padding: "0 1.125rem"
    height: "2.75rem"
  button-primary-hover:
    backgroundColor: "{colors.walnut-2}"
  button-quiet:
    backgroundColor: "transparent"
    textColor: "{colors.plaster-6}"
    rounded: "{rounded.sm}"
    padding: "0 1.125rem"
    height: "2.75rem"
  button-quiet-hover:
    backgroundColor: "{colors.plaster-0}"
  button-fire:
    backgroundColor: "{colors.fire}"
    textColor: "#ffffff"
    rounded: "{rounded.sm}"
    padding: "0 1.125rem"
    height: "2.75rem"
  button-fire-hover:
    backgroundColor: "{colors.fire-hi}"
  input:
    backgroundColor: "#ffffff"
    textColor: "{colors.plaster-6}"
    rounded: "{rounded.sm}"
    padding: "0 0.875rem"
    height: "2.75rem"
  input-desk:
    backgroundColor: "{colors.felt-deep}"
    textColor: "{colors.on-felt}"
    rounded: "{rounded.sm}"
    padding: "0 0.875rem"
    height: "2.75rem"
---

# Design System: Front-Desk Key Board

## Overview

**Creative North Star: "The Front-Desk Key Board"**

Calm Hills Villa is run like the reception of a small hotel. Every device in the house hangs as a numbered tag on an oiled-walnut key board; a tag that is on or open turns to brushed brass and lifts off the board, the way a key off its hook tells the clerk a room is taken. The whole house reads in one glance, across a room or from a projector: what is open, what is lit, whether the ESP32 is online, whether there is fire.

The materials are few and each has one job. Walnut is the shell (the bar and the board). Plaster is the room around it, on one fixed seven-step ramp. Brass is the state of being on. Green desk felt is the voice desk, where a round brass bell is rung to speak. Alarm red belongs to fire and nothing else, and when fire comes it takes the bar, the alarm tag and the fire card at once. The density is calm and generous: eight equal tags, two readings, one desk. It refuses the category default of a grid of rounded icon tiles with a blue accent.

**Key Characteristics:**
- Walnut shell, plaster room, brass state, felt desk, red fire: five materials, five jobs.
- Eight equal tags in a fixed grid; state changes colour and lift, never size or position.
- One sans (Figtree) for all UI; Archivo Narrow tracked caps for tag numbers and section labels; tabular numerals for readings.
- Flat plaster surfaces; depth only where a physical object would cast it (the board, a lifted tag, the bell, the desk).
- Motion is physical and short: tags swing on their hook, the bell rings while listening.

## Colors

A warm, material palette: dark walnut and green felt carry the controls, cool plaster carries the reading surfaces, and the two signal colours (brass, red) are held back for state.

### Primary
- **Brushed Brass** (brass): the fill of a tag that is on or open, the bell-mic, the focus ring. Its presence on the board is the answer to "what is running".
- **Polished Brass** (brass-hi): hover on an active tag or the bell, the bell's listening ring, text selection.
- **Shadowed Brass** (brass-lo): input focus border, caret and native accent colour, the gauge's threshold mark, the tag hook on hover.
- **Ink on Brass** (on-brass): text and hook on a brass surface.

### Secondary
- **Oiled Walnut** (walnut-0): the sticky top bar, the primary button, a tag's hook socket.
- **Board Walnut** (walnut-1): the key board ground and the sign-in card head.
- **Tag Walnut** (walnut-2): a tag at rest, the offline pill, primary-button hover, the gauge fill.
- **Worn Walnut** (walnut-3): outlines on walnut (bar button border, hook rim).
- **Linen on Walnut** (on-walnut / on-walnut-2): primary and secondary text on walnut.

### Tertiary
- **Desk Felt** (felt): the voice desk ground.
- **Raised Felt** (felt-2): agent ledger bubbles, icon-button hover, the send button.
- **Deep Felt** (felt-deep): the mode switch track and the typed-command field.
- **Mint on Felt** (on-felt / on-felt-2): text on felt; on-felt is also the user's ledger bubble and the selected mode segment.

### Neutral
- **Plaster ramp** (plaster-0 to plaster-6): the only neutrals. plaster-0 card surfaces; plaster-1 page ground; plaster-2 card borders and gauge track; plaster-3 input and quiet-button borders; plaster-4 placeholders and hover borders; plaster-5 secondary text and section labels; plaster-6 body text.

### State
- **Alarm Red** (fire / fire-hi): the bar during fire, the alarm tag while fire is detected, the fire reading value, the Silence button.
- **Alarm Wash** (fire-bg): the fire banner and the fire card while fire is detected.

### Named Rules
**The Brass Means On Rule.** On the board and in the readings, a brass fill means exactly one thing: the device is on or open. A tag is never brass for emphasis, selection or decoration. The bell is the one brass object by material (it is the desk bell); focus, caret and selection use brass as the clerk's hand, not as state.

**The Red Is Fire Rule.** Alarm red appears only when the flame sensor reports fire (and on the Silence button that answers it). No other error, warning or offline state may use it.

**The One Ramp Rule.** Neutrals come from the seven plaster steps and nowhere else. A new grey is a new step on nobody's ramp; pick the nearest existing one.

## Typography

**Display Font:** Figtree (with system-ui, -apple-system, Segoe UI, sans-serif)
**Body Font:** Figtree
**Label Font:** Archivo Narrow (with Figtree), tracked uppercase

**Character:** Figtree is friendly and plain, the voice of a helpful clerk; Archivo Narrow in tracked caps is the stamped number on a brass key tag. Only the label face changes; everything a person reads or says is Figtree.

### Hierarchy
- **Display** (700, 2.5rem, 1.1, tabular numerals): reading values such as the garage distance; a word value ("No flame", "Flame detected") drops to 1.75rem.
- **Headline** (700, 1.375rem, 1.25): the sign-in card title only.
- **Title** (600, 1.1875rem, 1.2): the room name on a tag; the brand name in the bar runs 700 at 1.125rem.
- **Body** (400, 1rem, 1.5): inputs and running text; ledger bubbles and buttons sit at 0.9375rem. Reading notes cap at 60ch.
- **Body small** (500, 0.875rem): tag state ("Open", "Off"), section notes, board notice.
- **Label** (Archivo Narrow 600, 0.875rem, 0.12em, uppercase, plaster-5): section headings ("Key board", "Voice desk", "Garage sensor").
- **Tag number** (Archivo Narrow 600, 0.75rem, 0.14em): "No. 01" on each tag.

### Named Rules
**The Tabular Reading Rule.** Every live number (distance, RSSI in the pill) uses tabular numerals so values do not jitter as they update.

## Layout

A two-column desk at desktop: the main column (key board, then readings) at `minmax(0, 1fr)` beside a fixed 25rem voice desk, 1.5rem gap, page padding `clamp(1rem, 3vw, 2rem)`, max width 90rem. The bar is sticky at 4rem; the voice desk is sticky below it and fills the viewport height so the ledger scrolls inside it.

The key board is two rows of four equal tags (doors and modes, then lights), 1.125rem gaps. Readings sit two-up beneath it.

Responsive changes:
- At 1100px and below, one column; the voice desk moves directly after the key board (board, desk, readings) and stops being sticky; the ledger caps at 18rem.
- At 720px and below, the board goes to two tags per row with 0.75rem gaps, tags shorten to 8rem, readings stack, and the bar drops its "Front desk" subtitle.
- At 520px and below, the bar wraps and the ESP32 pill moves to its own line.

## Elevation & Depth

Hybrid, and literal. Plaster surfaces (page, reading cards) are flat with a 1px plaster-2 border. Shadows appear only on the physical objects of the desk: the walnut board, the felt desk, the brass bell, the sign-in card, and a tag that has lifted off its hook. The lift is the state: an on tag rises 4px and casts a warm brass glow.

### Shadow Vocabulary
- **Board** (`inset 0 1px 0 rgba(255,255,255,0.05), 0 10px 28px -16px rgba(42,30,22,0.6)`): the key board slab.
- **Desk** (`0 10px 28px -16px rgba(22,58,46,0.8)`): the felt voice desk.
- **Card** (`0 12px 32px -12px rgba(42,30,22,0.25)`): the sign-in card.
- **Lifted tag** (`0 12px 24px -10px rgba(236,208,138,0.55), 0 2px 4px rgba(0,0,0,0.25)`): an on tag, with `translateY(-4px)`.
- **Alarm tag** (`0 12px 24px -10px rgba(214,69,59,0.6)`): the alarm tag during fire, also lifted 4px.
- **Bell** (`0 8px 18px -6px rgba(0,0,0,0.45)`): the brass bell-mic.

### Named Rules
**The Lift Is State Rule.** A tag casts a shadow only when it is on (brass) or alarming (red). Resting tags sit flat in the board.

## Shapes

Softened rectangles throughout: 12px for slabs (board, desk, cards), 10px for tags and ledger bubbles, 8px for buttons and inputs, full round for the pill, the mode switch and the bell. Each tag carries a small round hook (0.75rem) at top centre, a walnut socket ringed in worn walnut; on an active tag the hook fills with the tag's ink. Ledger bubbles square one bottom corner to 3px on the speaker's side. Icons are 24px line drawings at 1.6 stroke, round caps and joins.

## Components

### Bar and pill
Oiled walnut, sticky, 4rem. Brand name in Figtree 700 with "Front desk" in on-walnut-2 beside it. The ESP32 pill sits right with a leading dot in currentColor: online is a dark green ground with pale green text; offline is walnut-2 with on-walnut-2. The bar's Sign out is a ghost button with a walnut-3 border that fills walnut-2 on hover. During fire the whole bar turns alarm red (240ms colour transition).

### Key-board tag (signature)
- **Shape:** 10px corners, min 9.5rem tall, equal width in a 4-column grid, hook at top centre, number, icon, room name, state line in that order.
- **Rest:** walnut-2 ground, on-walnut-2 text, room name in on-walnut. Hover warms the ground slightly and rims the hook in brass-lo.
- **On:** brass ground, on-brass text, lifted 4px with the lifted-tag shadow; hover goes to brass-hi. The state line reads "Open" or "On".
- **Pending:** a 2px dashed brass outline (3px offset) and " · sending…" appended to the state line, until the house confirms or the wait times out and a board notice explains why.
- **Alarm:** the alarm tag (No. 04) turns alarm red with white text, lifted, while fire is detected.
- **Disabled:** the alarm tag is disabled unless the buzzer is sounding; it stays at rest colours with no hover.
- **Motion:** a confirmed state change swings the tag on its hook (620ms, -4deg to 2.5deg to -1deg to rest, pivot at the hook). Every tag is a `switch`.

### Bell-mic
A 6rem round brass bell on the felt, mic icon at 2.25rem. Hover lifts 2px and brightens to brass-hi; press sinks 1px and scales to 0.98. **Listening:** a brass-hi ring expands from the bell and fades (1.6s, repeating) and the icon becomes a stop square. **Thinking:** the bell tilts side to side (±3deg, 900ms, repeating). Disabled: greyed and faded.

### Mode switch
A felt-deep pill track holding two segments (Tap to talk, Hands-free "Hey Home"). The selected segment is an on-felt pill with felt text; the other is on-felt-2 text that brightens on hover. It is a radiogroup.

### Ledger
The conversation, oldest at the top and newest at the bottom, auto-scrolled to the newest turn and capped at 40 turns. The top 1.5rem fades out so older turns read as history. User bubbles align right on on-felt with felt-deep text; agent bubbles align left on felt-2. A small 0.75rem source line ("AI", "Offline", "Said on the phone") sits under the text. Below the ledger, interim speech shows in italics, then the typed-command field (felt-deep, no border until hover) and a felt-2 send button.

### Readings cards
Plaster-0 cards with a plaster-2 border and 12px corners. Label heading, a Display value with unit in plaster-5, and a note. The garage card carries a gauge: a plaster-2 track, walnut fill, and a brass-lo mark at the 15 cm auto-open threshold. The fire card switches to the alarm wash with a red value when fire is detected.

### Fire banner
Full-width alarm wash under the bar, flame icon in alarm red, a bold "Fire detected." sentence, and the Silence buzzer button. It is a `role="alert"` and appears only during fire.

### Buttons
- **Shape:** 8px corners, 2.75rem tall, 0 1.125rem padding, Figtree 600 at 0.9375rem.
- **Primary:** walnut-0 with on-walnut text; hover walnut-2.
- **Quiet:** transparent with a plaster-3 border; hover plaster-0 with a plaster-4 border.
- **Fire:** alarm red with white text; hover fire-hi. Used only to silence the buzzer.
- **Press / disabled:** press nudges down 1px; disabled drops to 55% opacity.
- **Icon button:** 2.5rem square, transparent on felt, felt-2 on hover.

### Inputs
White field, plaster-3 border, 8px corners, 2.75rem tall; hover darkens the border to plaster-4. Focus replaces the outline with a brass-lo border and a 3px translucent brass glow. On the felt desk the field is felt-deep with no border. Global focus for everything else is a 3px brass outline at 2px offset.

## Do's and Don'ts

### Do:
- **Do** turn a tag brass (with its 4px lift) only when its device is on or open.
- **Do** keep all eight tags the same size and in the same place; show state with colour, lift and the state line.
- **Do** take every neutral from the plaster ramp (plaster-0 to plaster-6).
- **Do** append new ledger turns at the bottom and scroll to them; older turns fade at the top.
- **Do** swing a tag on its hook when its state changes, and ring the bell while listening.
- **Do** honour `prefers-reduced-motion`: animations and transitions collapse to 1ms and active tags stop lifting.
- **Do** set Archivo Narrow tracked caps only for tag numbers and section labels.

### Don't:
- **Don't** use brass as an accent, highlight, selection state or decoration on the board.
- **Don't** use alarm red for anything but fire: not for form errors, offline, or failed commands.
- **Don't** introduce greys outside the plaster ramp or a blue accent.
- **Don't** enlarge, reorder or badge a tag to show it is active.
- **Don't** put newest ledger turns at the top.
- **Don't** add motion that is not a physical response (a swing, a ring, a press).
