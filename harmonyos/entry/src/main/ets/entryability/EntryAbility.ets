import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { GameProgress } from '../model/GameProgress';

const DOMAIN = 0x0000;

// 保存全局 UIAbilityContext，供页面在不能使用 getContext(this) 时使用。
let appContext: Context | null = null;

/**
 * 获取应用全局 Context（在 EntryAbility 启动后可用）。
 * 替代被 deprecated 的 getContext(this) 写法。
 */
export function getAppContext(): Context | null {
  return appContext;
}

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    appContext = this.context;
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    // 恢复上次持久化的主题模式
    this.restoreThemeMode();
  }

  /**
   * 从 preferences 恢复用户上次选择的主题模式并应用。
   * 无记录（-1）时跟随系统深色模式。
   */
  private async restoreThemeMode(): Promise<void> {
    try {
      const mode = await GameProgress.getThemeMode(this.context);
      if (mode === ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET) {
        this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
        AppStorage.setOrCreate('colorMode', ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      } else {
        this.context.getApplicationContext().setColorMode(mode);
        AppStorage.setOrCreate('colorMode', mode);
      }
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'restoreThemeMode failed. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    const colorMode = newConfig.colorMode;
    if (colorMode !== undefined) {
      AppStorage.setOrCreate('colorMode', colorMode);
    }
    hilog.info(DOMAIN, 'testTag', 'onConfigurationUpdate, colorMode: %{public}d', colorMode ?? -1);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/DifficultyPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });

  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
