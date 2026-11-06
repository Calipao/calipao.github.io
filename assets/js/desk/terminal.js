// A small terminal drawn onto a canvas, used as the texture of the desk monitor.
// It knows nothing about Three.js: main.js feeds it keystrokes and asks it to draw.

const COLORS = {
  text: "#d6f5b0",
  green: "#b5e853",
  dim: "#6f8f3a",
  link: "#63c0f5",
  error: "#ff7b6b",
  white: "#f2f2f2",
};

const PROMPT = "lin@desk:~$ ";

export class Terminal {
  constructor({ data, width = 1024, height = 768, reducedMotion = false, onNavigate, onExit, onTextView, onOutput }) {
    this.data = data;
    this.canvas = document.createElement("canvas");
    this.canvas.width = width;
    this.canvas.height = height;
    this.ctx = this.canvas.getContext("2d");
    this.reducedMotion = reducedMotion;
    this.onNavigate = onNavigate;
    this.onExit = onExit;
    this.onTextView = onTextView;
    this.onOutput = onOutput;

    this.pad = 36;
    this.fontSize = 22;
    this.lineHeight = 28;
    this.font = `${this.fontSize}px "DejaVu Sans Mono", Menlo, Consolas, "Courier New", monospace`;
    this.ctx.font = this.font;
    this.charWidth = this.ctx.measureText("M").width;
    this.cols = Math.floor((width - this.pad * 2) / this.charWidth);
    this.rows = Math.floor((height - this.pad * 2) / this.lineHeight);

    this.lines = [];      // rendered lines: { text, color, href }
    this.queue = [];      // lines waiting to be "typed" out
    this.input = "";
    this.history = [];
    this.historyIndex = -1;
    this.scroll = 0;      // lines scrolled up from the bottom
    this.linkRects = [];  // clickable areas from the last draw
    this.dirty = true;
    this.lastBlink = 0;
    this.cursorOn = true;
    this.queueTimer = 0;
    this.overlay = this.buildOverlay(width, height);

    this.boot();
  }

  // ---------- output ----------

  print(text = "", color = COLORS.text, href = null) {
    for (const piece of this.wrap(String(text))) this.queue.push({ text: piece, color, href });
    if (this.onOutput && text) this.onOutput(String(text));
  }

  wrap(text) {
    if (text.length <= this.cols) return [text];
    const out = [];
    let rest = text;
    while (rest.length > this.cols) {
      let cut = rest.lastIndexOf(" ", this.cols);
      if (cut <= 0) cut = this.cols;
      out.push(rest.slice(0, cut));
      rest = "  " + rest.slice(cut).trimStart();
    }
    out.push(rest);
    return out;
  }

  flushQueue() {
    this.lines.push(...this.queue);
    this.queue.length = 0;
    this.trimScrollback();
    this.dirty = true;
  }

  trimScrollback() {
    if (this.lines.length > 400) this.lines.splice(0, this.lines.length - 400);
  }

  get busy() {
    return this.queue.length > 0;
  }

  // ---------- input ----------

  setInput(value) {
    this.input = value.replace(/[\r\n]/g, "").slice(0, this.cols - PROMPT.length - 1);
    this.scroll = 0;
    this.dirty = true;
  }

  submit() {
    const raw = this.input.trim();
    if (this.busy) this.flushQueue();
    this.lines.push({ text: PROMPT + this.input, color: COLORS.white });
    this.input = "";
    this.scroll = 0;
    if (raw) {
      this.history.push(raw);
      this.historyIndex = this.history.length;
      this.run(raw);
    }
    this.dirty = true;
  }

  historyStep(dir) {
    if (!this.history.length) return this.input;
    this.historyIndex = Math.min(this.history.length, Math.max(0, this.historyIndex + dir));
    this.input = this.history[this.historyIndex] || "";
    this.dirty = true;
    return this.input;
  }

  complete() {
    const word = this.input.trim().toLowerCase();
    if (!word || word.includes(" ")) return this.input;
    const matches = Object.keys(this.commands()).filter((c) => c.startsWith(word));
    if (matches.length === 1) this.input = matches[0] + " ";
    else if (matches.length > 1) {
      this.lines.push({ text: PROMPT + this.input, color: COLORS.white });
      this.print(matches.join("  "), COLORS.dim);
    }
    this.dirty = true;
    return this.input;
  }

  scrollBy(lines) {
    const max = Math.max(0, this.lines.length - (this.rows - 1));
    this.scroll = Math.min(max, Math.max(0, this.scroll + lines));
    this.dirty = true;
  }

  // ---------- commands ----------

