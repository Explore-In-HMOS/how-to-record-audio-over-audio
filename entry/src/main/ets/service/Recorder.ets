import { fileIo as fs } from '@kit.CoreFileKit';
import { audio } from '@kit.AudioKit';
import { streamInfo } from './Constants';

@Observed
export default class Recorder {
  private capturer?: audio.AudioCapturer;
  state: string = 'STATE_INVALID';
  private fileFd?: number;
  private fileWriteOffset: number = 0;

  get recording(): boolean {
    return this.state === 'STATE_RUNNING';
  }

  async start(filePath: string) {
    // initialize recorder
    try {
      this.capturer = await audio.createAudioCapturer({
        capturerInfo: {
          source: audio.SourceType.SOURCE_TYPE_MIC,
          capturerFlags: 0
        },
        streamInfo: streamInfo
      });

      this.capturer.on('audioInterrupt', (interruptEvent: audio.InterruptEvent) => {
        if (interruptEvent.forceType === audio.InterruptForceType.INTERRUPT_FORCE) {
          switch (interruptEvent.hintType) {
            case audio.InterruptHint.INTERRUPT_HINT_PAUSE:
            case audio.InterruptHint.INTERRUPT_HINT_STOP:
              this.stopAndSave();
              break;
            default:
              console.info('Invalid interruptEvent');
              break;
          }
        }
      });

      this.capturer.on('stateChange', (state: audio.AudioState) => {
        switch (state) {
          case audio.AudioState.STATE_INVALID:
            this.state = 'STATE_INVALID';
            break;
          case audio.AudioState.STATE_NEW:
            this.state = 'STATE_NEW';
            break;
          case audio.AudioState.STATE_PREPARED:
            this.state = 'STATE_PREPARED';
            break;
          case audio.AudioState.STATE_RUNNING:
            this.state = 'STATE_RUNNING';
            break;
          case audio.AudioState.STATE_STOPPED:
            this.state = 'STATE_STOPPED';
            break;
          case audio.AudioState.STATE_RELEASED:
            this.state = 'STATE_RELEASED';
            break;
          case audio.AudioState.STATE_PAUSED:
            this.state = 'STATE_PAUSED';
            break;
        }

        console.info(`audioCapturer state changed to: ${this.state}`);
      });

      const audioFile: fs.File =
        fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.APPEND);
      this.fileFd = audioFile.fd; // Obtain the file FD.
      console.info(`file fd: ${this.fileFd}`);

      this.fileWriteOffset = 0;

      this.capturer?.on('readData', (buffer) => {
        console.info(`read | len: ${buffer.byteLength} | offset: ${this.fileWriteOffset} | fd: ${this.fileFd}`);
        fs.writeSync(this.fileFd, buffer, {
          offset: this.fileWriteOffset,
          length: buffer.byteLength
        });

        this.fileWriteOffset += buffer.byteLength;
      });

      await this.capturer?.start();
    } catch (e) {
      console.error('start err:', e.code, e.message);
    }
  }

  async stopAndSave() {
    try {
      await this.capturer?.stop();
      await this.capturer?.release();
      fs.closeSync(this.fileFd);
    } catch (e) {
      console.error('stop err:', e.code, e.message);
      throw new Error(e.message);
    }
  }
}