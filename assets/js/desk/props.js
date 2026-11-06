// Builds the desk scene from simple low-poly shapes, so the page needs no model files.
import * as THREE from "three";
import { RoundedBoxGeometry } from "three/addons/geometries/RoundedBoxGeometry.js";

const DESK_Y = 0.75; // height of the desk surface

function mat(color, opts = {}) {
  return new THREE.MeshStandardMaterial({ color, roughness: 0.75, metalness: 0.05, ...opts });
}

function mesh(geometry, material, { cast = true, receive = true } = {}) {
  const m = new THREE.Mesh(geometry, material);
  m.castShadow = cast;
  m.receiveShadow = receive;
  return m;
}

// Seeded random so the skyline looks the same on every visit.
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
  t.anisotropy = 4;
  return t;
}

function fitText(g, text, maxWidth, size, weight = "bold") {
  let s = size;
  do {
    g.font = `${weight} ${s}px "DejaVu Sans Mono", Menlo, Consolas, monospace`;
    s -= 1;
  } while (g.measureText(text).width > maxWidth && s > 8);
}

function wrapWords(g, text, maxWidth, maxLines) {
  const words = String(text).split(/\s+/);
  const lines = [];
  let line = "";
  for (const w of words) {
    const test = line ? line + " " + w : w;
    if (g.measureText(test).width > maxWidth && line) {
      lines.push(line);
      line = w;
      if (lines.length === maxLines) break;
    } else line = test;
  }
  if (lines.length < maxLines && line) lines.push(line);
  return lines;
}

const CART_COLORS = ["#3b6e9e", "#9e3b4f", "#3b9e6a", "#9e7a3b", "#6a3b9e", "#3b8e9e", "#9e5a3b", "#5a5a5a"];

