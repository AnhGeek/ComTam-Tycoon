/**
 * Presentation layer for the prototype.
 *
 * Mirrors the architecture of the real client: this file reads simulation state
 * and renders it, and holds no game rules. Every number on screen comes from
 * core.js.
 */

import {
  DaySimulation, BALANCE, PROFILE, DONENESS, STATE, CMD,
  evaluateDoneness, formatMoney, moodOf,
} from './core.js';

const FIXED_STEP = 0.05; // 20 Hz, matching the Unity host

const $ = (id) => document.getElementById(id);

const el = {
  money: $('money'), day: $('day'), timer: $('timer'),
  queue: $('queue'),
  canvas: $('grillCanvas'), grillState: $('grillState'),
  trayRice: $('trayRice'), trayPork: $('trayPork'), trayReady: $('trayReady'),
  btnRice: $('btnRice'), btnGrill: $('btnGrill'), btnServe: $('btnServe'),
  btnGrillLabel: $('btnGrillLabel'),
  toast: $('toast'), floats: $('floats'),
  intro: $('intro'), btnStart: $('btnStart'),
  results: $('results'), resultsBody: $('resultsBody'), btnAgain: $('btnAgain'),
};

let sim = null;
let running = false;
let raf = 0;
let lastTs = 0;
let acc = 0;
let toastUntil = 0;

// ---------------------------------------------------------------------------
// Faces - drawn, not emoji, so mood reads as part of the art direction
// ---------------------------------------------------------------------------

const MOUTHS = {
  happy: 'M15 27 Q21 33 27 27',
  normal: 'M16 28 H26',
  impatient: 'M16 30 Q21 26 26 30',
  angry: 'M15 31 Q21 25 27 31',
  eating: 'M16 27 Q21 32 26 27',
};
const FACE_TINT = {
  happy: '#4fa372', normal: '#c9d1ce', impatient: '#ff8c42',
  angry: '#d64545', eating: '#ffc93c',
};

function faceSvg(mood) {
  const tint = FACE_TINT[mood];
  const brows = (mood === 'angry' || mood === 'impatient')
    ? `<path d="M13 15 L19 18" stroke="${tint}" stroke-width="2" stroke-linecap="round"/>
       <path d="M29 15 L23 18" stroke="${tint}" stroke-width="2" stroke-linecap="round"/>`
    : '';
  return `<svg class="seat__face" viewBox="0 0 42 42" aria-hidden="true">
    <circle cx="21" cy="21" r="19" fill="${tint}22" stroke="${tint}" stroke-width="2"/>
    <circle cx="15" cy="21" r="2.2" fill="${tint}"/>
    <circle cx="27" cy="21" r="2.2" fill="${tint}"/>
    ${brows}
    <path d="${MOUTHS[mood]}" stroke="${tint}" stroke-width="2.2"
          fill="none" stroke-linecap="round"/>
  </svg>`;
}

function patienceColour(p) {
  if (p >= 0.8) return '#4fa372';
  if (p >= 0.5) return '#ffc93c';
  if (p >= 0.2) return '#ff8c42';
  return '#d64545';
}

// ---------------------------------------------------------------------------
// Grill canvas - the hero element
// ---------------------------------------------------------------------------

const ctx = el.canvas.getContext('2d');
let embers = [];

function sizeCanvas() {
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const r = el.canvas.getBoundingClientRect();
  el.canvas.width = Math.max(1, Math.round(r.width * dpr));
  el.canvas.height = Math.max(1, Math.round(r.height * dpr));
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
}

