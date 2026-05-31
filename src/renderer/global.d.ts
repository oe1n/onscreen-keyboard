interface MidiBridge {
  noteOn: (note: number, velocity: number) => void;
  noteOff: (note: number) => void;
  cc: (controller: number, value: number) => void;
  hideWindow: () => void;
  onReleaseAll: (cb: () => void) => void;
}

interface Window {
  midi: MidiBridge;
}
