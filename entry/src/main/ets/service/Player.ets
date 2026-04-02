import { audio } from '@kit.AudioKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { streamInfo } from './Constants';

@Observed
export default class Player {
  private player?: audio.AudioRenderer;
  state: string = 'idle';
  private fileFd?: number;
  private fileReadOffset: number = 0;

  private async init(filePath: string) {
    try {
      this.player = await audio.createAudioRenderer({
        rendererInfo: {
          usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
          rendererFlags: 0
        },
        streamInfo: streamInfo
      });

      this.player.on('outputDeviceChangeWithInfo', (deviceChangeInfo: audio.AudioStreamDeviceChangeInfo) => {
        if (this.state === 'STATE_RUNNING') {
          this.pause();
        }
      });

      this.player.on('audioInterrupt', (interruptEvent: audio.InterruptEvent) => {
        if (interruptEvent.forceType === audio.InterruptForceType.INTERRUPT_FORCE) {
          switch (interruptEvent.hintType) {
            case audio.InterruptHint.INTERRUPT_HINT_PAUSE:
              console.info('Force paused. Update playing status and stop writing');
              this.pause();
              break;
            case audio.InterruptHint.INTERRUPT_HINT_STOP:
              console.info('Force stopped. Update playing status and stop writing');
              this.stop();
              break;
            default:
              break;
          }
        }
      });

      this.player.on('stateChange', (state: audio.AudioState) => {
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

        console.info(`audioRenderer state changed to: ${this.state}`);
      });

      const audioFile: fs.File = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      this.fileFd = audioFile.fd; // Obtain the file FD.
      console.info(`file fd: ${this.fileFd}`);

      this.fileReadOffset = 0;

      this.player.on('writeData', (buffer) => {
        console.info(`writeData | len: ${buffer.byteLength} | offset: ${this.fileReadOffset} | fd: ${this.fileFd}`);
        try {
          const readLength = fs.readSync(this.fileFd, buffer, {
            offset: this.fileReadOffset,
            length: buffer.byteLength
          });

          this.fileReadOffset += readLength;

          if (readLength === 0) {
            console.info('stop now');
            this.player?.off('writeData');
            this.stop();
          }

          return audio.AudioDataCallbackResult.VALID;
        } catch (error) {
          console.error('Error reading file:', error);
          return audio.AudioDataCallbackResult.INVALID;
        }
      });

      await this.player.start();
    } catch (e) {
      console.error(`init err: ${e}`);
    }
  }

  async start(filePath: string) {
    try {
      if (!this.player) {
        console.info('init');
        await this.init(filePath);
      } else {
        console.info('start');
        await this.player.start();
      }
    } catch (e) {
      console.error('start err:', e);
    }
  }

  async pause() {
    this.player?.pause();
  }

  async stop() {
    try {
      await this.player?.stop();
      await this.player?.release();
      fs.closeSync(this.fileFd);
      this.player = undefined;
    } catch (e) {
      console.error('stop err:', e.code, e.message);
      throw new Error(e.message);
    }
  }
}