function drawGrill(now) {
  const r = el.canvas.getBoundingClientRect();
  const W = r.width;
  const H = r.height;
  const padX = 10;
  const barY = H * 0.46;
  const barH = 22;
  const barW = W - padX * 2;

  ctx.clearRect(0, 0, W, H);

  const occupied = sim.grill.occupied;
  const t = sim.grill.elapsed;
  const total = PROFILE.burntAt;
  const x = (s) => padX + (s / total) * barW;

  // Bar bed
  ctx.fillStyle = '#101b19';
  roundRect(ctx, padX, barY, barW, barH, 5);
  ctx.fill();

  // Zones. Only the perfect band is bright - everything else stays quiet so
  // the target is the one thing the eye lands on.
  const zones = [
    [0, PROFILE.rawUntil, '#2b3d3a'],
    [PROFILE.rawUntil, PROFILE.perfectStart, '#7a3f14'],
    [PROFILE.perfectEnd, PROFILE.burntAt, '#6d2a0d'],
  ];
  for (const [a, b, col] of zones) {
    ctx.fillStyle = col;
    ctx.fillRect(x(a), barY, x(b) - x(a), barH);
  }

  // Perfect band, with a pulse while the pork is actually in it
  const inPerfect = occupied && evaluateDoneness(t) === DONENESS.PERFECT;
  const pulse = inPerfect ? 0.72 + 0.28 * Math.sin(now / 90) : 0.5;
  const px = x(PROFILE.perfectStart);
  const pw = x(PROFILE.perfectEnd) - px;
  const grad = ctx.createLinearGradient(px, 0, px + pw, 0);
  grad.addColorStop(0, `rgba(255,140,26,${pulse})`);
  grad.addColorStop(0.5, `rgba(255,201,60,${pulse})`);
  grad.addColorStop(1, `rgba(255,140,26,${pulse})`);
  ctx.fillStyle = grad;
  ctx.fillRect(px, barY, pw, barH);

  if (inPerfect) {
    ctx.save();
    ctx.shadowColor = '#ffc93c';
    ctx.shadowBlur = 26;
    ctx.fillStyle = 'rgba(255,201,60,.34)';
    ctx.fillRect(px, barY, pw, barH);
    ctx.restore();
  }

  // Zone ticks
  ctx.strokeStyle = '#0d1716';
  ctx.lineWidth = 2;
  for (const s of [PROFILE.rawUntil, PROFILE.perfectStart, PROFILE.perfectEnd]) {
    ctx.beginPath();
    ctx.moveTo(x(s), barY);
    ctx.lineTo(x(s), barY + barH);
    ctx.stroke();
  }

  ctx.strokeStyle = '#2f4744';
  ctx.lineWidth = 1;
  roundRect(ctx, padX, barY, barW, barH, 5);
  ctx.stroke();

  if (occupied) {
    const hx = Math.min(x(t), padX + barW);

    // Trail behind the playhead
    const trail = ctx.createLinearGradient(padX, 0, hx, 0);
    trail.addColorStop(0, 'rgba(255,107,26,0)');
    trail.addColorStop(1, 'rgba(255,107,26,.42)');
    ctx.fillStyle = trail;
    ctx.fillRect(padX, barY, hx - padX, barH);

    // Playhead
    ctx.save();
    ctx.shadowColor = '#fff';
    ctx.shadowBlur = 12;
    ctx.fillStyle = '#fff6e8';
    ctx.fillRect(hx - 1.5, barY - 6, 3, barH + 12);
    ctx.restore();

    // The chop
    const chopY = barY - 22;
    const heat = Math.min(1, t / PROFILE.burntAt);
    const burnt = evaluateDoneness(t) === DONENESS.BURNT;
    ctx.fillStyle = burnt
      ? '#241d1a'
      : `rgb(${Math.round(214 - 90 * heat)},${Math.round(120 - 70 * heat)},${Math.round(86 - 50 * heat)})`;
    roundRect(ctx, hx - 15, chopY, 30, 15, 4);
    ctx.fill();
    ctx.strokeStyle = burnt ? '#120e0d' : '#00000055';
    ctx.lineWidth = 1;
    ctx.stroke();

    spawnEmbers(hx, chopY, heat, burnt);
  }

  drawEmbers(ctx);
}

function spawnEmbers(x, y, heat, burnt) {
  if (embers.length > 60) return;
  if (Math.random() > 0.35 + heat * 0.4) return;
  embers.push({
    x: x + (Math.random() - 0.5) * 26,
    y: y + 8,
    vy: -0.4 - Math.random() * 0.9,
    vx: (Math.random() - 0.5) * 0.35,
    life: 1,
    burnt,
  });
}

