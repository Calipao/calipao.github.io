import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { Terminal } from "./terminal.js";
import { buildDesk } from "./props.js";

const root = document.documentElement;
const app = document.getElementById("desk-app");
const canvas = document.getElementById("desk-canvas");
const tooltip = document.getElementById("desk-tooltip");
const hint = document.getElementById("desk-hint");
const loading = document.getElementById("desk-loading");
const termUI = document.getElementById("desk-term-ui");
const termInput = document.getElementById("desk-term-input");
const live = document.getElementById("desk-live");
const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;

let desk = null; // created on first switch to the 3D view

// ---------- view switching ----------

function setView(view, { remember = true } = {}) {
  root.setAttribute("data-view", view);
  if (remember) {
    try { localStorage.setItem("desk-view", view); } catch (e) { /* storage unavailable */ }
  }
  if (view === "3d") startDesk();
  else if (desk) desk.stop();
}

document.addEventListener("click", (e) => {
  const sw = e.target.closest("[data-view-switch]");
  if (!sw) return;
  const view = sw.getAttribute("data-view-switch");
  if (sw.tagName !== "A") e.preventDefault();
  setView(view);
  if (view === "text") {
    window.scrollTo(0, 0);
    document.getElementById("main_content").focus({ preventScroll: true });
  }
});

function fallbackToText(reason) {
  console.warn("3D desk unavailable:", reason);
  root.setAttribute("data-webgl", "no");
  setView("text", { remember: false });
}

async function startDesk() {
  if (desk) return desk.start();
  try {
    const res = await fetch(app.dataset.portfolio, { cache: "no-cache" });
    if (!res.ok) throw new Error("portfolio.json: HTTP " + res.status);
    const data = await res.json();
    desk = createDesk(data);
    if (root.getAttribute("data-view") === "3d") desk.start();
  } catch (err) {
    fallbackToText(err);
  }
}

// ---------- the 3D desk ----------

