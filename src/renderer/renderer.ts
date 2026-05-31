interface KeyDef {
  code: string;
  semitone: number;
  isBlack: boolean;
  label: string;
}

// FL Studio-style computer keyboard piano layout.
// A row = white naturals starting at C; Q/W/E... black sharps above.
const KEY_MAP: KeyDef[] = [
  { code: 'KeyA',      semitone: 0,  isBlack: false, label: 'A' },
  { code: 'KeyW',      semitone: 1,  isBlack: true,  label: 'W' },
  { code: 'KeyS',      semitone: 2,  isBlack: false, label: 'S' },
  { code: 'KeyE',      semitone: 3,  isBlack: true,  label: 'E' },
  { code: 'KeyD',      semitone: 4,  isBlack: false, label: 'D' },
  { code: 'KeyF',      semitone: 5,  isBlack: false, label: 'F' },
  { code: 'KeyT',      semitone: 6,  isBlack: true,  label: 'T' },
  { code: 'KeyG',      semitone: 7,  isBlack: false, label: 'G' },
  { code: 'KeyY',      semitone: 8,  isBlack: true,  label: 'Y' },
  { code: 'KeyH',      semitone: 9,  isBlack: false, label: 'H' },
  { code: 'KeyU',      semitone: 10, isBlack: true,  label: 'U' },
  { code: 'KeyJ',      semitone: 11, isBlack: false, label: 'J' },
  { code: 'KeyK',      semitone: 12, isBlack: false, label: 'K' },
  { code: 'KeyO',      semitone: 13, isBlack: true,  label: 'O' },
  { code: 'KeyL',      semitone: 14, isBlack: false, label: 'L' },
  { code: 'KeyP',      semitone: 15, isBlack: true,  label: 'P' },
  { code: 'Semicolon', semitone: 16, isBlack: false, label: ';' },
  { code: 'Quote',     semitone: 17, isBlack: false, label: "'" },
];

const NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
const VELOCITY = 100;
const SUSTAIN_CC = 64;
const MIN_OCTAVE = 0;
const MAX_OCTAVE = 8;

let octave = 4;
let sustainOn = false;

const heldKeys = new Set<string>();      // keys currently physically down
const keyToNote = new Map<string, number>(); // key code → midi note currently sounding
const keyElements = new Map<string, HTMLElement>();
let mouseHeldDef: KeyDef | null = null;

const pianoEl  = document.getElementById('piano')!;
const octaveEl = document.getElementById('octave-value')!;
const sustainEl = document.getElementById('sustain-value')!;

function midiFor(semitone: number): number {
  // MIDI: C-1 = 0, so C{oct} = (oct + 1) * 12
  return (octave + 1) * 12 + semitone;
}

function noteName(midi: number): string {
  return NOTE_NAMES[midi % 12] + (Math.floor(midi / 12) - 1);
}

function buildPiano() {
  pianoEl.innerHTML = '';
  keyElements.clear();

  const whites = KEY_MAP.filter(k => !k.isBlack);
  const blacks = KEY_MAP.filter(k => k.isBlack);
  const whiteW = 100 / whites.length;

  whites.forEach((def, i) => {
    const el = document.createElement('div');
    el.className = 'white-key';
    el.style.left  = `${i * whiteW}%`;
    el.style.width = `${whiteW}%`;
    el.dataset.code = def.code;
    el.innerHTML = `
      <span class="note-label"></span>
      <span class="key-label">${def.label}</span>
    `;
    pianoEl.appendChild(el);
    keyElements.set(def.code, el);
  });

  blacks.forEach(def => {
    const prevIdx = whites.findIndex(w => w.semitone === def.semitone - 1);
    if (prevIdx < 0) return;
    const blackW = whiteW * 0.6;
    const left = (prevIdx + 1) * whiteW - blackW / 2;
    const el = document.createElement('div');
    el.className = 'black-key';
    el.style.left  = `${left}%`;
    el.style.width = `${blackW}%`;
    el.dataset.code = def.code;
    el.innerHTML = `<span class="key-label">${def.label}</span>`;
    pianoEl.appendChild(el);
    keyElements.set(def.code, el);
  });

  refreshNoteLabels();
}

function refreshNoteLabels() {
  KEY_MAP.forEach(def => {
    const el = keyElements.get(def.code);
    if (!el) return;
    const labelEl = el.querySelector('.note-label');
    if (labelEl) labelEl.textContent = noteName(midiFor(def.semitone));
  });
}