function drawEmbers(c) {
  for (const e of embers) {
    e.x += e.vx;
    e.y += e.vy;
    e.life -= 0.018;
    if (e.life <= 0) continue;
    c.globalAlpha = Math.max(0, e.life) * 0.85;
    c.fillStyle = e.burnt ? '#6b6b6b' : (e.life > 0.6 ? '#ffc93c' : '#ff6b1a');
    c.beginPath();
    c.arc(e.x, e.y, e.burnt ? 2.2 : 1.5, 0, Math.PI * 2);
    c.fill();
  }
  c.globalAlpha = 1;
  embers = embers.filter((e) => e.life > 0);
}

function roundRect(c, x, y, w, h, r) {
  c.beginPath();
  c.moveTo(x + r, y);
  c.arcTo(x + w, y, x + w, y + h, r);
  c.arcTo(x + w, y + h, x, y + h, r);
  c.arcTo(x, y + h, x, y, r);
  c.arcTo(x, y, x + w, y, r);
  c.closePath();
}

// ---------------------------------------------------------------------------
// DOM rendering
// ---------------------------------------------------------------------------

const DONENESS_LABEL = {
  [DONENESS.RAW]: 'CÒN SỐNG',
  [DONENESS.COOKING]: 'ĐANG NƯỚNG',
  [DONENESS.PERFECT]: 'VỪA CHÍN — LẤY NGAY!',
  [DONENESS.OVERCOOKED]: 'HƠI QUÁ — NHANH!',
  [DONENESS.BURNT]: 'CHÁY RỒI!',
};

function render() {
  el.money.textContent = formatMoney(sim.money);
  el.day.textContent = `Ngày ${sim.day}`;

  const secs = Math.ceil(sim.timeRemaining);
  el.timer.textContent = `${Math.floor(secs / 60)}:${String(secs % 60).padStart(2, '0')}`;
  el.timer.classList.toggle('is-low', secs <= 20);

  renderQueue();
  renderGrillState();
  renderTray();
}

function renderQueue() {
  const next = sim.nextServable();
  const html = [];

  for (let i = 0; i < BALANCE.queueCapacity; i++) {
    const c = sim.slots[i];
    if (!c) {
      html.push('<div class="seat seat--empty"></div>');
      continue;
    }

    const isNext = next && c.id === next.id;
    const served = c.state === STATE.RECEIVING || c.state === STATE.EATING;
    const gone = c.state === STATE.ANGRY;

    let mood = moodOf(c.patience);
    if (served) mood = 'eating';
    if (gone) mood = 'angry';

    const cls = ['seat'];
    if (isNext) cls.push('seat--next');
    if (served) cls.push('seat--served');
    if (gone) cls.push('seat--gone');

    let bottom;
    if (served) {
      bottom = `<div class="seat__stars">${'★'.repeat(c.stars)}</div>`;
    } else if (gone) {
      bottom = '<div class="seat__order">BỎ ĐI</div>';
    } else if (c.state === STATE.WAITING) {
      const pct = Math.max(0, Math.min(1, c.patience)) * 100;
      bottom = `<div class="seat__patience"><i style="width:${pct}%;background:${patienceColour(c.patience)}"></i></div>
                <div class="seat__order">CƠM + SƯỜN</div>`;
    } else {
      bottom = '<div class="seat__order">đang tới…</div>';
    }

    html.push(`<div class="${cls.join(' ')}">
      ${faceSvg(mood)}
      <div class="seat__name">${escapeHtml(c.name)}</div>
      <div class="seat__tag">${c.archetype.short}</div>
      ${bottom}
    </div>`);
  }
  el.queue.innerHTML = html.join('');
}

function renderGrillState() {
  if (!sim.grill.occupied) {
    el.grillState.textContent = 'Bếp trống';
    el.grillState.dataset.d = 'empty';
    el.btnGrill.classList.remove('is-hot');
    el.btnGrillLabel.textContent = 'Đặt sườn lên';
    return;
  }
  const d = evaluateDoneness(sim.grill.elapsed);
  el.grillState.textContent = DONENESS_LABEL[d];
  el.grillState.dataset.d = d;
  el.btnGrill.classList.toggle('is-hot', d === DONENESS.PERFECT);
  el.btnGrillLabel.textContent = d === DONENESS.RAW ? 'Chưa chín' : 'Lấy sườn ra';
}

