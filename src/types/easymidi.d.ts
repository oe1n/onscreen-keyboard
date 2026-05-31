declare module 'easymidi' {
  export interface NoteMessage {
    note: number;
    velocity: number;
    channel: number;
  }
  export interface CCMessage {
    controller: number;
    value: number;
    channel: number;
  }
  export class Output {
    constructor(name: string, virtual?: boolean);
    send(type: 'noteon' | 'noteoff', msg: NoteMessage): void;
    send(type: 'cc', msg: CCMessage): void;
    close(): void;
  }
  export class Input {
    constructor(name: string, virtual?: boolean);
    close(): void;
  }
  export function getOutputs(): string[];
  export function getInputs(): string[];
}
