/**
 * DifficultyPage — 首页 / 难度选择
 */
import { router } from '@kit.ArkUI';
import { GameProgress } from '../model/GameProgress';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { getAppContext } from '../entryability/EntryAbility';

@Entry
@Component
struct DifficultyPage {
  @State totalScore: number = 0;
  @State bestEasy: string = '暂无记录';
  @State bestMedium: string = '暂无记录';
  @State bestHard: string = '暂无记录';
  @State completedEasy: number = 0;
  @State completedMedium: number = 0;
  @State completedHard: number = 0;
  @State isDark: boolean = false;
  @State loaded: boolean = false;

  aboutToAppear(): void {
    // 从 AppStorage 读取初始颜色模式（可能尚未设置则用默认）
    try {
      const mode = AppStorage.get<ConfigurationConstant.ColorMode>('colorMode');
      this.isDark = mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } catch (_e) {
      this.isDark = false;
    }
  }

  onPageShow(): void {
    this.loadData();
    this.refreshTheme();
  }

  /**
   * 从持久化配置刷新主题（异步恢复晚于页面加载时的兜底）
   */
  private async refreshTheme(): Promise<void> {
    const ctx = getAppContext();
    if (!ctx) {
      return;
    }
    try {
      const mode = await GameProgress.getThemeMode(ctx);
      this.isDark = mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      AppStorage.setOrCreate('colorMode', mode);
    } catch (_e) {
      // 读取失败时保持当前显示
    }
  }

  private async loadData(): Promise<void> {
    const ctx = getAppContext();
    if (!ctx) {
      return;
    }
    try {
      this.totalScore = await GameProgress.getTotalScore(ctx);
      this.completedEasy = await GameProgress.getCompletedCount(ctx, 0);
      this.completedMedium = await GameProgress.getCompletedCount(ctx, 1);
      this.completedHard = await GameProgress.getCompletedCount(ctx, 2);

      const best0 = await GameProgress.getBestTime(ctx, 0);
      const best1 = await GameProgress.getBestTime(ctx, 1);
      const best2 = await GameProgress.getBestTime(ctx, 2);
      this.bestEasy = best0 < 0 ? '暂无记录' : `最佳 ${GameProgress.formatTime(best0)}`;
      this.bestMedium = best1 < 0 ? '暂无记录' : `最佳 ${GameProgress.formatTime(best1)}`;
      this.bestHard = best2 < 0 ? '暂无记录' : `最佳 ${GameProgress.formatTime(best2)}`;
      this.loaded = true;
    } catch (_e) {
      // preferences 可能尚未就绪，静默跳过
    }
  }

  private tColor(): ResourceColor { return this.isDark ? '#E2E8F0' : '#18324B'; }
  private tDim(): ResourceColor { return this.isDark ? '#94A3B8' : '#6E7F8D'; }
  private tSurface(): ResourceColor { return this.isDark ? '#1E293B' : '#FFFFFF'; }
  private tBorder(): ResourceColor { return this.isDark ? '#334155' : '#D7E1E8'; }
  private headerBg(): ResourceColor { return this.isDark ? '#1E293B' : '#18324B'; }
  private pageBg(): ResourceColor { return this.isDark ? '#0F172A' : '#F3F7F8'; }

  private async startGame(difficulty: number): Promise<void> {
    const gameParams: Record<string, Object> = {
      'difficulty': difficulty
    };
    try {
      await router.pushUrl({
        url: 'pages/GamePage',
        params: gameParams
      });
    } catch (_e) {
      // 跳转失败时静默
    }
  }

  private toggleTheme(): void {
    this.isDark = !this.isDark;
    const newMode = this.isDark ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK :
    ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    AppStorage.setOrCreate('colorMode', newMode);
    // 持久化主题选择，重启应用后保持
    const ctx = getAppContext();
    if (ctx) {
      GameProgress.setThemeMode(ctx, newMode);
    }
  }