function renderTray() {
  const rice = sim.hasComponent('rice');
  const pork = sim.hasComponent('pork');
  el.trayRice.classList.toggle('is-on', rice);
  el.trayPork.classList.toggle('is-on', pork);
  const ready = rice && pork;
  el.trayReady.classList.toggle('is-on', ready);
  el.btnServe.classList.toggle('is-ready', ready && !!sim.nextServable());
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (ch) => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]
  ));
}

// ---------------------------------------------------------------------------
// Feedback
// ---------------------------------------------------------------------------

function toast(msg, kind = '') {
  el.toast.textContent = msg;
  el.toast.className = 'toast' + (kind ? ' is-' + kind : '');
  toastUntil = performance.now() + 1700;
}

function floatText(text, colour) {
  const r = el.canvas.getBoundingClientRect();
  const n = document.createElement('div');
  n.className = 'float';
  n.textContent = text;
  // Stagger against anything still in flight so a cook and a serve firing
  // back-to-back don't stack on top of each other.
  const offset = el.floats.childElementCount * 26;
  n.style.left = `${r.left + r.width / 2}px`;
  n.style.top = `${r.top + r.height / 2 + offset}px`;
  if (colour) n.style.color = colour;
  el.floats.appendChild(n);
  setTimeout(() => n.remove(), 1200);
}