  commands() {
    const d = this.data;
    const L = d.links || {};
    return {
      help: { about: "list commands", run: () => this.help() },
      about: { about: "who I am", run: () => this.about() },
      whoami: { hidden: true, run: () => this.about() },
      projects: { about: "list projects", run: () => this.projects() },
      ls: { hidden: true, run: () => this.projects() },
      open: { about: "open a project, e.g. open 1", run: (arg) => this.open(arg) },
      experience: { about: "work history", run: () => this.experience() },
      education: { about: "where I studied", run: () => this.education() },
      skills: { about: "what I work with", run: () => this.skills() },
      contact: { about: "ways to reach me", run: () => this.contact() },
      email: { hidden: !L.email, run: () => this.go(L.email && "mailto:" + L.email, "email") },
      github: { hidden: !L.github, run: () => this.go(L.github, "GitHub") },
      linkedin: { hidden: !L.linkedin, run: () => this.go(L.linkedin, "LinkedIn") },
      resume: { hidden: !L.resume, run: () => this.go(L.resume, "résumé") },
      clear: { about: "clear the screen", run: () => { this.lines = []; this.queue = []; } },
      text: { about: "switch to the plain text site", run: () => this.onTextView && this.onTextView() },
      exit: { about: "step back from the desk", run: () => this.onExit && this.onExit() },
      date: { hidden: true, run: () => this.print(new Date().toString()) },
      echo: { hidden: true, run: (arg) => this.print(arg) },
      sudo: { hidden: true, run: () => this.print("Nice try. This incident will be reported.", COLORS.error) },
      cd: { hidden: true, run: () => this.print("There's nowhere else to go. Try `projects`.", COLORS.dim) },
    };
  }

  run(line) {
    const [name, ...rest] = line.split(/\s+/);
    const arg = rest.join(" ");
    const cmd = this.commands()[name.toLowerCase()];
    if (!cmd) {
      this.print(`command not found: ${name}. Type \`help\` for a list.`, COLORS.error);
      return;
    }
    cmd.run(arg);
  }

  boot() {
    const d = this.data;
    this.print("DESK-OS 1.0  (c) " + new Date().getFullYear() + " " + d.name, COLORS.dim);
    this.print("memory check ........ ok", COLORS.dim);
    this.print("loading portfolio ... ok", COLORS.dim);
    this.print("");
    this.print(`Hi, I'm ${d.name}.`, COLORS.green);
    this.print(d.role, COLORS.text);
    if (d.tagline) this.print(d.tagline, COLORS.text);
    this.print("");
    this.print("Type `help` to see what you can do, or `projects` to see my work.", COLORS.dim);
    this.print("");
  }

  help() {
    this.print("Available commands:", COLORS.green);
    for (const [name, c] of Object.entries(this.commands())) {
      if (c.hidden || !c.about) continue;
      this.print(`  ${name.padEnd(12)}${c.about}`);
    }
    const L = this.data.links || {};
    const shortcuts = ["email", "github", "linkedin", "resume"].filter((k) => L[k]);
    if (shortcuts.length) this.print(`  ${shortcuts.join(", ")}  open that link`, COLORS.text);
    this.print("Tab completes, ↑/↓ recall history, Esc leaves the terminal.", COLORS.dim);
  }

  about() {
    const d = this.data;
    this.print(d.name, COLORS.green);
    this.print(d.role);
    if (d.tagline) this.print(d.tagline);
    const now = (d.experience || []).filter((j) => /present/i.test(j.end));
    if (now.length) {
      this.print("");
      this.print("Currently:", COLORS.green);
      for (const j of now) this.print(`  ${j.role} @ ${j.org}`);
    }
    this.print("");
    this.print("> read the full about page", COLORS.link, d.pages.about);
  }

  projects() {
    const list = this.data.projects || [];
    if (!list.length) return this.print("No projects yet.", COLORS.dim);
    this.print("Projects (click one, or type `open <number>`):", COLORS.green);
    list.forEach((p, i) => {
      this.print(`  [${i + 1}] ${p.title}`, COLORS.link, p.url);
      if (p.summary) this.print(`      ${p.summary}`, COLORS.dim);
    });
  }

  open(arg) {
    const list = this.data.projects || [];
    const n = parseInt(arg, 10);
    let proj = Number.isFinite(n) ? list[n - 1] : null;
    if (!proj && arg) proj = list.find((p) => p.title.toLowerCase().includes(arg.toLowerCase()));
    if (!proj) return this.print("Usage: open <number>. Type `projects` to list them.", COLORS.error);
    this.go(proj.url, proj.title);
  }

  experience() {
    this.print("Experience:", COLORS.green);
    for (const j of this.data.experience || []) {
      this.print(`  ${j.role} — ${j.org}`, COLORS.white);
      this.print(`    ${j.start} – ${j.end}`, COLORS.dim);
      for (const p of j.points || []) this.print(`    - ${p}`);
    }
  }