function createDesk(data) {
  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: "high-performance" });
  } catch (err) {
    throw new Error("WebGL renderer failed: " + err.message);
  }
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.1;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFShadowMap;

  const scene = new THREE.Scene();
  scene.background = new THREE.Color("#0c0f0e");
  scene.fog = new THREE.Fog("#0c0f0e", 3.5, 8);

  const camera = new THREE.PerspectiveCamera(40, 1, 0.05, 340);

  // Lights: dim room, warm desk lamp (in props), green screen glow, cool moonlight.
  scene.add(new THREE.HemisphereLight("#7d93b8", "#1a1410", 0.55));
  const moon = new THREE.DirectionalLight("#9fb7ff", 0.6);
  moon.position.set(1.5, 2.5, 1.5);
  scene.add(moon);

  // Terminal on the monitor.
  const term = new Terminal({
    data,
    reducedMotion,
    onNavigate: navigate,
    onExit: () => exitTerminal(),
    onTextView: () => setView("text"),
    onOutput: announce,
  });
  const screenTexture = new THREE.CanvasTexture(term.canvas);
  screenTexture.colorSpace = THREE.SRGBColorSpace;
  screenTexture.anisotropy = renderer.capabilities.getMaxAnisotropy();

  const world = buildDesk(scene, { data, screenTexture });
  const screenGlow = new THREE.PointLight("#9dff6a", 0.9, 1.6, 2);
  const screenPos = new THREE.Vector3();
  world.screen.getWorldPosition(screenPos);
  screenGlow.position.copy(screenPos).add(new THREE.Vector3(0, -0.05, 0.25));
  scene.add(screenGlow);

  // Camera rig.
  const controls = new OrbitControls(camera, canvas);
  controls.enableDamping = true;
  controls.dampingFactor = 0.08;
  controls.enablePan = false;
  controls.minDistance = 0.7;
  controls.maxDistance = 2.6;
  controls.minPolarAngle = 0.55;
  controls.maxPolarAngle = 1.45;
  controls.minAzimuthAngle = -0.9;
  controls.maxAzimuthAngle = 0.9;
  controls.rotateSpeed = 0.6;
  controls.zoomSpeed = 0.7;

  const home = { target: new THREE.Vector3(0, 0.98, -0.05), position: new THREE.Vector3() };
  function homeDistance() {
    // Back off on narrow screens so the desk (about 1.6 m of it) stays in view.
    const halfV = THREE.MathUtils.degToRad(camera.fov) / 2;
    const halfH = Math.atan(Math.tan(halfV) * (camera.aspect || 1));
    return Math.max(1.75, 0.8 / Math.tan(halfH));
  }
  function homePosition() {
    const dist = homeDistance();
    return new THREE.Vector3(0, 1.4 + (dist - 1.75) * 0.15, dist);
  }
  function fitToScreen() {
    const dist = homeDistance();
    controls.maxDistance = Math.max(2.6, dist + 0.5);
    scene.fog.near = dist + 1.5;
    scene.fog.far = dist + 6;
  }

  // ---------- state ----------
  let mode = "orbit"; // orbit | focus | tween
  let tween = null;
  let hovered = null;
  let running = false;
  let hintHidden = false;
  if (matchMedia("(pointer: coarse)").matches) {
    hint.textContent = "Drag to look around · Tap the monitor for the terminal · Tap a cartridge to load a project";
  }

  function tweenCamera(toPos, toTarget, ms, done) {
    const fromPos = camera.position.clone();
    const fromTarget = controls.target.clone();
    const start = performance.now();
    const duration = reducedMotion ? 1 : ms;
    tween = (now) => {
      const t = Math.min(1, (now - start) / duration);
      const e = t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
      camera.position.lerpVectors(fromPos, toPos, e);
      controls.target.lerpVectors(fromTarget, toTarget, e);
      camera.lookAt(controls.target);
      if (t >= 1) {
        tween = null;
        if (done) done();
      }
    };
  }

  function screenView() {
    const pos = new THREE.Vector3();
    const quat = new THREE.Quaternion();
    world.screen.getWorldPosition(pos);
    world.screen.getWorldQuaternion(quat);
    const normal = new THREE.Vector3(0, 0, 1).applyQuaternion(quat);
    const h = 0.33;
    const w = 0.44;
    const vfov = THREE.MathUtils.degToRad(camera.fov);
    const distH = (h / 2) / Math.tan(vfov / 2);
    const distW = (w / 2) / (Math.tan(vfov / 2) * camera.aspect);
    const dist = Math.max(distH, distW) * 1.12 + 0.02;
    return { position: pos.clone().add(normal.multiplyScalar(dist)), target: pos };
  }

  function enterTerminal() {
    if (mode === "focus") {
      termInput.focus({ preventScroll: true });
      return;
    }
    hideHint();
    clearHover();
    mode = "tween";
    controls.enabled = false;
    const view = screenView();
    tweenCamera(view.position, view.target, 900, () => { mode = "focus"; });
    termUI.hidden = false;
    termInput.value = term.input;
    termInput.focus({ preventScroll: true });
  }

  function exitTerminal() {
    if (mode === "orbit") return;
    mode = "tween";
    termUI.hidden = true;
    termInput.blur();
    selectCartridge(0);
    home.position.copy(homePosition());
    tweenCamera(home.position, home.target, 900, () => {
      mode = "orbit";
      controls.enabled = true;
    });
  }

  function hideHint() {
    if (hintHidden) return;
    hintHidden = true;
    hint.classList.add("is-hidden");
  }

  // ---------- picking ----------
  const raycaster = new THREE.Raycaster();
  const pointer = new THREE.Vector2();

  function pick(clientX, clientY) {
    const rect = canvas.getBoundingClientRect();
    pointer.x = ((clientX - rect.left) / rect.width) * 2 - 1;
    pointer.y = -((clientY - rect.top) / rect.height) * 2 + 1;
    raycaster.setFromCamera(pointer, camera);
    const hits = raycaster.intersectObjects(world.interactive, true);
    if (!hits.length) return null;
    let o = hits[0].object;
    while (o && !world.interactive.includes(o)) o = o.parent;
    return o ? { object: o, hit: hits[0] } : null;
  }

  function screenLinkAt(hit) {
    if (!hit || hit.object !== world.screen || !hit.uv) return null;
    return term.linkAt(hit.uv.x * term.canvas.width, (1 - hit.uv.y) * term.canvas.height);
  }

  function setHover(obj, clientX, clientY) {
    if (hovered !== obj) {
      if (hovered) highlight(hovered, false);
      hovered = obj;
      if (hovered) highlight(hovered, true);
    }
    if (hovered && mode === "orbit") {
      const u = hovered.userData;
      tooltip.innerHTML = "";
      const title = document.createElement("strong");
      title.textContent = u.label;
      tooltip.appendChild(title);
      if (u.detail) {
        const p = document.createElement("span");
        p.textContent = u.detail;
        tooltip.appendChild(p);
      }
      if (u.action) {
        const a = document.createElement("em");
        a.textContent = u.action;
        tooltip.appendChild(a);
      }
      tooltip.hidden = false;
      const x = Math.min(clientX + 16, window.innerWidth - tooltip.offsetWidth - 8);
      const y = Math.min(clientY + 16, window.innerHeight - tooltip.offsetHeight - 8);
      tooltip.style.transform = `translate(${x}px, ${y}px)`;
    } else {
      tooltip.hidden = true;
    }
  }

  function clearHover() {
    setHover(null);
    canvas.style.cursor = "";
  }

  function highlight(obj, on) {
    const mats = obj.userData.materials;
    if (mats) for (const m of mats) m.emissive.set(on ? "#3a5a14" : "#000000");
    obj.userData.lift = on ? 0.02 : 0;
  }

  // Keep focus on the terminal input: clicking the (unfocusable) canvas would
  // otherwise move focus to the page and close the phone keyboard.
  canvas.addEventListener("mousedown", (e) => e.preventDefault());

  let downAt = null;
  canvas.addEventListener("pointerdown", (e) => {
    downAt = { x: e.clientX, y: e.clientY };
  });

  canvas.addEventListener("pointermove", (e) => {
    if (mode === "tween") return;
    if (e.pointerType === "touch") return;
    const p = pick(e.clientX, e.clientY);
    if (mode === "focus") {
      const link = p && screenLinkAt(p.hit);
      canvas.style.cursor = link ? "pointer" : p && p.object === world.monitor ? "text" : "zoom-out";
      return;
    }
    setHover(p ? p.object : null, e.clientX, e.clientY);
    canvas.style.cursor = p ? "pointer" : "grab";
  });

  canvas.addEventListener("pointerleave", () => clearHover());

  canvas.addEventListener("pointerup", (e) => {
    if (!downAt) return;
    const moved = Math.hypot(e.clientX - downAt.x, e.clientY - downAt.y);
    downAt = null;
    if (moved > 6 || mode === "tween") return;
    hideHint();
    const p = pick(e.clientX, e.clientY);

    if (mode === "focus") {
      if (p && p.object === world.monitor) {
        const link = screenLinkAt(p.hit);
        if (link && link.startsWith("cmd:")) runCommand(link.slice(4));
        else if (link) navigate(link);
        else termInput.focus({ preventScroll: true });
      } else {
        exitTerminal();
      }
      return;
    }

    if (!p) return;
    const u = p.object.userData;
    if (u.kind === "monitor") enterTerminal();
    else if (u.command) {
      enterTerminal();
      runCommand(u.command);
    } else if (u.href) navigate(u.href);
  });

  // Run a terminal command as if typed. `show <n>` also raises that cartridge.
  function runCommand(command) {
    term.runVisible(command);
    termInput.value = "";
    world.pressKey(true);
    const m = /^show\s+(\d+)$/.exec(command);
    selectCartridge(m ? Number(m[1]) : 0);
  }

  function selectCartridge(n) {
    for (const obj of world.interactive) {
      if (obj.userData.kind === "project") obj.userData.selected = obj.userData.command === `show ${n}`;
    }
  }

  canvas.addEventListener("wheel", (e) => {
    if (mode !== "focus") return;
    e.preventDefault();
    term.scrollBy(e.deltaY > 0 ? -3 : 3);
  }, { passive: false });

  // ---------- typing ----------
  termInput.addEventListener("input", () => {
    term.setInput(termInput.value);
    termInput.value = term.input;
    world.pressKey(termInput.value.endsWith(" "));
  });

  termInput.addEventListener("keydown", (e) => {
    switch (e.key) {
      case "Enter": {
        e.preventDefault();
        const typed = term.input.trim();
        term.submit();
        const m = /^show\s+(\d+)$/i.exec(typed);
        if (m) selectCartridge(Number(m[1]));
        termInput.value = "";
        world.pressKey(true);
        break;
      }
      case "ArrowUp":
        e.preventDefault();
        termInput.value = term.historyStep(-1);
        break;
      case "ArrowDown":
        e.preventDefault();
        termInput.value = term.historyStep(1);
        break;
      case "Tab":
        e.preventDefault();
        termInput.value = term.complete();
        break;
      case "PageUp":
        e.preventDefault();
        term.scrollBy(10);
        break;
      case "PageDown":
        e.preventDefault();
        term.scrollBy(-10);
        break;
      case "Escape":
        e.preventDefault();
        exitTerminal();
        break;
      default:
        break;
    }
  });

  // Start typing anywhere on the desk to jump into the terminal.
  window.addEventListener("keydown", (e) => {
    if (!running || mode !== "orbit") return;
    if (e.ctrlKey || e.metaKey || e.altKey || e.key.length !== 1) return;
    const t = e.target;
    if (t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.tagName === "BUTTON" || t.tagName === "A")) return;
    e.preventDefault();
    enterTerminal();
    term.setInput(term.input + e.key);
    termInput.value = term.input;
    world.pressKey(e.key === " ");
  });

  termUI.addEventListener("click", (e) => {
    const b = e.target.closest("button");
    if (!b) return;
    if (b.id === "desk-term-exit") return exitTerminal();
    const cmd = b.getAttribute("data-cmd");
    if (cmd) {
      runCommand(cmd);
      termInput.focus({ preventScroll: true });
    }
  });

  // ---------- loop ----------
  function resize() {
    const w = window.innerWidth;
    const h = window.innerHeight;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    fitToScreen();
    if (mode === "focus") {
      const v = screenView();
      camera.position.copy(v.position);
      controls.target.copy(v.target);
    }
  }
  window.addEventListener("resize", resize);

  function frame(now) {
    if (term.update(now)) screenTexture.needsUpdate = true;
    for (const fn of world.animated) fn(now);
    for (const obj of world.interactive) {
      const u = obj.userData;
      if (u.baseY === undefined) continue;
      const target = u.baseY + Math.max(u.lift || 0, u.selected ? 0.03 : 0);
      obj.position.y += (target - obj.position.y) * 0.2;
    }
    if (tween) tween(now);
    else if (mode === "orbit") controls.update();
    renderer.render(scene, camera);
  }

  let introDone = false;
  function start() {
    if (running) return;
    running = true;
    resize();
    if (!introDone) {
      introDone = true;
      home.position.copy(homePosition());
      if (reducedMotion) {
        camera.position.copy(home.position);
        controls.target.copy(home.target);
      } else {
        camera.position.set(0.9, 2.1, 3.4);
        controls.target.copy(home.target);
        mode = "tween";
        controls.enabled = false;
        tweenCamera(home.position, home.target, 1800, () => {
          mode = "orbit";
          controls.enabled = true;
        });
      }
      camera.lookAt(controls.target);
    }
    renderer.setAnimationLoop(frame);
    loading.hidden = true;
  }

  function stop() {
    running = false;
    renderer.setAnimationLoop(null);
    if (mode !== "orbit") {
      termUI.hidden = true;
      mode = "orbit";
      tween = null;
      controls.enabled = true;
      camera.position.copy(home.position);
      controls.target.copy(home.target);
    }
    clearHover();
  }

  canvas.addEventListener("webglcontextlost", (e) => {
    e.preventDefault();
    fallbackToText("WebGL context lost");
  });

  return { start, stop };
}

// ---------- helpers ----------

function navigate(href) {
  if (/^mailto:/i.test(href)) {
    window.location.href = href;
    return;
  }
  const url = new URL(href, window.location.href);
  if (url.origin !== window.location.origin) window.open(url.href, "_blank", "noopener");
  else window.location.href = url.href;
}

let liveTimer = 0;
let liveBuffer = [];
function announce(text) {
  liveBuffer.push(text);
  clearTimeout(liveTimer);
  liveTimer = setTimeout(() => {
    live.textContent = liveBuffer.join("\n");
    liveBuffer = [];
  }, 400);
}

// ---------- boot ----------
if (root.getAttribute("data-view") === "3d") startDesk();