function buzz(ms) {
  if (navigator.vibrate) { try { navigator.vibrate(ms); } catch { /* ignore */ } }
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

const REFUSAL = {
  [CMD.ALREADY_ON_PLATE]: ['Đĩa đã có rồi', ''],
  [CMD.GRILL_OCCUPIED]: ['Bếp đang bận', ''],
  [CMD.PORK_RAW]: ['Sườn còn sống — đợi thêm!', 'bad'],
  [CMD.NO_CUSTOMER]: ['Chưa có khách đợi món', ''],
  [CMD.PLATE_INCOMPLETE]: ['Cần cơm + sườn', 'bad'],
};

function report(result) {
  const r = REFUSAL[result];
  if (r) toast(r[0], r[1]);
}

function doRice() { report(sim.scoopRice()); render(); }

function doGrill() {
  report(sim.grill.occupied ? sim.takePork() : sim.placePork());
  render();
}

function doServe() { report(sim.serve()); render(); }

// ---------------------------------------------------------------------------
// Loop
// ---------------------------------------------------------------------------

function frame(ts) {
  if (!running) return;
  if (!lastTs) lastTs = ts;
  acc += Math.min(0.25, (ts - lastTs) / 1000);
  lastTs = ts;

  while (acc >= FIXED_STEP) {
    sim.tick(FIXED_STEP);
    acc -= FIXED_STEP;
    if (sim.over) break;
  }

  drawGrill(ts);
  render();

  if (toastUntil && ts > toastUntil) {
    el.toast.textContent = '';
    el.toast.className = 'toast';
    toastUntil = 0;
  }

  if (sim.over) { running = false; showResults(); return; }
  raf = requestAnimationFrame(frame);
}

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

function showResults() {
  const r = sim.result;
  const row = (k, v, cls = '') =>
    `<div class="ledger__row"><span>${k}</span><span class="${cls}">${v}</span></div>`;

  el.resultsBody.innerHTML = `
    <div class="ledger">
      ${row('Doanh thu', '+' + formatMoney(r.revenue), 'pos')}
      ${row('Tiền tip', '+' + formatMoney(r.tips), 'pos')}
      ${row('Nguyên liệu', '−' + formatMoney(r.ingredientCost), 'neg')}
      ${row('Thưởng mục tiêu', '+' + formatMoney(r.goalBonus), 'pos')}
      <div class="ledger__row ledger__row--total">
        <span>Lợi nhuận</span><span>${formatMoney(sim.profit)}</span>
      </div>
    </div>
    <div class="stats">
      <div class="stat"><div class="stat__k">Khách phục vụ</div><div class="stat__v">${r.served}</div></div>
      <div class="stat"><div class="stat__k">Đánh giá TB</div><div class="stat__v">${sim.averageStars.toFixed(1)}★</div></div>
      <div class="stat"><div class="stat__k">Khách bỏ đi</div><div class="stat__v">${r.lost}</div></div>
      <div class="stat"><div class="stat__k">Sườn cháy</div><div class="stat__v">${r.burned}</div></div>
    </div>
    <div class="goal ${r.goalMet ? 'goal--met' : 'goal--miss'}">
      ${r.goalMet
        ? `Mục tiêu hoàn thành — phục vụ ${r.served}/${r.goalTarget} khách. Thưởng ${formatMoney(BALANCE.day1GoalBonusDong)}.`
        : `Chưa đạt mục tiêu — phục vụ ${r.served}/${r.goalTarget} khách.`}
    </div>
    ${r.bestName ? `<p>Khách hài lòng nhất: <b style="color:var(--chalk)">${escapeHtml(r.bestName)}</b> — ${r.bestStars}★</p>` : ''}
    <div class="note">
      Đây là bản thử nghiệm Ngày 1. Câu hỏi quan trọng nhất:
      <b style="color:var(--ember-hot)">nướng sườn có đã tay không?</b>
      Nếu chưa, cần sửa cơ chế nướng trước khi làm thêm bất cứ thứ gì.
    </div>`;
  el.results.hidden = false;
}

// ---------------------------------------------------------------------------
// Wiring
// ---------------------------------------------------------------------------

function newGame() {
  sim = new DaySimulation((Math.random() * 1e9) | 0);
  embers = [];

  sim.on('arrive', (c) => toast(`${c.name} vừa tới`, ''));
  sim.on('burn', () => {
    toast('Sườn cháy! Mất 12,000đ', 'bad');
    floatText('−' + formatMoney(BALANCE.porkCostDong), '#d64545');
    buzz([40, 60, 40]);
  });
  sim.on('angry', (c) => { toast(`${c.name} bỏ đi vì đợi lâu`, 'bad'); buzz(50); });
  sim.on('cooked', (e) => {
    if (e.doneness === DONENESS.PERFECT) {
      toast('Vừa chín! Chất lượng 100', 'hot');
      floatText('HOÀN HẢO', '#ffc93c');
      buzz(18);
    } else {
      toast(`Sườn ${e.doneness === DONENESS.COOKING ? 'còn tái' : 'hơi quá'} — chất lượng ${e.quality}`, '');
      buzz(8);
    }
  });
  sim.on('served', (e) => {
    const tip = e.tip > 0 ? ` +tip ${formatMoney(e.tip)}` : '';
    toast(`${'★'.repeat(e.stars)}  ${e.customer.name}${tip}`, 'good');
    floatText('+' + formatMoney(e.paid + e.tip), '#7fd3a2');
    buzz(12);
  });

  el.results.hidden = true;
  running = true;
  lastTs = 0;
  acc = 0;
  sizeCanvas();
  render();
  cancelAnimationFrame(raf);
  raf = requestAnimationFrame(frame);
}

el.btnRice.addEventListener('click', doRice);
el.btnGrill.addEventListener('click', doGrill);
el.btnServe.addEventListener('click', doServe);
el.btnStart.addEventListener('click', () => { el.intro.hidden = true; newGame(); });
el.btnAgain.addEventListener('click', newGame);

window.addEventListener('keydown', (e) => {
  if (el.intro.hidden === false || !sim || sim.over) return;
  if (e.key === '1') { e.preventDefault(); doRice(); }
  else if (e.code === 'Space') { e.preventDefault(); doGrill(); }
  else if (e.key === 'Enter') { e.preventDefault(); doServe(); }
});

window.addEventListener('resize', () => { sizeCanvas(); });

// Draw the empty grill behind the intro card so the page is not blank.
sim = new DaySimulation(1);
sizeCanvas();
render();
drawGrill(0);
