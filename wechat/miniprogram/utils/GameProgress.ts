/**
 * GameProgress — 积分/进度持久化管理（从 HarmonyOS/Android 移植）
 * 使用微信小程序 wx.setStorageSync / wx.getStorageSync，替代 SharedPreferences / preferences。
 */

const KEY_TOTAL_SCORE: string = 'total_score';
const KEY_INITIALIZED: string = 'score_initialized';
const KEY_BEST_TIME_PREFIX: string = 'best_time_';
const KEY_COMPLETED_PREFIX: string = 'completed_';
const KEY_THEME_MODE: string = 'theme_mode';
const INITIAL_SCORE: number = 2;
const LEVEL_POINTS: number[] = [2, 5, 7];

export type ThemeMode = 'light' | 'dark';

export class GameProgress {
  private static get(key: string, def: any): any {
    try {
      const v = wx.getStorageSync(key);
      return v === '' || v === undefined ? def : v;
    } catch (_e) {
      return def;
    }
  }

  private static set(key: string, value: any): void {
    try {
      wx.setStorageSync(key, value);
    } catch (_e) {
      // 存储失败时静默降级
    }
  }

  /**
   * 获取总分（自动初始化首次 2 分）
   */
  static getTotalScore(): number {
    const initialized = GameProgress.get(KEY_INITIALIZED, false) as boolean;
    if (!initialized) {
      GameProgress.set(KEY_INITIALIZED, true);
      if (GameProgress.get(KEY_TOTAL_SCORE, undefined) === undefined) {
        GameProgress.set(KEY_TOTAL_SCORE, INITIAL_SCORE);
      }
    }
    return GameProgress.get(KEY_TOTAL_SCORE, INITIAL_SCORE) as number;
  }

  /**
   * 对应难度等级的基础积分
   */
  static pointsForLevel(level: number): number {
    return LEVEL_POINTS[Math.max(0, Math.min(level, LEVEL_POINTS.length - 1))];
  }

  /**
   * 完成题目加分
   */
  static addCompletedLevel(level: number): number {
    const total = GameProgress.getTotalScore() + GameProgress.pointsForLevel(level);
    GameProgress.set(KEY_TOTAL_SCORE, total);
    return total;
  }

  /**
   * 额外加分（连击、纪录等）
   */
  static addBonus(bonus: number): number {
    const total = GameProgress.getTotalScore() + bonus;
    GameProgress.set(KEY_TOTAL_SCORE, total);
    return total;
  }

  /**
   * 获取某难度最佳时间（毫秒），-1 表示无记录
   */
  static getBestTime(level: number): number {
    return GameProgress.get(KEY_BEST_TIME_PREFIX + level, -1) as number;
  }

  /**
   * 记录时间，返回最佳时间
   */
  static recordTime(level: number, millis: number): number {
    const best = GameProgress.getBestTime(level);
    if (best < 0 || millis < best) {
      GameProgress.set(KEY_BEST_TIME_PREFIX + level, millis);
      return millis;
    }
    return best;
  }

  /**
   * 获取某难度完成次数
   */
  static getCompletedCount(level: number): number {
    return GameProgress.get(KEY_COMPLETED_PREFIX + level, 0) as number;
  }

  /**
   * 完成次数 +1
   */
  static addCompletedCount(level: number): number {
    const count = GameProgress.getCompletedCount(level) + 1;
    GameProgress.set(KEY_COMPLETED_PREFIX + level, count);
    return count;
  }

  /**
   * 消费积分，成功返回 true
   */
  static spend(cost: number): boolean {
    const total = GameProgress.getTotalScore();
    if (total < cost) {
      return false;
    }
    GameProgress.set(KEY_TOTAL_SCORE, total - cost);
    return true;
  }

  /**
   * 获取持久化的主题模式，默认浅色
   */
  static getThemeMode(): ThemeMode {
    const mode = GameProgress.get(KEY_THEME_MODE, 'light');
    return mode === 'dark' ? 'dark' : 'light';
  }

  /**
   * 持久化主题模式
   */
  static setThemeMode(mode: ThemeMode): void {
    GameProgress.set(KEY_THEME_MODE, mode === 'dark' ? 'dark' : 'light');
  }

  /**
   * 格式化毫秒为 mm:ss
   */
  static formatTime(millis: number): string {
    const totalSeconds = Math.floor(millis / 1000);
    const min = Math.floor(totalSeconds / 60);
    const sec = totalSeconds % 60;
    const mm = min < 10 ? '0' + min : String(min);
    const ss = sec < 10 ? '0' + sec : String(sec);
    return `${mm}:${ss}`;
  }
}
