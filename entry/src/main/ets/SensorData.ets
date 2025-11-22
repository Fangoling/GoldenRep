export class Vector3 {
  x: number = 0;
  y: number = 0;
  z: number = 0;

  constructor(x: number = 0, y: number = 0, z: number = 0) {
    this.x = x;
    this.y = y;
    this.z = z;
  }
}

export class Quaternion {
  x: number = 0;
  y: number = 0;
  z: number = 0;
  w: number = 1;

  constructor(x: number = 0, y: number = 0, z: number = 0, w: number = 1) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.w = w;
  }
}

export class SensorFrame {
  timestamp: number = 0;
  elapsed_ms: number = 0;
  
  accel: Vector3 = new Vector3();
  quaternion: Quaternion = new Quaternion();
}

export class SensorBuffer {
  accelX: number = 0;
  accelY: number = 0;
  accelZ: number = 0;

  quatX: number = 0;
  quatY: number = 0;
  quatZ: number = 0;
  quatW: number = 1;
}