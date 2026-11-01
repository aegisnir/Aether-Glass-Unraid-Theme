# <img src="source/aether-glass.png" width="48" height="48" alt="" align="top"> Aether Glass

A deep-violet frosted-glass theme for the Unraid webGUI.

> **Unofficial.**  Aether Glass is a community theme.  It is not made, endorsed or supported by Lime Technology.  "Unraid" is a trademark of Lime Technology, Inc.

![Dashboard](screenshots/dashboard.png)

| Login | Settings |
|---|---|
| ![Login page](screenshots/login.png) | ![Settings page](screenshots/settings.png) |

<sub>Screenshots use anonymized data.</sub>

## What it changes

- **Look:** a violet aurora behind frosted-glass panels, cyan → violet → pink accents, the system font (SF Pro on Apple devices, Segoe UI on Windows).
- **Status colours:** sea green for normal, amber for warning, crimson rose for critical, with soft glows.
- **Controls:** pill buttons and fields, macOS-style toggles, a segmented glass main menu.
- **Pages covered:** every normal page, the login page, the reboot and shutdown page, and the pop-up log windows plugins open (for example a "Downloading Package" window).

It is CSS only.  It changes how pages look and nothing else: the array, Docker, VMs, shares and data are not touched.  The worst case is a page that looks wrong, and the Settings page or the kill switch puts it back to stock.

## Requirements

- Unraid **7.2 or newer**.  Tested on **7.3.4**.
- Display theme set to **Black**: `Settings → Display Settings → Dynamix color theme`.  On another theme, normal pages stay stock and only the login page is themed.

## Install

1. **Make** a flash backup first: `Main → Boot Device → Flash → Flash Backup`.
2. **Open** `Plugins → Install Plugin` and paste:

   ```
   https://raw.githubusercontent.com/aegisnir/Aether-Glass-Unraid-Theme/main/aether-glass.plg
   ```

3. **Open** `Settings → Aether Glass` and click **Approve this version and turn on**.  The theme stays off until you do.
4. **Reload** the page.  If it still looks stock, reload while holding Shift.

## Dev channel (optional)

New changes land on the `dev` branch first and are tested there before they reach `main`.  `main` is always the default: the install link above, and Community Apps.  If you'd like to try changes early, install the dev build instead:

```
https://raw.githubusercontent.com/aegisnir/Aether-Glass-Unraid-Theme/dev/aether-glass.plg
```

- It replaces your normal install (same plugin, so the two never run together) and from then on updates from `dev`.  Its version ends in `-dev`, so `Plugins` shows which channel you're on.
- Dev builds can have rough edges.  Please report them in the issues.
- To go back, install the `main` link above.  Your settings are kept.  If the dev build is newer than the current release, you stay on that version until the next release passes it.

## Settings page

`Settings → Aether Glass` shows the Unraid version, the approved version, the kill switch, whether the Display theme is Black, and which pages are themed.

| Button | Does |
|---|---|
| Approve this version and turn on | records the current Unraid version as approved and applies the theme |
| Turn off | switches the kill switch on and goes back to stock, also after reboots |
| Turn back on | switches the kill switch off and applies the theme again, if this version is approved |

### Effects

On a slower computer, trade looks for speed.  Pick a level for each effect, or pick a preset:

| Effect | Levels, lowest first |
|---|---|
| Holographic (the shimmer on titles) | still · on the tile you point at · page titles always, Dashboard tiles on hover · every title |
| Frosted glass | off (solid panels) · menus, dropdowns, dialogs and tooltips only · panels (small buttons get a plain fill) · everything |
| Glows | off · not on live bars and numbers · everywhere |

| Preset | Holographic | Frosted glass | Glows |
|---|---|---|---|
| Vivid | every title | everything | everywhere |
| **Balanced** (default) | tile you point at | everything | everywhere |
| Light | tile you point at | menus and popups | not on live bars |
| Minimal | still | off | off |

Any other mix shows as Custom.  The settings page shows the result as two rings, Visuals and Speed.

The choice is saved in `/boot/config/plugins/aether-glass/effects.cfg` and applies to everyone who opens this server's webGUI.  Each visitor's own computer still wins: if macOS or Windows is set to reduce motion or transparency, that visitor gets less of it whatever is set here.  Still CSS only: the effects are switched in the stylesheet, no script runs in the browser.

#### How the Speed ring is worked out

All 27 combinations (3 levels x 3 effects) were measured twice on the Dashboard, in random order, timing frames while idle and while the page scrolled itself.  Average for each level across the 9 combinations it appears in (run 1 / run 2):

