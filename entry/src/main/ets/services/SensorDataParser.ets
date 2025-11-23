import { DTWUtils } from './DtwUtils'
import { SensorFrame } from '../SensorData'

/**
 * Detailed analysis of the raw DTW computation.
 */
export interface RepMetrics {
  accelerationDtw: number;
  quaternionDtw: number;
  combinedScore: number; // Weighted average of Acc and Quat
}

/**
 * The final verdict returned to the UI.
 */
export interface RepResult {
  isSuccessful: boolean;
  failureReason?: FailureReason;
  score: number;       // 0.0 (Perfect) to Infinity (Bad)
  tempoRatio: number;  // 1.0 is perfect match, <1.0 fast, >1.0 slow
  avgHeartRate: number;
}

export enum FailureReason {
  FORM_BAD = 'FORM_BAD',
  TOO_FAST = 'TOO_FAST',
  TOO_SLOW = 'TOO_SLOW',
  TOO_SHORT = 'TOO_SHORT',  // Likely noise/bump
  NO_REFERENCE = 'NO_REFERENCE',
  HEARTRATE_LOW = 'HEARTRATE_LOW',
  HEARTRATE_HIGH = 'HEARTRATE_HIGH',
}

export class SensorDataParser {

  private static instance: SensorDataParser;
  private constructor() {}
  public static getInstance(): SensorDataParser {
    if (!SensorDataParser.instance) {
      SensorDataParser.instance = new SensorDataParser();
    }
    return SensorDataParser.instance;
  }

  protected referenceAcc: number[][] = [];
  protected referenceQuat: number[][] = [];
  protected referenceLength: number = 0;
  protected referenceHeartRate: number = 0;

  // --- CONFIGURATION ---
  protected readonly TARGET_SIZE = 60;
  protected readonly DTW_WINDOW = 10;

  // Weights: Accel describes the "Path", Quat describes "Stability".
  // Usually path is more critical for counting.
  private readonly ACC_WEIGHT = 0.6;
  private readonly QUAT_WEIGHT = 0.4;

  // Thresholds
  private readonly THRESH_FORM_FAIL = 1.5; // > 1.5 deviation is a fail
  private readonly THRESH_TEMPO_FAST = 0.7; // < 70% duration of ref
  private readonly THRESH_TEMPO_SLOW = 1.5; // > 150% duration of ref
  private readonly MIN_REP_LENGTH = 15;     // Ignore noise < 0.75s (at 20Hz)
  private readonly MAX_HEART_RATE = 200;     // Heartrate above 200 is dangerous

  /**
   * Main entry point. Takes raw sensor frames and returns a full analysis.
   */
  processRepData(rep: SensorFrame[]): RepResult {
    // 1. Safety Checks
    if (this.referenceLength === 0) {
      return this.createFailResult(FailureReason.NO_REFERENCE);
    }
    if (rep.length < this.MIN_REP_LENGTH) {
      return this.createFailResult(FailureReason.TOO_SHORT);
    }

    // 2. Calculate Tempo
    const tempoRatio = rep.length / this.referenceLength;

    // 3. Calculate Form (DTW)
    const metrics = this.computeDtw(rep);

    // 4. Calculate HeartRate
    const avgHeartRate = this.getAverageHeartRate(rep);

    // 4. Evaluate Failure Conditions
    // Priority: Form > Speed. If form is bad, speed doesn't matter.
    if (avgHeartRate > this.MAX_HEART_RATE) {
      return this.createFailResult(FailureReason.HEARTRATE_HIGH, metrics.combinedScore, tempoRatio)
    }

    if (metrics.combinedScore > this.THRESH_FORM_FAIL) {
      return this.createFailResult(FailureReason.FORM_BAD, metrics.combinedScore, tempoRatio);
    }

    if (tempoRatio < this.THRESH_TEMPO_FAST) {
      return this.createFailResult(FailureReason.TOO_FAST, metrics.combinedScore, tempoRatio);
    }

    if (tempoRatio > this.THRESH_TEMPO_SLOW) {
      return this.createFailResult(FailureReason.TOO_SLOW, metrics.combinedScore, tempoRatio);
    }

    // 5. Success!
    return {
      isSuccessful: true,
      score: metrics.combinedScore,
      tempoRatio: tempoRatio,
      avgHeartRate: avgHeartRate
    };
  }

  setReference(input: SensorFrame[]): RepResult {
    const accArray = this.getAccArray(input)
    this.referenceAcc = this.processSignal(accArray);
    const quatArray = this.getQuatArray(input)
    this.referenceQuat = this.processSignal(quatArray)
    this.referenceHeartRate = this.getAverageHeartRate(input)
    this.referenceLength = input.length

    return {
      isSuccessful: true,
      failureReason: undefined,
      score: 0,
      tempoRatio: 0,
      avgHeartRate: this.referenceHeartRate
    }
  }

  private computeDtw (input: SensorFrame[]): RepMetrics {
    const accArray = this.getAccArray(input)
    const processedAcc = this.processSignal(accArray)
    const accTotalDist = DTWUtils.computeVector(processedAcc, this.referenceAcc, this.DTW_WINDOW)
    const accelerationDtw = processedAcc.length > 0 ? (accTotalDist / processedAcc.length) : 100;

    const quatArray = this.getQuatArray(input)
    const processedQuat = this.processSignal(quatArray)
    const quatTotalDist = DTWUtils.computeVector(processedQuat, this.referenceQuat, this.DTW_WINDOW);
    const quaternionDtw = processedQuat.length > 0 ? (quatTotalDist / processedQuat.length) : 100;

    // Weighted Average Score
    const combinedScore = (accelerationDtw * this.ACC_WEIGHT) + (quaternionDtw * this.QUAT_WEIGHT);
    return {accelerationDtw, quaternionDtw, combinedScore}
  }

  private createFailResult(reason: FailureReason, score: number = 0, tempo: number = 0, avgHeartRate: number = 0): RepResult {
    return {
      isSuccessful: false,
      failureReason: reason,
      score: score,
      tempoRatio: tempo,
      avgHeartRate: avgHeartRate
    };
  }

  private processSignal(input: number[][]) {
    if (input.length === 0) return [];
    const factor = Math.ceil(input.length / this.TARGET_SIZE);

    const downSampledAcc = DTWUtils.downsampleVector(input, factor)
    const normalizedAcc = DTWUtils.zNormalizeVector(downSampledAcc)
    return normalizedAcc
  }

  private getAccArray(input: SensorFrame[]): [number, number, number][] {
    return input.map(frame => [frame.accel.x, frame.accel.y, frame.accel.z])
  }

  private getQuatArray(input: SensorFrame[]): [number, number, number, number][] {
    return input.map(frame => [frame.quaternion.x, frame.quaternion.y, frame.quaternion.z, frame.quaternion.w])
  }

  private getAverageHeartRate(input: SensorFrame[]): number {
    let sum = 0;
    for (const x of input) sum += x.heartRate;
    const avg = sum / input.length;
    return avg
  }
}