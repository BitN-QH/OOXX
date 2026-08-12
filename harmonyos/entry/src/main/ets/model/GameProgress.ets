/**
 * GameProgress — 积分/进度持久化管理
 * 使用 HarmonyOS preferences API，替代 Android SharedPreferences
 *
 * 所有方法内部已捕获 preferences API 可能抛出的 BusinessError，
 * 失败时返回安全默认值，调用方无需再 try-catch。
 */
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'GameProgress';
const PREFERENCES_NAME: string = 'tic_tac_logic_progress';
const KEY_TOTAL_SCORE: string = 'total_score';
const KEY_INITIALIZED: string = 'score_initialized';
const KEY_BEST_TIME_PREFIX: string = 'best_time_';
const KEY_COMPLETED_PREFIX: string = 'completed_';
const KEY_THEME_MODE: string = 'theme_mode';
const INITIAL_SCORE: number = 2;
const LEVEL_POINTS: number[] = [2, 5, 7];

export class GameProgress {
  private static async getPrefs(context: Context): Promise<preferences.Preferences | null> {
    try {
      return await preferences.getPreferences(context, PREFERENCES_NAME);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'getPreferences failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  /**
   * 获取总分（自动初始化首次 2 分）
   */
  static async getTotalScore(context: Context): Promise<number> {
    const prefs = await GameProgress.getPrefs(context);
    if (!prefs) {
      return INITIAL_SCORE;
    }
    try {
      const initialized = await prefs.get(KEY_INITIALIZED, false) as boolean;
      if (!initialized) {
        await prefs.put(KEY_INITIALIZED, true);
        const hasScore = await prefs.has(KEY_TOTAL_SCORE);
        if (!hasScore) {
          await prefs.put(KEY_TOTAL_SCORE, INITIAL_SCORE);
        }
        await prefs.flush();
      }
      return await prefs.get(KEY_TOTAL_SCORE, INITIAL_SCORE) as number;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'getTotalScore failed: %{public}s', JSON.stringify(e));
      return INITIAL_SCORE;
    }
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
  static async addCompletedLevel(context: Context, level: number): Promise<number> {
    const total = await GameProgress.getTotalScore(context) + GameProgress.pointsForLevel(level);
    const prefs = await GameProgress.getPrefs(context);
    if (!prefs) {
      return total;
    }
    try {
      await prefs.put(KEY_TOTAL_SCORE, total);
      await prefs.flush();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'addCompletedLevel failed: %{public}s', JSON.stringify(e));
    }
    return total;
  }

  /**
   * 额外加分（连击、纪录等）
   */
  static async addBonus(context: Context, bonus: number): Promise<number> {
    const total = await GameProgress.getTotalScore(context) + bonus;
    const prefs = await GameProgress.getPrefs(context);
    if (!prefs) {
      return total;
    }
    try {
      await prefs.put(KEY_TOTAL_SCORE, total);
      await prefs.flush();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'addBonus failed: %{public}s', JSON.stringify(e));
    }
    return total;
  }

  /**
   * 获取某难度最佳时间（毫秒），-1 表示无记录
   */
  static async getBestTime(context: Context, level: number): Promise<number> {
    const prefs = await GameProgress.getPrefs(context);
    if (!prefs) {
      return -1;
    }
    try {
      return await prefs.get(KEY_BEST_TIME_PREFIX + level, -1) as number;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'getBestTime failed: %{public}s', JSON.stringify(e));
      return -1;
    }
  }

  /**
   * 记录时间，返回最佳时间
   */
  static async recordTime(context: Context, level: number, millis: number): Promise<number> {
    const best = await GameProgress.getBestTime(context, level);
    if (best < 0 || millis < best) {
      const prefs = await GameProgress.getPrefs(context);
      if (prefs) {
        try {
          await prefs.put(KEY_BEST_TIME_PREFIX + level, millis);
          await prefs.flush();
          return millis;
        } catch (e) {
          hilog.error(DOMAIN, TAG, 'recordTime failed: %{public}s', JSON.stringify(e));
        }
      }
    }
    return best;
  }

  /**
   * 获取某难度完成次数
   */
  static async getCompletedCount(context: Context, level: number): Promise<number> {
    const prefs = await GameProgress.getPrefs(context);
    if (!prefs) {
      return 0;
    }
    try {
      return await prefs.get(KEY_COMPLETED_PREFIX + level, 0) as number;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'getCompletedCount failed: %{public}s', JSON.stringify(e));
      return 0;
    }
  }

  /**
   * 完成次数 +1
   */
  static async addCompletedCount(context: Context, level: number): Promise<number> {
    const count = await GameProgress.getCompletedCount(context, level) + 1;
    const prefs = await GameProgress.getPrefs(context);
    if (!prefs) {
      return count;
    }
    try {
      await prefs.put(KEY_COMPLETED_PREFIX + level, count);
      await prefs.flush();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'addCompletedCount failed: %{public}s', JSON.stringify(e));
    }
    return count;
  }

  /**
   * 消费积分，成功返回 true
   */
  static async spend(context: Context, cost: number): Promise<boolean> {
    const total = await GameProgress.getTotalScore(context);
    if (total < cost) {
      return false;
    }
    const prefs = await GameProgress.getPrefs(context);
    if (!prefs) {
      return false;
    }
    try {
      await prefs.put(KEY_TOTAL_SCORE, total - cost);
      await prefs.flush();
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'spend failed: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  /**
   * 获取持久化的主题模式（0 深色 / 1 浅色 / -1 跟随系统，与 ConfigurationConstant.ColorMode 一致）
   */
  static async getThemeMode(context: Context): Promise<number> {
    const prefs = await GameProgress.getPrefs(context);
    if (!prefs) {
      return -1;
    }
    try {
      return await prefs.get(KEY_THEME_MODE, -1) as number;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'getThemeMode failed: %{public}s', JSON.stringify(e));
      return -1;
    }
  }

  /**
   * 持久化主题模式（0 深色 / 1 浅色 / -1 跟随系统，与 ConfigurationConstant.ColorMode 一致）
   */
  static async setThemeMode(context: Context, mode: number): Promise<void> {
    const prefs = await GameProgress.getPrefs(context);
    if (!prefs) {
      return;
    }
    try {
      await prefs.put(KEY_THEME_MODE, mode);
      await prefs.flush();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'setThemeMode failed: %{public}s', JSON.stringify(e));
    }
  }

  /**
   * 格式化毫秒为 mm:ss
   */
  static formatTime(millis: number): string {
    const totalSeconds = Math.floor(millis / 1000);
    const min = Math.floor(totalSeconds / 60);
    const sec = totalSeconds % 60;
    return `${String(min).padStart(2, '0')}:${String(sec).padStart(2, '0')}`;
  }
}
