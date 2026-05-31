import { contextBridge, ipcRenderer } from 'electron';

contextBridge.exposeInMainWorld('midi', {
  noteOn: (note: number, velocity: number) =>
    ipcRenderer.send('midi-note-on', { note, velocity }),
  noteOff: (note: number) =>
    ipcRenderer.send('midi-note-off', { note }),
  cc: (controller: number, value: number) =>
    ipcRenderer.send('midi-cc', { controller, value }),
  hideWindow: () => ipcRenderer.send('hide-window'),
  onReleaseAll: (cb: () => void) => {
    ipcRenderer.on('release-all', () => cb());
  },
});