| Level | Idle fps | Scroll fps | Stutters (frames over 50 ms) |
|---|---|---|---|
| Holographic: still | 102 / 100 | 48 / 48 | 2 / 2 |
| Holographic: on hover | 99 / 110 | 47 / 51 | 2 / 1 |
| Holographic: every title | 84 / 82 | 31 / 32 | 26 / 23 |
| Frosted glass: off | 109 / 107 | 42 / 44 | 7 / 5 |
| Frosted glass: panels | 89 / 95 | 43 / 45 | 10 / 10 |
| Frosted glass: everything | 87 / 91 | 41 / 42 | 13 / 11 |
| Glows: any level | no measurable difference | | |

So the Speed ring counts the holographic shimmer on every title as the biggest cost, frosted glass as a medium one, and glows as free.  Two levels were added after the benchmark and their cost is estimated from it, not measured: "page titles" (a few always-moving titles, against about 37 for every title) and "menus and popups" (only the menu bar's blur is always on screen, against every panel).  Scrolling topped out near 50 fps in every combination (the self-scrolling test itself is the limit), so compare the rows with each other rather than reading them as absolute speeds.

**Measured on an Apple M5 MacBook Pro, macOS 27.2, Safari 27.2, on a 120 Hz screen.  Results vary with hardware, operating system, browser and screen:** blur in particular costs more on slower graphics chips.

#### Benchmark your own computer

The Speed ring uses figures from one computer.  To measure yours, paste this into the browser console on the Dashboard: it tries the four presets and scores each one: 1 point for every frame per second, minus 1 point for every stutter.  It recommends the richest preset that scores 50 or more, which is about a smooth 60 frames a second with only a few stutters.  It takes about 1.5 minutes.  A prompt asks you to close the console (⌥⌘I on a Mac, F12 on Windows) and counts down from 5 so the test measures the whole window; please don't touch the mouse or keyboard while it runs.  It is code you run yourself, not part of the plugin, so Aether Glass stays pure CSS.  It runs only in your browser, changes nothing permanently (reload to undo) and sends nothing anywhere.  The same steps and code are on the Settings page.  Tested in Safari; Chrome and Edge use the same code.

- **Safari:** turn on Settings → Advanced → "Show features for web developers" once, then Develop → Show JavaScript Console (⌥⌘C).
- **Chrome / Edge:** ⌥⌘J on a Mac, Ctrl+Shift+J on Windows.  Type `allow pasting` the first time.

```js
// Aether Glass benchmark: tests the four Effects presets on this page and recommends one.
// Paste into the browser console on the Dashboard.  It takes about 1.5 minutes.  Please don't touch
// the mouse or keyboard while it runs: moving or scrolling yourself would throw the results off.
// It only runs in your browser, changes nothing permanently, and sends nothing anywhere.
(async () => {
  // A see-through cover over the page for the length of the test, so a resting mouse can't
  // hover a tile and start its shimmer (that would skew two of the presets).
  const shield = Object.assign(document.createElement("div"), { style:
    "position:fixed;inset:0;z-index:2147483646;cursor:wait" });
  const banner = Object.assign(document.createElement("div"), { style:
    "position:fixed;bottom:40px;left:20px;z-index:2147483647;padding:8px 16px;border-radius:99px;" +
    "background:#000;color:#fff;font:700 15px system-ui;box-shadow:0 0 0 2px #10c98f;cursor:default" });
  document.documentElement.append(shield, banner);
  let card;   // the "close the console" prompt, removed again if the test stops early
  try {
    const wait = ms => new Promise(r => setTimeout(r, ms));
    // A page can't close the browser's console itself, so ask, with that browser's keys, and
    // count down.  An open console takes part of the window and would lower the scores.
    // Option-Command-I (Mac, Safari and Chrome) and F12 (Windows) toggle the developer panel closed
    const keys = /Mac/.test(navigator.platform) ? "Option-Command-I" : "F12";
    card = Object.assign(document.createElement("div"), { style:
      "position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);z-index:2147483647;width:min(640px,90vw);padding:44px 48px;border-radius:28px;" +
      "background:rgba(24,14,4,.97);color:#ffd27a;font:700 26px/1.4 system-ui;text-align:center;" +
      "box-shadow:0 0 0 3px #f59e0b,0 0 60px rgba(245,158,11,.45),0 30px 80px rgba(0,0,0,.7)" });   // amber, so it can't be missed
    document.documentElement.append(card);
    for (let n = 5; n > 0; n--) {
      card.innerHTML = `⚠️ Please close the console now<br><span style="font-size:22px;color:#fff">${keys}, or its × button</span>` +
        `<span style="display:block;margin-top:18px;font-size:20px;font-weight:600;color:#fde7b6">The test starts in</span>` +
        `<span style="display:block;font-size:96px;line-height:1.1;color:#f59e0b">${n}</span>`;
      await wait(1000);
    }
    card.remove();
    const frames = (ms, scroll) => new Promise(done => {
      const gaps = []; const t0 = performance.now(); let last = t0;
      const max = Math.max(0, document.documentElement.scrollHeight - innerHeight);
      const tick = t => { gaps.push(t - last); last = t; const p = (t - t0) / ms;
        if (scroll) scrollTo(0, max * (p < .5 ? p * 2 : 2 - p * 2)); p < 1 ? requestAnimationFrame(tick) : done(gaps); };
      requestAnimationFrame(tick);
    });
    const fps = a => a.length / (a.reduce((x, y) => x + y, 0) / 1000);
    // The theme's Effects rules, found by the names in their conditions
    const rules = [];
    for (const sh of document.styleSheets) { let rs; try { rs = sh.cssRules; } catch (e) { continue; }
      for (const r of rs) if (r instanceof CSSMediaRule && /aether-(motion|glass|glow)-|prefers-reduced-(motion|transparency)/.test(r.media.mediaText))
        rules.push({ r, orig: r.media.mediaText }); }
    if (!rules.some(x => x.orig.includes("aether-motion-everywhere"))) throw new Error("Aether Glass isn't active on this page (or is an older version)");
    // Switch the rules to one mix of levels, in this tab only
    const set = (m, g, w) => { for (const { r, orig } of rules) { const has = n => orig.includes(n);
      const on = has("prefers-reduced-motion") ? m === "still" : has("prefers-reduced-transparency") ? g === "off"
        : has("aether-motion-everywhere") ? m === "everywhere" : has("aether-motion-titles") ? m === "titles"
        : has("aether-glass-panels") ? g === "panels" : has("aether-glass-menus") ? g === "menus"
        : (has("aether-glow-static") && w === "static") || (has("aether-glow-off") && w === "off");
      r.media.mediaText = on ? "all" : "not all"; } };
    const presets = { Vivid: ["everywhere", "all", "all"], Balanced: ["hover", "all", "all"],
                      Light: ["hover", "menus", "static"], Minimal: ["still", "off", "off"] };
    const res = {};
    for (const round of [1, 2]) {
      const order = Object.keys(presets);   // shuffled (Fisher-Yates), so no preset always runs first
      for (let i = order.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [order[i], order[j]] = [order[j], order[i]]; }
      for (const name of order) {
        banner.textContent = `Testing ${name} (round ${round} of 2)…  Please don't touch the mouse or keyboard.`;
        set(...presets[name]); await wait(1000);
        const idle = await frames(3000, false), scroll = await frames(4000, true);
        (res[name] ||= []).push({ idle: fps(idle), scroll: fps(scroll), slow: [...idle, ...scroll].filter(x => x > 50).length });
        scrollTo(0, 0); await wait(400);
      }
    }
    for (const x of rules) x.r.media.mediaText = x.orig;   // back to how the page loaded
    shield.remove();
    // Score: 1 point per frame per second while idle, with no ceiling, so 144 Hz and faster
    // screens show their real differences (the self-scrolling part caps near 50 fps on every
    // preset, so it only counts toward stutters), minus 1 point for every
    // stutter (a frame that took longer than 50 ms, idle or scrolling).  The richest preset that
    // scores 50 or more is recommended: about a smooth 60 frames a second with only a few stutters.
    const avg = (r, k) => r.reduce((s, x) => s + x[k], 0) / r.length;
    const stats = {}, table = {};
    for (const name of Object.keys(presets)) { const r = res[name];
      const idle = avg(r, "idle"), stutters = Math.round(avg(r, "slow"));
      stats[name] = { score: Math.round(idle - stutters) };
      table[name] = { score: stats[name].score, "idle fps": +idle.toFixed(1), "scroll fps": +avg(r, "scroll").toFixed(1), stutters };
    }
    console.table(table);
    const pick = ["Vivid", "Balanced", "Light"].find(n => stats[n].score >= 50) || "Minimal";
    const note = stats.Minimal.score < 50 ? "  Even Minimal scores under 50 here, so this computer may find the theme heavy." : "";
    // Results card in the middle of the screen: violet, with the recommendation in green
    banner.remove();
    const top = Math.max(1, ...Object.values(table).map(t => t.score));   // bars scale to the best score in this run
    const row = n => { const t = table[n], best = n === pick, w = Math.max(0, t.score / top * 100);
      return `<tr style="${best ? "color:#4ade9c;font-weight:800" : ""}">` +
        `<td style="background:transparent;border:0;padding:8px 14px 8px 0;text-align:left">${best ? "✓ " : ""}${n}</td>` +
        `<td style="background:transparent;border:0;padding:8px 14px;min-width:170px"><div style="height:10px;border-radius:99px;background:rgba(124,92,255,.25)">` +
        `<div style="height:100%;width:${w}%;border-radius:99px;background:${best ? "#10c98f" : "linear-gradient(90deg,#00e5ff,#7c5cff)"}"></div></div></td>` +
        `<td style="background:transparent;border:0;padding:8px 14px;text-align:right;font-size:22px">${t.score}</td>` +
        `<td style="background:transparent;border:0;padding:8px 14px;text-align:right;color:${best ? "#4ade9c" : "#b4bad6"}">${Math.round(t["idle fps"])} fps</td>` +
        `<td style="background:transparent;border:0;padding:8px 0 8px 14px;text-align:right;color:${best ? "#4ade9c" : "#b4bad6"}">${t.stutters} stutters</td></tr>`; };
    const results = Object.assign(document.createElement("div"), { style:
      "position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);z-index:2147483647;width:min(720px,92vw);padding:36px 40px;border-radius:28px;" +
      "background:rgba(20,12,46,.97);color:#e6ebf7;font:600 17px/1.4 system-ui;text-align:center;" +
      "box-shadow:0 0 0 3px #7c5cff,0 0 60px rgba(124,92,255,.45),0 30px 80px rgba(0,0,0,.7)" });
    results.innerHTML =
      `<div style="font-size:15px;letter-spacing:.12em;text-transform:uppercase;color:#cdb9ff">Aether Glass benchmark</div>` +
      `<div style="margin:10px 0 4px;font-size:30px;font-weight:800;color:#4ade9c">Recommended: ${pick}</div>` +
      `<div style="font-size:15px;font-weight:500;color:#b4bad6">Set it in Settings → Aether Glass → Effects.</div>` +
      (note ? `<div style="margin-top:10px;font-size:15px;font-weight:500;color:#ffd27a">${note.trim()}</div>` : "") +
      `<table style="margin:22px auto 10px;border-collapse:separate;border-spacing:0;border-radius:18px;overflow:hidden;` +
      `padding:8px 20px;background:rgba(8,5,26,.6);box-shadow:inset 0 0 0 1px rgba(200,190,255,.14);font-size:17px">${["Vivid", "Balanced", "Light", "Minimal"].map(row).join("")}</table>` +
      `<div style="font-size:13px;font-weight:500;color:#8b95b5">Score = frames per second minus 1 per stutter.  50 or more is recommended.</div>` +
      // Two buttons: one goes straight to the Aether Glass settings page to apply the pick,
      // the quieter one just closes the card and stays on the Dashboard
      `<div style="margin-top:22px;display:flex;gap:12px;justify-content:center">` +
      `<button data-go style="padding:10px 28px;border:0;border-radius:99px;font:700 16px system-ui;color:#fff;cursor:pointer;` +
      `background:linear-gradient(180deg,#9a82ff,#7354f0 55%,#5534c9)">Open settings</button>` +
      `<button data-close style="padding:10px 22px;border:0;border-radius:99px;font:600 16px system-ui;color:#cdb9ff;cursor:pointer;` +
      `background:transparent;box-shadow:inset 0 0 0 1px rgba(205,185,255,.35)">Close</button></div>`;
    results.querySelector("[data-go]").onclick = () => { location.href = "/Settings/AetherGlass"; };
    results.querySelector("[data-close]").onclick = () => results.remove();
    document.documentElement.append(results);
    console.log(`%cRecommended preset for this computer: ${pick}`, "font-weight:bold;font-size:15px;color:#10c98f");
    console.log(Object.entries(table).map(([n, t]) => `${n}: ${t.score} points (${Math.round(t["idle fps"])} fps, ${t.stutters} stutters)`).join("\n"));
  } catch (err) { shield.remove(); card?.remove(); banner.textContent = "Benchmark stopped: " + err.message; console.error(err); }
})();
```

## Safety features

- **Pauses after Unraid updates.**  The theme only loads on the Unraid version you approved.  After an update it stays off, a notification says so, and you check the stock pages before approving the new version.  A webGUI change in a new release can't leave you with a broken-looking UI you didn't choose.
- **Kill switch.**  If the file `config/plugins/aether-glass/DISABLED` exists on the flash drive, the theme never loads.  It works even with the flash drive plugged into another computer.
- **Exact restore.**  Before changing anything, the plugin saves untouched copies of Unraid's original files in memory.  Turning the theme off or uninstalling copies them back byte for byte.
- **Nothing on the flash drive changes.**  The theme is added to the copies of the webGUI files that Unraid loads into memory at boot.  Unraid's own files on the flash drive are never edited, so every boot starts from stock.
- **Downloads are verified.**  Each file the plugin downloads is checked against a SHA256 fingerprint in the `.plg`.  A file that doesn't match is refused.

## Uninstall

`Plugins → Installed Plugins → Aether Glass → Remove`.  The webGUI goes back to stock right away, and the plugin deletes its own files from the flash drive and from memory.

## If the webGUI won't load

This should never happen from a CSS theme, but just in case:

1. **Shut down** the server and plug the flash drive into another computer.
2. **Create** an empty file named `DISABLED` in `config/plugins/aether-glass/`.
3. **Put** the flash drive back and boot.  The theme won't load.  Delete the file later to allow it again.

## Compatibility

| Tested with | Version |
|---|---|
| Unraid | 7.3.4 |
| Community Applications | 2026.07.21 |

The theme also styles a few popular plugins.  Those rules only match when the plugin is installed and do nothing otherwise:

- **Community Applications:** the Apps page cards, side panel and spotlight.
- **Dynamix System Buttons:** the header power button and its menu icon.
- **FolderView3:** folder boxes and dropdowns on the Docker and VMs pages.
- **Nvidia Driver** and other plugins that open a pop-up log window: the window is themed.

**Known conflicts:**

- **Custom WebUI CSS** (or any plugin that adds its own CSS) loads after this theme and wins.  Clear it out if something looks half-themed.
- **Other theme plugins** that change the same stylesheets.  Use one theme plugin at a time.

**Browsers:** current Safari, Chrome, Edge and Firefox.  Dropdown menus in Safari are drawn by macOS, so their highlight follows the system accent colour.

## How it works

Unraid unpacks its webGUI into memory at every boot and reinstalls plugins from `/boot/config/plugins/`.  At each boot this plugin:

1. Checks that this Unraid version is approved and the kill switch is off.
2. Saves untouched copies of three webGUI files in `/tmp`.
3. Switches on the Effects levels you picked (in the copy it installs; the theme file itself is not changed).
4. Appends the theme to `themes/black.css` (normal pages) and `default-cases.css` (the login page, which loads no other stylesheet), and inserts a `<style>` block into `logging.htm` (the pop-up log window).  Each addition sits between `AETHER-GLASS-START` and `AETHER-GLASS-END` markers.

Results go to the system log under the tag `aether-glass`:

```bash
grep aether-glass /var/log/syslog
```

## For maintainers: releasing

Two channels, chosen by the branch you're on.  `tools/release.sh` sets the update link in the `.plg` to match and adds `-dev` to dev versions.  Both channels download files from the version's tag: a new tag is an address GitHub hasn't cached, so a build installs as soon as it's pushed.

One-time setup per clone, so the push guard below runs (GitHub Desktop runs it too):

```
git config core.hooksPath tools/hooks
```

**Dev build** (on `dev`)
1. **Edit** files in `source/`.
2. **Run** `tools/release.sh 2026.11.02`.  The `.plg` becomes `2026.11.02-dev`, updating from the `dev` branch.
3. **Add** a line under `<CHANGES>` in the `.plg`.
4. **Commit**, **tag** it `2026.11.02-dev` before pushing, then **push** `dev` and the tag.

**Release** (to everyone)
1. **Merge** `dev` into `main`.
2. **Run** `tools/release.sh 2026.11.02` on `main`.  It refuses to keep a `-dev` version and points the update link back at `main`.
3. **Commit**, then **tag** that commit with the same version **before pushing**: `git tag 2026.11.02`.  The `.plg` downloads its files from that tag, so a release pushed without it fails to install.
4. **Push** the commit and the tag: `git push && git push --tags`.
5. **Check** the tag is on GitHub and each file in the `.plg` downloads with a matching SHA256.
6. **Merge** `main` back into `dev`, then run `tools/release.sh` on `dev` so it's a dev build again.

The push guard (`tools/hooks/pre-push`) stops a push to `main` while its `.plg` still has a `-dev` version or the `dev` update link.  That's the one mistake that would move every user onto the testing channel.

Changes that don't touch `source/` or the `.plg` (README, screenshots, tools) need no new version and no tag.

## License

MIT, see [LICENSE](LICENSE).  No Lime Technology artwork is included: the header wordmark is recoloured using a mask of the logo file already on your server.
