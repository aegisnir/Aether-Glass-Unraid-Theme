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
