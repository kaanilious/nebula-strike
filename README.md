# Nebula Strike

A small arcade space shooter. One HTML file, no build step, no dependencies.

## Play it

Open `index.html` in any modern browser (Chrome, Edge, Firefox, Safari).

**Controls**

- Move: arrow keys or `A` / `D`, or move the mouse / drag a finger
- Guns fire on their own
- `P` or `Esc` pauses, `M` mutes
- `Enter` or `Space` starts and restarts

Asteroids drift down toward your ship. Shoot them before they reach you or slip
past the bottom edge — either one costs a life, and you have three. Rocks take
one hit, darts are fast and fragile, and the big hexagonal tanks take three.
Every 18 seconds the wave goes up and things get faster.

## Getting it onto a PC

The preview link (`...--preview.freemilk.app`) is **private on purpose**: only the
person signed in to FreeMilk can open it, which is why a PC browser shows
"This preview is private." Two ways around that:

1. **Go Live** (fastest, no download) — in the app, open the project's details
   (the project icon, top left of the chat) and tap **Go Live**. The game then
   sits at the site's own public link, e.g. `nebula-strike-4k1o.freemilk.app`,
   and opens in any browser, on any device, for anyone.
2. **Get the files** — push the repository to GitHub, then on the PC either
   `git clone` it or use the green *Code* button → *Download ZIP* and unpack it.
   Double-click `index.html`.

`index.html` also works entirely on its own if you copy just that one file across
(email, cloud storage, USB): it loads the haptics module only when it is running
inside the FreeMilk app and otherwise starts without it. No build step, no server.

## Files

- `index.html` — the whole game: markup, styles, canvas rendering and game loop
- `src/haptics.js` — haptic effect definitions, used only inside the FreeMilk app