  build() {
    Scroll() {
      Column() {
        // Header 卡片
        Column() {
          Row() {
            Text('OOXX')
              .fontSize(34).fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF').layoutWeight(1)
            Text('X')
              .fontSize(23).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              .width(48).height(48).textAlign(TextAlign.Center)
              .borderRadius(15).backgroundColor('#1976D2')
            Text('O')
              .fontSize(23).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              .width(48).height(48).textAlign(TextAlign.Center)
              .borderRadius(15).backgroundColor('#F06449').margin({ left: 8 })
          }
          .width('100%')

          Text('纯逻辑 · 圈叉谜题')
            .fontSize(14).fontColor('#B9C8D5').margin({ top: 8 })

          Divider().color('#355069').margin({ top: 22 })

          Row() {
            Text('可用积分').fontSize(13).fontColor('#B9C8D5').layoutWeight(1)
            Text(`${this.totalScore}`)
              .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#68D9C9')
          }
          .width('100%').margin({ top: 18 })
        }
        .width('100%').padding(24).borderRadius(28).backgroundColor(this.headerBg())

        // 难度标题
        Row() {
          Column() {
            Text('选择游戏难度')
              .fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.tColor())
            Text('选择适合你的棋盘尺寸，每次都会生成不同题目')
              .fontSize(13).fontColor(this.tDim()).margin({ top: 4 })
          }
        }
        .width('100%').margin({ top: 28 }).alignItems(VerticalAlign.Bottom)

        // 难度卡片
        this.diffCard('简单\u30006×6', '轻量棋盘 · 快速入门', '+2 分',
          this.bestEasy, this.completedEasy, '#E2F5F1', '#0B766E', '#B6E3DC', 0)
        this.diffCard('中等\u30008×8', '更多组合 · 进阶推理', '+5 分',
          this.bestMedium, this.completedMedium, '#E7F1FA', '#1976D2', '#BED5E8', 1)
        this.diffCard('困难\u300010×10', '大型棋盘 · 深度挑战', '+7 分',
          this.bestHard, this.completedHard, '#FDEAE5', '#F06449', '#F6C7BC', 2)

        Text('完成题目即可获得积分 · 难度越高积分越多')
          .fontSize(12).fontColor(this.tDim()).margin({ top: 22 }).textAlign(TextAlign.Center)

        Button(this.isDark ? '浅色模式' : '深色模式')
          .fontSize(14).fontColor(this.tColor())
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: this.tBorder(), style: BorderStyle.Solid })
          .borderRadius(14).height(44).padding({ left: 20, right: 20 })
          .margin({ top: 16, bottom: 28 })
          .onClick(() => this.toggleTheme())      }
      .width('100%').padding({ left: 22, right: 22, top: 34, bottom: 28 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%').height('100%').backgroundColor(this.pageBg()).scrollBar(BarState.Off)
  }

  @Builder
  diffCard(title: string, desc: string, reward: string,
           bestTime: string, completed: number,
           badgeBg: string, accent: string, borderClr: string, diff: number) {
    Row() {
      Text(`${diff === 0 ? '6' : diff === 1 ? '8' : '10'}`)
        .fontSize(20).fontWeight(FontWeight.Bold).fontColor(accent)
        .width(52).height(52).textAlign(TextAlign.Center)
        .borderRadius(16).backgroundColor(badgeBg)

      Column() {
        Text(title).fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.tColor())
        Text(desc).fontSize(12).fontColor(this.tDim()).margin({ top: 3 })
        Text(`${bestTime}  ·  已完成 ${completed} 局`)
          .fontSize(12).fontWeight(FontWeight.Bold).fontColor(accent).margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 14 })

      Text(reward).fontSize(14).fontWeight(FontWeight.Bold).fontColor(accent)
    }
    .width('100%').height(86).padding({ left: 16, right: 16 })
    .borderRadius(20).backgroundColor(this.tSurface())
    .border({ width: 1, color: borderClr, style: BorderStyle.Solid })
    .margin({ top: diff === 0 ? 20 : 12 })
    .onClick(() => this.startGame(diff))
  }
}