  education() {
    this.print("Education:", COLORS.green);
    for (const e of this.data.education || []) {
      this.print(`  ${e.qualification}`, COLORS.white);
      this.print(`    ${e.school}, ${e.start} – ${e.end}`, COLORS.dim);
    }
  }

  skills() {
    this.print("Skills:", COLORS.green);
    for (const g of this.data.skills || []) this.print(`  ${g.group}: ${g.items.join(", ")}`);
  }

  contact() {
    const L = this.data.links || {};
    this.print("Get in touch (click a line):", COLORS.green);
    if (L.email) this.print(`  email     ${L.email}`, COLORS.link, "mailto:" + L.email);
    if (L.github) this.print(`  github    ${L.github.replace(/^https?:\/\//, "")}`, COLORS.link, L.github);
    if (L.linkedin) this.print(`  linkedin  ${L.linkedin.replace(/^https?:\/\//, "")}`, COLORS.link, L.linkedin);
    if (L.website) this.print(`  web       ${L.website.replace(/^https?:\/\//, "")}`, COLORS.link, L.website);
    if (L.resume) this.print(`  résumé    ${L.resume}`, COLORS.link, L.resume);
  }

  go(href, label) {
    if (!href) return this.print("Not available yet.", COLORS.dim);
    this.print(`opening ${label} ...`, COLORS.dim);
    this.flushQueue();
    this.draw(performance.now());
    if (this.onNavigate) setTimeout(() => this.onNavigate(href), 250);
  }

  // ---------- drawing ----------

  update(now) {
    if (this.queue.length) {
      if (this.reducedMotion) this.flushQueue();
      else if (now - this.queueTimer > 22) {
        this.queueTimer = now;
        // Type faster when a lot is waiting.
        const n = this.queue.length > 30 ? 4 : this.queue.length > 10 ? 2 : 1;
        this.lines.push(...this.queue.splice(0, n));
        this.trimScrollback();
        this.scroll = 0;
        this.dirty = true;
      }
    }
    if (now - this.lastBlink > 530) {
      this.lastBlink = now;
      this.cursorOn = !this.cursorOn;
      this.dirty = true;
    }
    if (this.dirty) {
      this.draw(now);
      this.dirty = false;
      return true;
    }
    return false;
  }

  draw() {
    const { ctx, canvas, pad, lineHeight } = this;
    ctx.fillStyle = "#050a03";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.font = this.font;
    ctx.textBaseline = "top";

    const showPrompt = !this.busy;
    const visibleRows = this.rows - (showPrompt ? 1 : 0);
    const end = this.lines.length - this.scroll;
    const start = Math.max(0, end - visibleRows);
    const shown = this.lines.slice(start, end);

    this.linkRects = [];
    ctx.shadowBlur = 8;
    let y = pad;
    for (const line of shown) {
      ctx.fillStyle = line.color || COLORS.text;
      ctx.shadowColor = line.color || COLORS.text;
      ctx.fillText(line.text, pad, y);
      if (line.href) {
        const w = this.charWidth * line.text.length;
        this.linkRects.push({ x0: pad, x1: pad + w, y0: y, y1: y + lineHeight, href: line.href });
      }
      y += lineHeight;
    }

    if (showPrompt && this.scroll === 0) {
      ctx.fillStyle = COLORS.green;
      ctx.shadowColor = COLORS.green;
      const text = PROMPT + this.input;
      ctx.fillText(text, pad, y);
      if (this.cursorOn) ctx.fillRect(pad + this.charWidth * text.length + 2, y + 2, this.charWidth, this.fontSize);
    } else if (this.scroll > 0) {
      ctx.fillStyle = COLORS.dim;
      ctx.shadowColor = COLORS.dim;
      ctx.fillText(`-- scrolled up ${this.scroll} lines --`, pad, y);
    }
    ctx.shadowBlur = 0;
    ctx.drawImage(this.overlay, 0, 0);
  }

  // Link under a point given in canvas pixels, if any.
  linkAt(x, y) {
    const hit = this.linkRects.find((r) => x >= r.x0 - 6 && x <= r.x1 + 6 && y >= r.y0 && y <= r.y1);
    return hit ? hit.href : null;
  }

  buildOverlay(w, h) {
    const c = document.createElement("canvas");
    c.width = w;
    c.height = h;
    const g = c.getContext("2d");
    g.fillStyle = "rgba(0,0,0,0.18)";
    for (let y = 0; y < h; y += 3) g.fillRect(0, y, w, 1);
    const v = g.createRadialGradient(w / 2, h / 2, h * 0.35, w / 2, h / 2, h * 0.85);
    v.addColorStop(0, "rgba(0,0,0,0)");
    v.addColorStop(1, "rgba(0,0,0,0.55)");
    g.fillStyle = v;
    g.fillRect(0, 0, w, h);
    return c;
  }
}