export function buildDesk(scene, { data, screenTexture }) {
  const interactive = [];
  const animated = [];

  // ---------- room ----------
  const floor = mesh(new THREE.PlaneGeometry(12, 12), mat("#15181a", { roughness: 0.95 }), { cast: false });
  floor.rotation.x = -Math.PI / 2;
  scene.add(floor);

  const wall = mesh(new THREE.PlaneGeometry(12, 5), mat("#1f2a26", { roughness: 0.95 }), { cast: false });
  wall.position.set(0, 2.5, -0.62);
  scene.add(wall);

  // Window with a night skyline.
  const skyline = canvasTexture(512, 400, (g, w, h) => {
    const sky = g.createLinearGradient(0, 0, 0, h);
    sky.addColorStop(0, "#050816");
    sky.addColorStop(1, "#1b2440");
    g.fillStyle = sky;
    g.fillRect(0, 0, w, h);
    g.fillStyle = "#e9edd8";
    g.beginPath();
    g.arc(w * 0.78, h * 0.2, 22, 0, Math.PI * 2);
    g.fill();
    const r = rng(42);
    for (let i = 0; i < 60; i++) {
      g.fillStyle = `rgba(255,255,255,${0.3 + r() * 0.6})`;
      g.fillRect(r() * w, r() * h * 0.5, 1.5, 1.5);
    }
    let x = 0;
    while (x < w) {
      const bw = 30 + r() * 50;
      const bh = h * (0.25 + r() * 0.5);
      g.fillStyle = r() > 0.5 ? "#0b0f1a" : "#10162a";
      g.fillRect(x, h - bh, bw, bh);
      for (let wy = h - bh + 8; wy < h - 6; wy += 12) {
        for (let wx = x + 5; wx < x + bw - 6; wx += 9) {
          if (r() > 0.68) {
            g.fillStyle = r() > 0.2 ? "#f5d27a" : "#9fd3ff";
            g.fillRect(wx, wy, 4, 6);
          }
        }
      }
      x += bw + 2;
    }
  });
  const windowGroup = new THREE.Group();
  const glass = new THREE.Mesh(new THREE.PlaneGeometry(0.9, 0.7), new THREE.MeshBasicMaterial({ map: skyline, toneMapped: false }));
  windowGroup.add(glass);
  const frameMat = mat("#2d2a26");
  for (const [w, h, x, y] of [[0.98, 0.04, 0, 0.37], [0.98, 0.04, 0, -0.37], [0.04, 0.78, -0.47, 0], [0.04, 0.78, 0.47, 0], [0.02, 0.7, 0, 0], [0.9, 0.02, 0, 0]]) {
    const bar = mesh(new THREE.BoxGeometry(w, h, 0.04), frameMat);
    bar.position.set(x, y, 0.02);
    windowGroup.add(bar);
  }
  windowGroup.position.set(0.95, 1.55, -0.6);
  scene.add(windowGroup);

  // Poster.
  const posterTex = canvasTexture(300, 400, (g, w, h) => {
    g.fillStyle = "#0b0f0a";
    g.fillRect(0, 0, w, h);
    g.strokeStyle = "#b5e853";
    g.lineWidth = 4;
    g.strokeRect(14, 14, w - 28, h - 28);
    g.fillStyle = "#b5e853";
    g.textAlign = "center";
    fitText(g, "./" + data.name.toLowerCase().replace(/\s+/g, "-"), w - 60, 34);
    g.fillText("./" + data.name.toLowerCase().replace(/\s+/g, "-"), w / 2, 90);
    g.font = '20px "DejaVu Sans Mono", monospace';
    g.fillStyle = "#6f8f3a";
    ["while (alive) {", "  make();", "  play();", "  learn();", "}"].forEach((l, i) => {
      g.textAlign = "left";
      g.fillText(l, 50, 170 + i * 32);
    });
    g.textAlign = "center";
    g.fillStyle = "#b5e853";
    g.font = 'bold 18px "DejaVu Sans Mono", monospace';
    g.fillText("PRESS START", w / 2, h - 50);
  });
  const poster = mesh(new THREE.BoxGeometry(0.42, 0.56, 0.015), [frameMat, frameMat, frameMat, frameMat, mat("#ffffff", { map: posterTex, roughness: 0.6 }), frameMat], { cast: false });
  poster.position.set(-0.85, 1.55, -0.6);
  poster.rotation.z = 0.02;
  scene.add(poster);

  // ---------- desk ----------
  const wood = mat("#6b4a31", { roughness: 0.65 });
  const top = mesh(new RoundedBoxGeometry(1.9, 0.05, 0.85, 3, 0.012), wood);
  top.position.set(0, DESK_Y - 0.025, 0);
  scene.add(top);
  const metal = mat("#2a2d30", { metalness: 0.6, roughness: 0.4 });
  for (const x of [-0.88, 0.88]) {
    for (const z of [-0.36, 0.36]) {
      const leg = mesh(new THREE.BoxGeometry(0.04, DESK_Y - 0.05, 0.04), metal);
      leg.position.set(x, (DESK_Y - 0.05) / 2, z);
      scene.add(leg);
    }
  }

  // ---------- CRT monitor ----------
  const monitor = new THREE.Group();
  const shell = mat("#c9c1a9", { roughness: 0.55 });
  const base = mesh(new RoundedBoxGeometry(0.3, 0.03, 0.26, 2, 0.01), shell);
  base.position.set(0, 0.015, 0);
  monitor.add(base);
  const neck = mesh(new THREE.CylinderGeometry(0.06, 0.08, 0.04, 16), shell);
  neck.position.set(0, 0.05, 0);
  monitor.add(neck);
  const body = mesh(new RoundedBoxGeometry(0.58, 0.46, 0.4, 4, 0.03), shell);
  body.position.set(0, 0.3, 0);
  monitor.add(body);
  const back = mesh(new RoundedBoxGeometry(0.42, 0.34, 0.24, 3, 0.04), shell);
  back.position.set(0, 0.3, -0.27);
  monitor.add(back);
  const bezel = mesh(new RoundedBoxGeometry(0.5, 0.38, 0.02, 2, 0.008), mat("#26282a", { roughness: 0.5 }));
  bezel.position.set(0, 0.31, 0.2);
  monitor.add(bezel);
  const screen = new THREE.Mesh(
    new THREE.PlaneGeometry(0.44, 0.33),
    new THREE.MeshBasicMaterial({ map: screenTexture, toneMapped: false })
  );
  screen.position.set(0, 0.31, 0.2115);
  screen.name = "screen";
  monitor.add(screen);
  // Power light and brand strip.
  const led = new THREE.Mesh(new THREE.SphereGeometry(0.006, 8, 8), new THREE.MeshBasicMaterial({ color: "#7dff4a" }));
  led.position.set(0.23, 0.095, 0.2);
  monitor.add(led);
  // Sticky note.
  const noteTex = canvasTexture(200, 200, (g, w, h) => {
    g.fillStyle = "#f4e36b";
    g.fillRect(0, 0, w, h);
    g.fillStyle = "#3a3320";
    g.font = 'bold 26px "Comic Sans MS", "Segoe Print", cursive';
    g.textAlign = "center";
    g.fillText("click the", w / 2, 60);
    g.fillText("screen &", w / 2, 95);
    g.fillText("type help", w / 2, 130);
    g.font = "bold 34px sans-serif";
    g.fillText("↖", w / 2, 175);
  });
  const note = new THREE.Mesh(new THREE.PlaneGeometry(0.062, 0.062), mat("#ffffff", { map: noteTex, roughness: 0.9 }));
  note.position.set(0.252, 0.112, 0.213);
  note.rotation.z = -0.12;
  monitor.add(note);

  monitor.position.set(-0.05, DESK_Y, -0.17);
  monitor.traverse((o) => (o.userData.interactive = monitor));
  monitor.userData = { kind: "monitor", label: "Terminal", detail: "Click to use it, or just start typing." };
  scene.add(monitor);
  interactive.push(monitor);

  // ---------- keyboard ----------
  const keyboard = new THREE.Group();
  const kbBase = mesh(new RoundedBoxGeometry(0.46, 0.025, 0.16, 2, 0.008), shell);
  kbBase.position.y = 0.0125;
  keyboard.add(kbBase);
  const keyGeo = new RoundedBoxGeometry(0.024, 0.012, 0.024, 1, 0.003);
  const keyMat = mat("#ebe6d6", { roughness: 0.5 });
  const cols = 14;
  const rowsK = 4;
  const keys = new THREE.InstancedMesh(keyGeo, keyMat, cols * rowsK + 1);
  keys.castShadow = true;
  const dummy = new THREE.Object3D();
  const keyRest = [];
  let k = 0;
  for (let r = 0; r < rowsK; r++) {
    for (let c = 0; c < cols; c++) {
      dummy.position.set(-0.195 + c * 0.03 + (r % 2) * 0.008, 0.031, -0.05 + r * 0.03);
      dummy.scale.set(1, 1, 1);
      dummy.updateMatrix();
      keys.setMatrixAt(k, dummy.matrix);
      keyRest.push(dummy.position.clone());
      k++;
    }
  }
  dummy.position.set(0, 0.031, 0.072);
  dummy.scale.set(7, 1, 1);
  dummy.updateMatrix();
  keys.setMatrixAt(k, dummy.matrix);
  keyRest.push(dummy.position.clone());
  keyboard.add(keys);
  keyboard.position.set(-0.05, DESK_Y, 0.2);
  scene.add(keyboard);

  const pressed = new Map(); // key index -> time pressed
  function pressKey(spacebar = false) {
    const i = spacebar ? keyRest.length - 1 : Math.floor(Math.random() * (keyRest.length - 1));
    pressed.set(i, performance.now());
  }
  animated.push((now) => {
    if (!pressed.size) return;
    for (const [i, t] of pressed) {
      const age = now - t;
      const down = age < 120 ? 0.006 : 0;
      const p = keyRest[i];
      dummy.position.set(p.x, p.y - down, p.z);
      dummy.scale.set(i === keyRest.length - 1 ? 7 : 1, 1, 1);
      dummy.updateMatrix();
      keys.setMatrixAt(i, dummy.matrix);
      if (age >= 120) pressed.delete(i);
    }
    keys.instanceMatrix.needsUpdate = true;
  });

  // ---------- mouse ----------
  const pad = mesh(new RoundedBoxGeometry(0.22, 0.004, 0.18, 1, 0.002), mat("#1d3b2c", { roughness: 0.95 }));
  pad.position.set(0.36, DESK_Y + 0.002, 0.22);
  scene.add(pad);
  const mouse = mesh(new THREE.SphereGeometry(0.03, 16, 12), shell);
  mouse.scale.set(0.85, 0.45, 1.3);
  mouse.position.set(0.36, DESK_Y + 0.016, 0.22);
  scene.add(mouse);

  // ---------- mug ----------
  const mug = new THREE.Group();
  const mugProfile = [
    new THREE.Vector2(0, 0), new THREE.Vector2(0.038, 0), new THREE.Vector2(0.04, 0.005),
    new THREE.Vector2(0.042, 0.1), new THREE.Vector2(0.036, 0.1), new THREE.Vector2(0.034, 0.012), new THREE.Vector2(0, 0.012),
  ];
  const mugMat = mat("#b5e853", { roughness: 0.4 });
  mug.add(mesh(new THREE.LatheGeometry(mugProfile, 24), mugMat));
  const handle = mesh(new THREE.TorusGeometry(0.026, 0.007, 8, 16, Math.PI), mugMat);
  handle.rotation.z = -Math.PI / 2;
  handle.position.set(0.042, 0.052, 0);
  mug.add(handle);
  const coffee = new THREE.Mesh(new THREE.CircleGeometry(0.035, 20), mat("#2b1a10", { roughness: 0.2 }));
  coffee.rotation.x = -Math.PI / 2;
  coffee.position.y = 0.085;
  mug.add(coffee);
  mug.position.set(-0.6, DESK_Y, 0.08);
  mug.rotation.y = 0.6;
  scene.add(mug);

  // ---------- plant ----------
  const plant = new THREE.Group();
  const pot = mesh(new THREE.CylinderGeometry(0.07, 0.055, 0.12, 16), mat("#a65a3a"));
  pot.position.y = 0.06;
  plant.add(pot);
  const soil = new THREE.Mesh(new THREE.CircleGeometry(0.065, 16), mat("#2a1d14"));
  soil.rotation.x = -Math.PI / 2;
  soil.position.y = 0.115;
  plant.add(soil);
  const leafMat = mat("#3f8f4a", { roughness: 0.6, flatShading: true });
  const r = rng(7);
  for (let i = 0; i < 9; i++) {
    const leaf = mesh(new THREE.ConeGeometry(0.025, 0.2 + r() * 0.08, 4), leafMat);
    const a = (i / 9) * Math.PI * 2;
    const tilt = 0.25 + r() * 0.45;
    leaf.position.set(Math.cos(a) * 0.03, 0.2, Math.sin(a) * 0.03);
    leaf.rotation.set(Math.sin(a) * tilt, 0, -Math.cos(a) * tilt);
    leaf.scale.set(1, 1, 0.35);
    plant.add(leaf);
  }
  plant.position.set(-0.78, DESK_Y, -0.27);
  scene.add(plant);
  animated.push((now) => {
    plant.rotation.z = Math.sin(now / 1800) * 0.015;
  });

  // ---------- lamp ----------
  const lamp = new THREE.Group();
  const lampMat = mat("#2f3b35", { metalness: 0.5, roughness: 0.35 });
  const lampBase = mesh(new THREE.CylinderGeometry(0.07, 0.08, 0.02, 20), lampMat);
  lampBase.position.y = 0.01;
  lamp.add(lampBase);
  const arm1 = mesh(new THREE.CylinderGeometry(0.008, 0.008, 0.36, 8), lampMat);
  arm1.position.set(0, 0.19, -0.03);
  arm1.rotation.x = -0.25;
  lamp.add(arm1);
  const joint = mesh(new THREE.SphereGeometry(0.016, 12, 8), lampMat);
  joint.position.set(0, 0.36, -0.075);
  lamp.add(joint);
  const arm2 = mesh(new THREE.CylinderGeometry(0.008, 0.008, 0.3, 8), lampMat);
  arm2.position.set(-0.11, 0.42, -0.04);
  arm2.rotation.z = Math.PI / 2.6;
  lamp.add(arm2);
  const head = mesh(new THREE.ConeGeometry(0.06, 0.1, 20, 1, true), new THREE.MeshStandardMaterial({ color: "#2f3b35", metalness: 0.5, roughness: 0.35, side: THREE.DoubleSide }));
  head.position.set(-0.24, 0.43, -0.01);
  head.rotation.z = 0.5;
  lamp.add(head);
  const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.022, 12, 8), new THREE.MeshBasicMaterial({ color: "#fff3c4" }));
  bulb.position.set(-0.225, 0.4, -0.01);
  lamp.add(bulb);
  lamp.position.set(0.7, DESK_Y, -0.22);
  scene.add(lamp);
  const lampLight = new THREE.SpotLight("#ffd9a0", 6, 3, 0.75, 0.6, 1.5);
  lampLight.position.set(0.7 - 0.225, DESK_Y + 0.39, -0.23);
  lampLight.target.position.set(0.25, DESK_Y, 0.05);
  lampLight.castShadow = true;
  lampLight.shadow.mapSize.set(1024, 1024);
  lampLight.shadow.bias = -0.0005;
  lampLight.shadow.camera.near = 0.05;
  scene.add(lampLight, lampLight.target);

  // ---------- project cartridges ----------
  const projects = data.projects || [];
  const rackCount = Math.max(1, Math.min(projects.length, 8));
  const spacing = 0.075;
  const rack = mesh(new RoundedBoxGeometry(rackCount * spacing + 0.04, 0.03, 0.1, 2, 0.008), mat("#26282a"));
  const rackX = 0.42;
  rack.position.set(rackX, DESK_Y + 0.015, -0.02);
  scene.add(rack);

  projects.slice(0, 8).forEach((proj, i) => {
    const color = CART_COLORS[i % CART_COLORS.length];
    const labelTex = canvasTexture(256, 320, (g, w, h) => {
      g.fillStyle = color;
      g.fillRect(0, 0, w, h);
      g.fillStyle = "#f2efe4";
      g.fillRect(16, 16, w - 32, h - 80);
      g.fillStyle = "#1a1a1a";
      g.textAlign = "center";
      g.font = 'bold 30px "DejaVu Sans Mono", monospace';
      const title = proj.title.replace(/^\[|\]$/g, "");
      const lines = wrapWords(g, title, w - 60, 4);
      lines.forEach((l, j) => g.fillText(l, w / 2, 70 + j * 38));
      g.fillStyle = "#f2efe4";
      g.font = 'bold 26px "DejaVu Sans Mono", monospace';
      g.fillText(String(i + 1).padStart(2, "0"), w / 2, h - 26);
    });
    const shellMat = mat(color, { roughness: 0.5 });
    const faceMat = mat("#ffffff", { map: labelTex, roughness: 0.5 });
    const cart = new THREE.Group();
    const box = mesh(new THREE.BoxGeometry(0.06, 0.08, 0.016), [shellMat, shellMat, shellMat, shellMat, faceMat, shellMat]);
    box.position.y = 0.04;
    cart.add(box);
    const ridge = mesh(new THREE.BoxGeometry(0.06, 0.012, 0.02), shellMat);
    ridge.position.y = 0.074;
    cart.add(ridge);
    const x = rackX - ((rackCount - 1) * spacing) / 2 + i * spacing;
    cart.position.set(x, DESK_Y + 0.025, -0.02);
    cart.rotation.y = -0.25;
    cart.userData = {
      kind: "project",
      label: proj.title,
      detail: proj.summary,
      action: "Click to load it in the terminal.",
      command: `show ${i + 1}`,
      baseY: cart.position.y,
      materials: [shellMat, faceMat],
    };
    cart.traverse((o) => { if (o !== cart) o.userData.interactive = cart; });
    scene.add(cart);
    interactive.push(cart);
  });

  // ---------- about notebook ----------
  const coverTex = canvasTexture(256, 340, (g, w, h) => {
    g.fillStyle = "#24302b";
    g.fillRect(0, 0, w, h);
    g.fillStyle = "#b5e853";
    g.fillRect(0, 0, 22, h);
    g.textAlign = "center";
    g.font = 'bold 34px "DejaVu Sans Mono", monospace';
    g.fillText("ABOUT", w / 2 + 10, 130);
    g.fillText("ME", w / 2 + 10, 172);
    g.font = '18px "DejaVu Sans Mono", monospace';
    g.fillStyle = "#9fb88a";
    g.fillText(data.name, w / 2 + 10, 240);
  });
  const nbMat = mat("#24302b", { roughness: 0.8 });
  const pagesMat = mat("#efeadb", { roughness: 0.9 });
  const coverMat = mat("#ffffff", { map: coverTex, roughness: 0.8 });
  const notebook = new THREE.Group();
  const nb = mesh(new THREE.BoxGeometry(0.17, 0.022, 0.23), [pagesMat, nbMat, coverMat, nbMat, pagesMat, pagesMat]);
  nb.position.y = 0.011;
  notebook.add(nb);
  notebook.position.set(-0.43, DESK_Y, 0.2);
  notebook.rotation.y = 0.35;
  notebook.userData = { kind: "link", label: "About me", detail: "Experience, education and skills.", href: data.pages.about, baseY: DESK_Y, materials: [nbMat, coverMat] };
  notebook.traverse((o) => { if (o !== notebook) o.userData.interactive = notebook; });
  scene.add(notebook);
  interactive.push(notebook);

  // ---------- contact cards ----------
  const cardTex = canvasTexture(350, 200, (g, w, h) => {
    g.fillStyle = "#f2efe4";
    g.fillRect(0, 0, w, h);
    g.fillStyle = "#1a1a1a";
    g.font = 'bold 28px "DejaVu Sans Mono", monospace';
    g.fillText(data.name, 22, 52);
    g.font = '18px "DejaVu Sans Mono", monospace';
    g.fillStyle = "#4a4a4a";
    fitText(g, data.role, w - 44, 18, "normal");
    g.fillText(data.role, 22, 84);
    g.fillStyle = "#3b6e9e";
    g.font = 'bold 20px "DejaVu Sans Mono", monospace';
    g.fillText("CONTACT ›", 22, 160);
  });
  const cardMat = mat("#ffffff", { map: cardTex, roughness: 0.7 });
  const holderMat = mat("#26282a", { metalness: 0.4, roughness: 0.4 });
  const contact = new THREE.Group();
  const holder = mesh(new THREE.BoxGeometry(0.1, 0.02, 0.05), holderMat);
  holder.position.y = 0.01;
  contact.add(holder);
  const card = mesh(new THREE.PlaneGeometry(0.09, 0.052), cardMat);
  card.position.set(0, 0.045, -0.005);
  card.rotation.x = -0.35;
  contact.add(card);
  contact.position.set(0.7, DESK_Y, 0.25);
  contact.rotation.y = -0.4;
  contact.userData = { kind: "command", label: "Contact", detail: "Email, GitHub and LinkedIn.", command: "contact", baseY: DESK_Y, materials: [cardMat, holderMat] };
  contact.traverse((o) => { if (o !== contact) o.userData.interactive = contact; });
  scene.add(contact);
  interactive.push(contact);

  return { interactive, animated, monitor, screen, pressKey, lampLight };
}
