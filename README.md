# Nebula Strike 3D

A 3D space-combat arcade game that runs in the browser. Fly an interceptor
through an asteroid belt, break drone waves, and put down the dreadnought that
arrives every fifth wave.

No installer, no build step, no server. `index.html` and the `vendor/` folder
are all it needs, and `vendor/three.min.js` ships with the download, so it runs
completely offline.

## Play on a PC

1. Unzip the folder.
2. Double-click `index.html` (Chrome, Edge or Firefox).
3. Click **LAUNCH**, then click once in the game window to capture the mouse.

You can also just open the unzipped folder in a browser, or serve it with
`python -m http.server` if your browser is strict about local files.

## Controls

- **Mouse** — steer (click the window once to capture it; `Esc` releases)
- **W / S** — throttle up and down
- **Shift** — afterburner (drains the boost bar)
- **Q / E** — roll
- **Arrow keys** — alternative steering
- **P** or **Esc** — pause
- **M** — mute, **B** — toggle bloom
- **Enter** — start / restart

Guns fire automatically. Touch devices steer by dragging.

## Rules

- Hull at zero ends the run. Shields soak damage and recharge after four
  seconds without being hit.
- Asteroids respawn around you, so the belt never runs out. Big rocks take
  three hits, medium two, small one.
- Drones chase and shoot. The dreadnought on every fifth wave has 34 hit
  points and fires three-round bursts.

## Graphics and performance

- Physically based materials with an image-based environment map, so metal
  actually reflects the nebula.
- Instanced asteroid field (102 rocks in 3 draw calls) and instanced lasers.
- One-draw-call GPU particle system for engines, impacts and debris.
- Procedural nebula sky and a distant planet with an atmospheric rim.
- ACES tone mapping, custom bloom (bright pass + separable blur) and a vignette,
  all hand-rolled on top of three.js.
- Pixel ratio capped at 1.75, resolution auto-drops once if the frame budget is
  blown, and **B** turns bloom off for a further speed win.

The numbers are deliberately modest: an i7-8700K and a GTX 1080 Ti will hold a
locked frame rate at 1440p with bloom on. A laptop iGPU will still run it at
reduced resolution.

## Files

- `index.html` — the whole game
- `vendor/three.min.js` — three.js r149, bundled so it works offline
- `nebula-strike-2d.html` — the earlier 2D version, kept for reference
- `src/haptics.js` — haptics used only inside the FreeMilk app