function playKey(def: KeyDef) {
  if (keyToNote.has(def.code)) return;
  const midi = midiFor(def.semitone);
  keyToNote.set(def.code, midi);
  window.midi.noteOn(midi, VELOCITY);
  keyElements.get(def.code)?.classList.add('active');
}

function releaseKey(def: KeyDef) {
  const midi = keyToNote.get(def.code);
  if (midi === undefined) return;
  keyToNote.delete(def.code);
  window.midi.noteOff(midi);
  keyElements.get(def.code)?.classList.remove('active');
}

function shiftOctave(delta: number) {
  const next = Math.max(MIN_OCTAVE, Math.min(MAX_OCTAVE, octave + delta));
  if (next === octave) return;
  octave = next;
  octaveEl.textContent = String(octave);
  refreshNoteLabels();
}

function setSustain(on: boolean) {
  if (on === sustainOn) return;
  sustainOn = on;
  window.midi.cc(SUSTAIN_CC, on ? 127 : 0);
  sustainEl.textContent = on ? 'ON' : 'OFF';
  sustainEl.classList.toggle('on', on);
  sustainEl.classList.toggle('off', !on);
}

function releaseAll() {
  keyToNote.forEach((midi) => window.midi.noteOff(midi));
  keyToNote.clear();
  heldKeys.clear();
  mouseHeldDef = null;
  document.querySelectorAll('.active').forEach(el => el.classList.remove('active'));
  if (sustainOn) setSustain(false);
}

document.addEventListener('keydown', (e) => {
  if (e.repeat) { e.preventDefault(); return; }

  if (e.code === 'Escape') {
    window.midi.hideWindow();
    e.preventDefault();
    return;
  }

  // Octave down: Z, Left Shift, or Left Arrow
  if (e.code === 'KeyZ' || e.code === 'ShiftLeft' || e.code === 'ArrowLeft') {
    if (!heldKeys.has(e.code)) {
      heldKeys.add(e.code);
      shiftOctave(-1);
    }
    e.preventDefault();
    return;
  }

  // Octave up: X, Right Shift, or Right Arrow
  if (e.code === 'KeyX' || e.code === 'ShiftRight' || e.code === 'ArrowRight') {
    if (!heldKeys.has(e.code)) {
      heldKeys.add(e.code);
      shiftOctave(+1);
    }
    e.preventDefault();
    return;
  }

  // Sustain pedal: Tab
  if (e.code === 'Tab') {
    setSustain(true);
    e.preventDefault();
    return;
  }

  const def = KEY_MAP.find(k => k.code === e.code);
  if (def) {
    heldKeys.add(e.code);
    playKey(def);
    e.preventDefault();
  }
});

document.addEventListener('keyup', (e) => {
  heldKeys.delete(e.code);

  if (e.code === 'Tab') {
    setSustain(false);
    e.preventDefault();
    return;
  }

  // Octave keys are one-shot — nothing to release on keyup.
  if (e.code === 'KeyZ' || e.code === 'ShiftLeft' || e.code === 'ArrowLeft' ||
      e.code === 'KeyX' || e.code === 'ShiftRight' || e.code === 'ArrowRight') {
    return;
  }

  const def = KEY_MAP.find(k => k.code === e.code);
  if (def) {
    releaseKey(def);
    e.preventDefault();
  }
});

window.addEventListener('blur', () => releaseAll());
window.midi.onReleaseAll(() => releaseAll());

// Mouse interaction: click + drag glides between keys (D→E releases D, plays E).
function keyDefFromEvent(target: EventTarget | null): KeyDef | null {
  const el = (target as HTMLElement | null)?.closest?.(
    '.white-key, .black-key'
  ) as HTMLElement | null;
  const code = el?.dataset.code;
  if (!code) return null;
  return KEY_MAP.find(k => k.code === code) ?? null;
}

function setMouseKey(def: KeyDef | null) {
  if (mouseHeldDef === def) return;
  if (mouseHeldDef) releaseKey(mouseHeldDef);
  mouseHeldDef = def;
  if (def) playKey(def);
}

pianoEl.addEventListener('mousedown', (e) => {
  const def = keyDefFromEvent(e.target);
  if (def) {
    setMouseKey(def);
    e.preventDefault();
  }
});

pianoEl.addEventListener('mouseover', (e) => {
  if (e.buttons !== 1) return;
  const def = keyDefFromEvent(e.target);
  if (def) setMouseKey(def);
});

pianoEl.addEventListener('mouseleave', (e) => {
  if (e.buttons === 1) setMouseKey(null);
});

document.addEventListener('mouseup', () => setMouseKey(null));

buildPiano();
