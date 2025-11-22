import sensor from '@ohos.sensor';
import common from '@ohos.app.ability.common';
import { SensorFrame, SensorBuffer, Vector3, Quaternion } from '../SensorData';
import { FileUtils } from '../services/FileUtils';
import { GraphRendererService } from '../services/GraphRendererService'; // This now resolves to GraphRenderer.ets

@Entry
@Component
struct GhostRecorder {
  // --- STATE VARIABLES ---
  @State isRecording: boolean = false;
  @State durationText: string = "0.00s";
  @State frameCount: number = 0;
  @State saveStatus: string = "";

  // --- INTERNAL VARIABLES ---
  private timerId: number = -1;
  private startTime: number = 0;

  private buffer: SensorBuffer = new SensorBuffer();
  private recordedData: SensorFrame[] = [];

  // --- GRAPHING SETUP ---
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  // Instantiate the helper class
  private graphRenderer: GraphRendererService = new GraphRendererService();

  aboutToAppear() {
    this.initSensors();
  }

  aboutToDisappear() {
    this.stopSensors();
  }

  // --- SENSOR SETUP ---
  initSensors() {
    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, (data) => {
        this.buffer.accelX = data.x;
        this.buffer.accelY = data.y;
        this.buffer.accelZ = data.z;
      }, { interval: 20000000 }); // 20ms

      sensor.on(sensor.SensorId.ROTATION_VECTOR, (data) => {
        this.buffer.quatX = data.x;
        this.buffer.quatY = data.y;
        this.buffer.quatZ = data.z;
        this.buffer.quatW = data.w;
      }, { interval: 20000000 });

    } catch (err) {
      console.error('Sensor init failed: ' + JSON.stringify(err));
    }
  }

  stopSensors() {
    try {
      sensor.off(sensor.SensorId.ACCELEROMETER);
      sensor.off(sensor.SensorId.ROTATION_VECTOR);
    } catch (err) {
      console.error('Sensor stop failed');
    }
  }

  // --- RECORDING LOOP ---
  startRecording() {
    this.recordedData = [];
    this.graphRenderer.reset(); // Reset graph helper
    this.isRecording = true;
    this.saveStatus = "";
    this.startTime = new Date().getTime();

    this.timerId = setInterval(() => {
      this.snapshotFrame();
    }, 50);
  }

  stopRecording() {
    clearInterval(this.timerId);
    this.isRecording = false;

    // DELEGATE: Call the FileUtils to save
    let context = getContext(this) as common.UIAbilityContext;
    this.saveStatus = FileUtils.saveJson(context, 'ghost_rep.json', this.recordedData);
  }

  snapshotFrame() {
    let now = new Date().getTime();
    let elapsed = now - this.startTime;

    let frame = new SensorFrame();
    frame.timestamp = now;
    frame.elapsed_ms = elapsed;
    frame.accel = new Vector3(this.buffer.accelX, this.buffer.accelY, this.buffer.accelZ);
    frame.quaternion = new Quaternion(this.buffer.quatX, this.buffer.quatY, this.buffer.quatZ, this.buffer.quatW);

    this.recordedData.push(frame);

    // DELEGATE: Update graph data and draw
    this.graphRenderer.pushValue(frame.accel.y);
    this.graphRenderer.draw(this.context);

    this.durationText = (elapsed / 1000).toFixed(2) + "s";
    this.frameCount = this.recordedData.length;
  }

  // --- UI BUILD ---
  build() {
    Stack() {
      Rect().width('100%').height('100%').fill(Color.Black)

      Column() {
        Text("GHOST REC")
          .fontColor(Color.Blue)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 5 })

        Canvas(this.context)
          .width(200)
          .height(60)
          .backgroundColor('#111111')
          .margin({ bottom: 10 })
          .onReady(() => {
            // Initial draw (optional)
          })

        Text(this.durationText)
          .fontColor(Color.White)
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 2 })

        Text(`Frames: ${this.frameCount}`)
          .fontColor(Color.Gray)
          .fontSize(10)
          .margin({ bottom: 10 })

        if (!this.isRecording) {
          Button("RECORD")
            .width('60%')
            .height(35)
            .backgroundColor(Color.Blue)
            .fontSize(14)
            .onClick(() => { this.startRecording(); })
        } else {
          Button("STOP")
            .width('60%')
            .height(35)
            .backgroundColor(Color.Red)
            .fontSize(14)
            .onClick(() => { this.stopRecording(); })
        }

        if (this.saveStatus !== "") {
          Text(this.saveStatus)
            .fontColor(Color.Yellow)
            .fontSize(10)
            .margin({top: 10})
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
  }
}