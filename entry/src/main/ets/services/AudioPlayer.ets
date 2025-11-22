import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class AudioPlayer {
  private avPlayer: media.AVPlayer | undefined = undefined;
  private statusCallback: ((state: string) => void) | undefined = undefined;
  private currentStatus: string = 'idle';

  /**
   * Initializes the AVPlayer instance.
   * Must be called before loading or playing.
   */
  async init() {
    try {
      this.avPlayer = await media.createAVPlayer();
      this.setAVPlayerCallbacks();
    } catch (error) {
      console.error(`Failed to create AVPlayer: ${error}`);
    }
  }

  /**
   * Registers a callback to listen for state changes (e.g., 'playing', 'paused', 'prepared').
   * Use this to update your UI @State.
   */
  onStatusChange(callback: (state: string) => void) {
    this.statusCallback = callback;
  }

  /**
   * Loads an audio file from the rawfile folder.
   * @param context The UIAbilityContext (required to access resourceManager)
   * @param filename The name of the file in src/main/resources/rawfile/
   */
  async loadRawAudio(context: common.UIAbilityContext, filename: string) {
    if (!this.avPlayer) return;

    try {
      const fileDescriptor = await context.resourceManager.getRawFd(filename);

      // Setting fdSrc triggers the 'initialized' state
      this.avPlayer.fdSrc = {
        fd: fileDescriptor.fd,
        offset: fileDescriptor.offset,
        length: fileDescriptor.length
      };
    } catch (error) {
      console.error(`Error loading raw file: ${error}`);
    }
  }

  play() {
    // Guard clause: Only play if valid states
    const validStates = ['prepared', 'paused', 'completed'];
    if (this.avPlayer && validStates.includes(this.currentStatus)) {
      this.avPlayer.play();
    }
  }

  pause() {
    if (this.avPlayer && this.currentStatus === 'playing') {
      this.avPlayer.pause();
    }
  }

  release() {
    if (this.avPlayer) {
      this.avPlayer.release();
      this.avPlayer = undefined;
    }
  }

  // --- Internal Helper: State Machine ---
  private setAVPlayerCallbacks() {
    if (!this.avPlayer) return;

    this.avPlayer.on('stateChange', (state: media.AVPlayerState) => {
      this.currentStatus = state;

      // Notify the UI
      if (this.statusCallback) {
        this.statusCallback(state);
      }

      // Handle internal logic
      switch (state) {
        case 'initialized':
          this.avPlayer?.prepare(); // Automatically prepare when source is set
          break;
        case 'prepared':
          console.info('AudioPlayer: Ready to play');
          break;
        case 'completed':
          console.info('AudioPlayer: Playback finished');
          break;
      }
    });

    this.avPlayer.on('error', (err: BusinessError) => {
      console.error(`AudioPlayer Error: ${err.message}`);
    });
  }
}