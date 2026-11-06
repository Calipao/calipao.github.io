// The night city seen through the window: low-poly buildings with lit windows
// at real distances behind the wall, so they shift against each other as the
// camera moves, in front of a sky with a moon and a glowing horizon.
//
// Everything out here is unlit (MeshBasicMaterial) and ignores the room's fog,
// which is tuned for the desk. Distance is suggested by dimming instead.
import * as THREE from "three";

const STREET_Y = -40; // the room is about 13 floors up
const SKY_Z = -280;

function rng(seed) {
  return () => {
    seed = (seed * 16807) % 2147483647;
    return (seed - 1) / 2147483646;
  };
}

function canvasTexture(w, h, draw) {
  const c = document.createElement("canvas");
  c.width = w;
  c.height = h;
  draw(c.getContext("2d"), w, h);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

// A facade of 8 x 16 windows. Repeated across each building face.
const FACADE_COLS = 8;
const FACADE_ROWS = 16;
const WINDOW_W = 2.2; // metres per window column
const WINDOW_H = 3.1; // metres per floor

function facadeTexture(seed, wall, lit) {
  const r = rng(seed);
  const tex = canvasTexture(256, 512, (g, w, h) => {
    g.fillStyle = wall;
    g.fillRect(0, 0, w, h);
    const cw = w / FACADE_COLS;
    const ch = h / FACADE_ROWS;
    for (let y = 0; y < FACADE_ROWS; y++) {
      for (let x = 0; x < FACADE_COLS; x++) {
        const roll = r();
        g.fillStyle = roll < lit * 0.8 ? "#f3c96b" : roll < lit ? "#a9d4ff" : roll < lit + 0.08 ? "#2a2f3d" : "#141926";
        g.fillRect(x * cw + cw * 0.18, y * ch + ch * 0.2, cw * 0.64, ch * 0.55);
      }
    }
  });
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.anisotropy = 4;
  return tex;
}

function skyTexture() {
  return canvasTexture(512, 512, (g, w, h) => {
    const grad = g.createLinearGradient(0, 0, 0, h);
    grad.addColorStop(0, "#03050d");
    grad.addColorStop(0.45, "#0b1226");
    grad.addColorStop(0.62, "#24294a");
    grad.addColorStop(0.7, "#4a3b52"); // city glow at the horizon
    grad.addColorStop(0.78, "#1a1a2a");
    grad.addColorStop(1, "#0a0b12");
    g.fillStyle = grad;
    g.fillRect(0, 0, w, h);
    const r = rng(11);
    for (let i = 0; i < 260; i++) {
      const y = r() * h * 0.55;
      g.fillStyle = `rgba(255,255,255,${0.25 + r() * 0.65 * (1 - y / (h * 0.55))})`;
      const s = r() > 0.94 ? 2 : 1;
      g.fillRect(r() * w, y, s, s);
    }
  });
}

function moonTexture() {
  return canvasTexture(256, 256, (g, w, h) => {
    const halo = g.createRadialGradient(w / 2, h / 2, 20, w / 2, h / 2, w / 2);
    halo.addColorStop(0, "rgba(233,237,216,0.35)");
    halo.addColorStop(1, "rgba(233,237,216,0)");
    g.fillStyle = halo;
    g.fillRect(0, 0, w, h);
    g.fillStyle = "#eef0dc";
    g.beginPath();
    g.arc(w / 2, h / 2, 36, 0, Math.PI * 2);
    g.fill();
    g.fillStyle = "rgba(170,175,160,0.35)";
    for (const [x, y, s] of [[-10, -8, 9], [12, 6, 7], [-2, 14, 5], [14, -14, 4]]) {
      g.beginPath();
      g.arc(w / 2 + x, h / 2 + y, s, 0, Math.PI * 2);
      g.fill();
    }
  });
}

// ---------- flickering windows ----------
//
// A single instanced mesh of small panels laid exactly over real windows on
// the street-facing facades. Each panel is lit or dark and now and then
// flickers, switches, or (for a few) glows like a TV. Only these panels
// change, so the shared facade textures stay untouched.

const LIT_WARM = new THREE.Color("#f3c96b");
const LIT_COOL = new THREE.Color("#a9d4ff");
const UNLIT = new THREE.Color("#141926");
const TV = new THREE.Color("#7fa6ff");

function flickeringWindows(city, fronts, r) {
  const near = fronts.filter((f) => f.distance <= 150 && f.w > 4 && f.h > 6);
  const count = near.length ? 160 : 0;
  const mesh = new THREE.InstancedMesh(
    new THREE.PlaneGeometry(1, 1),
    new THREE.MeshBasicMaterial({ fog: false }),
    count
  );
  const dummy = new THREE.Object3D();
  const panels = [];

  // Most panels go where they can be seen: inside the view through the
  // window from the default camera (widened a little for orbiting).
  const eye = new THREE.Vector3(0, 1.4, 1.75);
  function inView(x, y, z) {
    const t = (eye.z - z) / (eye.z + 0.7); // distance scale from eye to window plane
    return x > eye.x + (0.45 - 0.35) * t && x < eye.x + (1.45 + 0.35) * t &&
      y > eye.y + (1.04 - eye.y) * t && y < eye.y + (1.8 - eye.y) * t;
  }

  for (let i = 0; i < count; i++) {
    const wantVisible = i < count * 0.8;
    let f = null;
    let pos = null;
    for (let attempt = 0; attempt < 40 && !pos; attempt++) {
      f = near[Math.floor(r() * near.length)];
      pos = pickCell(f);
      if (pos && wantVisible && !inView(pos.x, pos.y, f.z)) pos = null;
    }
    if (!pos) { panels.push(null); continue; }
    dummy.position.set(pos.x, pos.y, f.z + 0.08);
    dummy.scale.set(WINDOW_W * 0.64 * 1.08, WINDOW_H * 0.55 * 1.08, 1);
    dummy.updateMatrix();
    mesh.setMatrixAt(i, dummy.matrix);
    addPanel(f);
  }

  // Picks a window cell on a facade in its tile space and converts it back to
  // a position on the face. Texture cells: 8 columns x 16 rows per tile; the
  // lit rectangle of a cell spans 18-82% across and 25-80% up.
  function pickCell(f) {
    // Pick a window cell in the face's tile space and convert it back to a
    // position on the face. Texture cells: 8 columns x 16 rows per tile;
    // the lit rectangle of a cell spans 18-82% across and 25-80% up.
    const colMin = Math.ceil(f.ox * FACADE_COLS);
    const colMax = Math.floor((f.ox + f.rx) * FACADE_COLS) - 1;
    const rowMin = Math.ceil(f.oy * FACADE_ROWS);
    const rowMax = Math.floor((f.oy + f.ry) * FACADE_ROWS) - 1;
    if (colMax < colMin || rowMax < rowMin + 1) return null;
    const col = colMin + Math.floor(r() * (colMax - colMin + 1));
    const row = rowMin + 1 + Math.floor(r() * (rowMax - rowMin)); // skip the street-level row
    const u = ((col + 0.5) / FACADE_COLS - f.ox) / f.rx;
    const v = ((row + 0.525) / FACADE_ROWS - f.oy) / f.ry;
    return { x: f.x0 + u * f.w, y: f.y0 + v * f.h };
  }

  // Kinds: most lights change rarely (a flicker or a switch every 45-150 s),
  // a few faulty ones flicker every 6-25 s, and a few windows glow like a TV.
  function addPanel(f) {
    const roll = r();
    const kind = roll < 0.07 ? "tv" : roll < 0.12 ? "faulty" : "light";
    const lit = (r() < 0.85 ? LIT_WARM : LIT_COOL).clone().multiply(f.tint);
    panels.push({
      kind,
      lit,
      dark: UNLIT.clone().multiply(f.tint),
      tv: TV.clone().multiply(f.tint),
      on: kind === "faulty" || r() < 0.6,
      next: interval(kind) * r(), // ms until its first event
      until: 0, // end of the current flicker burst
      settleTo: null, // state to switch to after a burst
      phase: r() * 1000,
      shown: null,
    });
  }

  function interval(kind) {
    return kind === "faulty" ? 6000 + r() * 19000 : 45000 + r() * 105000;
  }
  // Hide unused slots.
  dummy.scale.set(0, 0, 0);
  dummy.updateMatrix();
  panels.forEach((p, i) => { if (!p) mesh.setMatrixAt(i, dummy.matrix); });
  mesh.instanceMatrix.needsUpdate = true;
  for (let i = 0; i < count; i++) mesh.setColorAt(i, UNLIT);
  city.add(mesh);

  const tmp = new THREE.Color();
  let started = null;
  return (now) => {
    if (started === null) started = now;
    const t = now - started;
    let changed = false;
    panels.forEach((p, i) => {
      if (!p) return;
      if (t >= p.next) {
        if (p.kind !== "tv") {
          // A short stutter; for ordinary lights, half the time it ends with
          // the light switched on or off.
          p.until = t + 250 + r() * 900;
          p.settleTo = p.kind === "light" && r() < 0.5 ? !p.on : null;
        }
        p.next = t + interval(p.kind);
      }
      let key;
      if (p.kind === "tv") {
        // Uneven bluish pulsing, like a screen in a dark room.
        const k = 0.45 + 0.35 * Math.sin((t + p.phase) / 170) * Math.sin((t + p.phase) / 410) + 0.2 * Math.sin((t + p.phase) / 53);
        tmp.copy(p.dark).lerp(p.tv, Math.max(0, Math.min(1, k)));
        mesh.setColorAt(i, tmp);
        changed = true;
        return;
      }
      if (t < p.until) {
        key = Math.floor((t + p.phase) / 70) % 3 === 0 ? !p.on : p.on; // stutter
        if (Math.sin((t + p.phase) * 0.9) > 0.6) key = !key;
      } else {
        if (p.settleTo !== null) { p.on = p.settleTo; p.settleTo = null; }
        key = p.on;
      }
      if (key !== p.shown) {
        p.shown = key;
        mesh.setColorAt(i, key ? p.lit : p.dark);
        changed = true;
      }
    });
    if (changed) mesh.instanceColor.needsUpdate = true;
  };
}

export function buildCity(scene) {
  const city = new THREE.Group();
  city.name = "city";
  const animated = [];
  const r = rng(2024);

  // Sky and moon.
  const sky = new THREE.Mesh(
    new THREE.PlaneGeometry(900, 360),
    new THREE.MeshBasicMaterial({ map: skyTexture(), fog: false })
  );
  sky.position.set(100, 40, SKY_Z);
  city.add(sky);
  const moon = new THREE.Mesh(
    new THREE.PlaneGeometry(34, 34),
    new THREE.MeshBasicMaterial({ map: moonTexture(), transparent: true, depthWrite: false, fog: false, toneMapped: false })
  );
  moon.position.set(135, 36, SKY_Z + 2);
  city.add(moon);

  // A dark ground far below so gaps between buildings never show the sky.
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(900, 280), new THREE.MeshBasicMaterial({ color: "#07080d", fog: false }));
  ground.rotation.x = -Math.PI / 2;
  ground.position.set(100, STREET_Y, -140);
  city.add(ground);

  // The whole city is merged into a handful of meshes (one per facade
  // texture, plus one for roofs and rooftop details) so it costs only a few
  // draw calls. Per-building dimming lives in vertex colours, and window
  // tiling in the UVs.
  const facades = [
    facadeTexture(1, "#0e1322", 0.32),
    facadeTexture(2, "#121625", 0.22),
    facadeTexture(3, "#0b0f1b", 0.42),
    facadeTexture(4, "#151a24", 0.18),
  ];
  const batches = facades.map(() => ({ pos: [], uv: [], col: [] }));
  const dark = { pos: [], uv: [], col: [] };
  const DARK = new THREE.Color("#0c0e16");
  const ROOF = new THREE.Color("#090b12");
  const move = new THREE.Matrix4();

  // Adds any geometry, moved to (x, y, z), to the dark batch.
  function addDark(geometry, x, y, z) {
    const g = geometry.index ? geometry.toNonIndexed() : geometry;
    g.applyMatrix4(move.makeTranslation(x, y, z));
    const p = g.attributes.position.array;
    for (let i = 0; i < p.length; i += 3) {
      dark.pos.push(p[i], p[i + 1], p[i + 2]);
      dark.uv.push(0, 0);
      dark.col.push(DARK.r, DARK.g, DARK.b);
    }
  }

  // Adds a box: walls go to the facade batch with tiled window UVs, the
  // top and bottom go to the dark batch.
  const fronts = []; // street-facing (+z) facades, for the flickering windows
  function addBox(texIndex, w, h, d, x, y, z, tint, distance) {
    const g = new THREE.BoxGeometry(w, h, d).toNonIndexed();
    g.applyMatrix4(move.makeTranslation(x, y, z));
    const p = g.attributes.position.array;
    const u = g.attributes.uv.array;
    const ry = h / (FACADE_ROWS * WINDOW_H);
    // Non-indexed box: 6 faces of 6 vertices, in order +x, -x, +y, -y, +z, -z.
    for (let f = 0; f < 6; f++) {
      const roof = f === 2 || f === 3;
      const batch = roof ? dark : batches[texIndex];
      const color = roof ? ROOF : tint;
      const rx = (f < 2 ? d : w) / (FACADE_COLS * WINDOW_W);
      const ox = Math.floor(r() * FACADE_COLS) / FACADE_COLS;
      const oy = Math.floor(r() * FACADE_ROWS) / FACADE_ROWS;
      if (f === 4) fronts.push({ x0: x - w / 2, y0: y - h / 2, w, h, z: z + d / 2, rx, ry, ox, oy, tint, distance });
      for (let v = f * 6; v < f * 6 + 6; v++) {
        batch.pos.push(p[v * 3], p[v * 3 + 1], p[v * 3 + 2]);
        batch.uv.push(u[v * 2] * rx + ox, u[v * 2 + 1] * ry + oy);
        batch.col.push(color.r, color.g, color.b);
      }
    }
  }

  function building(x, z, w, d, topY, distance) {
    const h = topY - STREET_Y;
    // Farther buildings are dimmer and slightly bluer.
    const k = THREE.MathUtils.smoothstep(distance, 40, 225);
    const tint = new THREE.Color(1 - k * 0.55, 1 - k * 0.5, 1 - k * 0.38);
    const tex = Math.floor(r() * facades.length);
    addBox(tex, w, h, d, x, STREET_Y + h / 2, z, tint, distance);

    let roofY = topY;
    const roll = r();
    if (roll < 0.25 && w > 16) {
      // Setback: a narrower block on top.
      const sw = w * (0.5 + r() * 0.2);
      const sd = d * (0.5 + r() * 0.2);
      const sh = 8 + r() * 14;
      addBox(tex, sw, sh, sd, x + (r() - 0.5) * (w - sw), topY + sh / 2, z, tint, distance);
      roofY = topY + sh;
    } else if (roll < 0.55) {
      // Water tank on legs.
      const tx = x + (r() - 0.5) * w * 0.5;
      const tz = z + (r() - 0.5) * d * 0.5;
      addDark(new THREE.CylinderGeometry(2.4, 2.4, 4.5, 10), tx, topY + 5.5, tz);
      addDark(new THREE.ConeGeometry(2.6, 1.8, 10), tx, topY + 8.6, tz);
      addDark(new THREE.BoxGeometry(3.4, 3.3, 3.4), tx, topY + 1.65, tz);
    } else if (roll < 0.7) {
      // Rooftop unit.
      addDark(new THREE.BoxGeometry(w * 0.3, 3, d * 0.3), x + (r() - 0.5) * w * 0.4, topY + 1.5, z);
    }
    return { x, z, roofY };
  }

  // Rows of buildings at increasing distance behind the window (the wall is
  // at z = -0.62). From the default camera the line of sight through the
  // window drifts right with distance, so the lane kept low for a clear view
  // follows it. Near rows stay below eye level; far rows rise into a skyline.
  const placed = [];
  const rows = [45, 62, 85, 110, 140, 175, 215];
  rows.forEach((dist) => {
    const z = -0.62 - dist;
    const viewX = 0.95 + dist * 0.37; // where the default line of sight lands
    const span = 15 + dist * 1.05;
    let x = viewX - span + r() * 8;
    while (x < viewX + span) {
      const w = 12 + r() * 18;
      const d = 12 + r() * 14;
      // The eye is level with the middle of the window (about y = 1.4), so
      // most roofs sit a little above or below that line and the sky fills
      // the top of the window. A few towers break the skyline.
      const lo = STREET_Y + 12 + dist * 0.1;
      let hi = r() < 0.12 ? 1.4 + dist * 0.3 : 1.4 + dist * 0.09;
      const inLane = x < viewX + dist * 0.3 && x + w > viewX - dist * 0.3;
      if (dist < 100 && inLane) hi = Math.min(hi, 0.5 - dist * 0.15);
      const topY = lo + r() * Math.max(2, hi - lo);
      placed.push(building(x + w / 2, z - r() * 8, w, d, topY, dist));
      x += w + 3 + r() * 9;
    }
  });

  // Antennas with blinking red beacons on the tallest buildings.
  const beacons = [];
  const beaconMat = new THREE.MeshBasicMaterial({ color: "#ff3b30", fog: false, toneMapped: false });
  placed
    .slice()
    .sort((a, b) => b.roofY - a.roofY)
    .slice(0, 4)
    .forEach((b, i) => {
      const mastH = 10 + r() * 12;
      addDark(new THREE.CylinderGeometry(0.3, 0.5, mastH, 6), b.x, b.roofY + mastH / 2, b.z);
      const beacon = new THREE.Mesh(new THREE.SphereGeometry(1.1, 8, 6), beaconMat.clone());
      beacon.position.set(b.x, b.roofY + mastH + 0.6, b.z);
      beacon.userData.phase = i * 0.37;
      city.add(beacon);
      beacons.push(beacon);
    });
  animated.push((now) => {
    for (const b of beacons) {
      const t = (now / 1600 + b.userData.phase) % 1;
      b.visible = t < 0.18;
    }
  });

  function finish(batch, map) {
    if (!batch.pos.length) return;
    const g = new THREE.BufferGeometry();
    g.setAttribute("position", new THREE.Float32BufferAttribute(batch.pos, 3));
    g.setAttribute("uv", new THREE.Float32BufferAttribute(batch.uv, 2));
    g.setAttribute("color", new THREE.Float32BufferAttribute(batch.col, 3));
    g.computeBoundingSphere();
    city.add(new THREE.Mesh(g, new THREE.MeshBasicMaterial({ map, vertexColors: true, fog: false })));
  }
  batches.forEach((batch, i) => finish(batch, facades[i]));
  animated.push(flickeringWindows(city, fronts, r));
  finish(dark, null);

  scene.add(city);
  return { animated };
}
