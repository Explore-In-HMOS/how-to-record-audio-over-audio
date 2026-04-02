import Player from '../service/Player';
import Recorder from '../service/Recorder';
import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';

@Entry
@Component
struct Index {
  private filePath: string = `${this.getUIContext().getHostContext()!.filesDir}/record.pcm`;
  @State recorder: Recorder = new Recorder();
  @State player: Player = new Player();

  aboutToAppear(): void {
    this.requestMicPermission();
  }

  build() {
    Column() {
      Text('Recorder State');
      Text(this.recorder.state);

      Button('Record / Stop')
        .size({ height: 40, width: '50%' })
        .onClick(() => {
          if (this.recorder.recording) {
            this.recorder.stopAndSave();
          } else {
            this.recorder.start(this.filePath);
          }
        });

      Text('Player State');
      Text(this.player.state);

      Button('Play / Pause')
        .size({ height: 40, width: '50%' })
        .onClick(() => {
          if (this.player.state === 'STATE_RUNNING') {
            this.player.pause();
          } else {
            this.player.start(this.filePath);
          }
        });

      Button('Release')
        .size({ height: 40, width: '50%' })
        .onClick(() => {
          this.player.stop();
        });
    }
    .justifyContent(FlexAlign.Center)
    .height('100%')
    .width('100%');
  }

  async requestMicPermission() {
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    const context = this.getUIContext().getHostContext();
    const permissions: Permissions[] = ['ohos.permission.MICROPHONE'];

    try {
      // request permission from user
      let granted =
        (await (atManager.requestPermissionsFromUser(context,
          permissions) as Promise<PermissionRequestResult>)).authResults[0] === 0;
      if (!granted) {
        // request permission on settings
        granted = (await atManager.requestPermissionOnSetting(context, permissions))[0] ===
        abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;

        if (!granted) {
          await (this.getUIContext().getHostContext() as common.UIAbilityContext).terminateSelf();
        }
      }
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error(`Failed to check access token. Code is ${err.code}, message is ${err.message}`);
    }
  }
}