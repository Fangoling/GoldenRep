import { common } from '@kit.AbilityKit';
import { AudioPlayer } from '../services/AudioPlayer';
@Entry
@Component
struct TestAudioView {
  // Instantiate the class
  private player: AudioPlayer = new AudioPlayer();

  // UI State
  @State status: string = 'idle';

  async aboutToAppear() {
    // 1. Initialize the player
    await this.player.init();

    // 2. Subscribe to status changes to update the UI
    this.player.onStatusChange((newState: string) => {
      this.status = newState;
    });

    // 3. Load the file
    const context = getContext(this) as common.UIAbilityContext;
    await this.player.loadRawAudio(context, 'beat.mp3');
  }

  aboutToDisappear() {
    // Clean up memory
    this.player.release();
  }

  build() {
    Column({ space: 20 }) {
      Text(`Status: ${this.status}`)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)

      Row({ space: 20 }) {
        Button('Play')
          .onClick(() => {
            this.player.play();
          })
          // Optional: Disable button if not ready
          .enabled(this.status === 'prepared' || this.status === 'paused' || this.status === 'completed')
          .opacity(this.status === 'playing' ? 0.5 : 1.0)

        Button('Pause')
          .onClick(() => {
            this.player.pause();
          })
          .enabled(this.status === 'playing')
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}