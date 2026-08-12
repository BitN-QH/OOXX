/**
 * GamePage — 游戏页面
 */
import { router } from '@kit.ArkUI';
import { TicTacLogicModel } from '../model/TicTacLogicModel';
import { GameProgress } from '../model/GameProgress';
import { GameBoard } from '../components/GameBoard';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { getAppContext } from '../entryability/EntryAbility';

const HINT_CHECK_LIMIT: number = 3;

@Entry
@Component
struct GamePage {
  private model: TicTacLogicModel = new TicTacLogicModel();
  @State cells: number[][] = [];
  @State fixed: boolean[][] = [];
  @State invalid: boolean[][] = [];
  @State boardSize: number = 6;
  @State levelName: string = '';
  @State levelIndex: number = 0;
  @State filled: number = 0;
  @State totalVal: number = 0;
  @State message: string = '';
  @State completed: boolean = false;
  @State totalScore: number = 0;
  @State timerText: string = '00:00';
  @State boardTrigger: number = 0;
  @State hintCheckCount: number = 0;
  @State streakCount: number = 0;
  @State showCompletion: boolean = false;
  @State showRules: boolean = false;
  @State completionMsg: string = '';
  @State completionTitle: string = '';
  @State isDark: boolean = false;
  private timerId: number = -1;
  private startedAt: number = 0;
  private elapsedAcc: number = 0;
  private dialogShown: boolean = false;

  aboutToAppear(): void {
    try {
      const mode = AppStorage.get<ConfigurationConstant.ColorMode>('colorMode');
      this.isDark = mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } catch (_e) {
      this.isDark = false;
    }
    try {
      const params = router.getParams() as Record<string, Object>;
      const difficulty = (params && params['difficulty'] as number) ?? 0;
      this.model.selectDifficulty(difficulty);
    } catch (_e) {
      this.model.selectDifficulty(0);
    }
    this.refreshState();
    this.startTimer();
  }

  onPageShow(): void {
    this.startTimer();
    this.loadScoreSafe();
  }

  onPageHide(): void {
    this.stopTimer();
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  // ============== 状态 ==============

  private refreshState(): void {
    const snap = this.model.getSnapshot();
    this.boardSize = snap.size;
    this.levelName = snap.levelName;
    this.levelIndex = snap.level;
    this.filled = snap.filled;
    this.totalVal = snap.total;
    this.message = snap.message;
    this.completed = snap.completed;
    this.cells = this.model.getCells();
    this.fixed = this.model.getFixed();
    this.invalid = this.model.getInvalid();
    this.boardTrigger++;
  }

  private async loadScoreSafe(): Promise<void> {
    const ctx = getAppContext();
    if (!ctx) {
      return;
    }
    try {
      this.totalScore = await GameProgress.getTotalScore(ctx);
    } catch (_e) { /* ignore */ }
  }

  private getCtx(): Context | null {
    return getAppContext();
  }

  // ============== 计时器 ==============

  private startTimer(): void {
    this.startedAt = Date.now() - this.elapsedAcc;
    this.updateTimerText();
    this.stopTimer();
    this.timerId = setInterval(() => { this.updateTimerText(); }, 1000);
  }

  private stopTimer(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private updateTimerText(): void {
    this.timerText = GameProgress.formatTime(Math.max(0, Date.now() - this.startedAt));
  }

  // ============== 棋盘 ==============

  private onTap(row: number, col: number): void {
    this.model.handleCellTap(row, col);
    this.refreshState();
    if (this.completed && !this.dialogShown) {
      this.doComplete();
    }
  }

  // ============== 操作 ==============

  private async doHint(): Promise<void> {
    if (this.completed) return;
    if (this.hintCheckCount >= HINT_CHECK_LIMIT) {
      this.showToast('本局提示/检查次数已用完（共3次）');
      return;
    }
    const ctx = this.getCtx();
    if (!ctx) return;
    if (!await GameProgress.spend(ctx, 2)) {
      this.showToast('积分不足，本操作需要 2 积分');
      return;
    }
    this.hintCheckCount++;
    this.totalScore = await GameProgress.getTotalScore(ctx);
    this.model.hint();
    this.refreshState();
    if (this.completed && !this.dialogShown) {
      this.doComplete();
    }
  }

  private async doCheck(): Promise<void> {
    if (this.completed) return;
    if (this.hintCheckCount >= HINT_CHECK_LIMIT) {
      this.showToast('本局提示/检查次数已用完（共3次）');
      return;
    }
    const ctx = this.getCtx();
    if (!ctx) return;
    if (!await GameProgress.spend(ctx, 1)) {
      this.showToast('积分不足，本操作需要 1 积分');
      return;
    }
    this.hintCheckCount++;
    this.totalScore = await GameProgress.getTotalScore(ctx);
    this.model.checkPuzzle();
    this.refreshState();
    if (this.completed && !this.dialogShown) {
      this.doComplete();
    }
  }

  private doReset(): void {
    this.model.resetPuzzle();
    this.refreshState();
    this.elapsedAcc = 0;
    this.startTimer();
  }

  private async doRestart(): Promise<void> {
    const ctx = this.getCtx();
    if (!ctx) return;
    if (!await GameProgress.spend(ctx, 1)) {
      this.showToast('积分不足，本操作需要 1 积分');
      return;
    }
    this.totalScore = await GameProgress.getTotalScore(ctx);
    this.hintCheckCount = 0;
    this.model.restart();
    this.refreshState();
    this.elapsedAcc = 0;
    this.dialogShown = false;
    this.startTimer();
  }

  private doExit(): void {
    this.stopTimer();
    try { router.back(); } catch (_e) { /* ignore */ }
  }

  // ============== 完成 ==============

  private async doComplete(): Promise<void> {
    this.dialogShown = true;
    this.stopTimer();
    const ctx = this.getCtx();
    if (!ctx) return;

    await GameProgress.addCompletedCount(ctx, this.levelIndex);
    const earned = GameProgress.pointsForLevel(this.levelIndex);
    const elapsed = Math.max(0, Date.now() - this.startedAt);

    const best = await GameProgress.recordTime(ctx, this.levelIndex, elapsed);
    const isBest = best === elapsed;
    const sb = this.strkBonus(this.streakCount + 1);
    const newBestB = isBest ? 2 : 0;
    const nxtStr = this.streakCount + 1;

    let total = await GameProgress.addCompletedLevel(ctx, this.levelIndex);
    if (newBestB > 0) total = await GameProgress.addBonus(ctx, newBestB);
    if (sb > 0) total = await GameProgress.addBonus(ctx, sb);
    this.totalScore = total;

    let msg = `"${this.levelName}"已正确完成！\n\n用时：${GameProgress.formatTime(elapsed)}\n获得：${earned} 积分`;
    if (newBestB > 0) msg += `\n新纪录 +${newBestB}`;
    msg += `\n总积分：${total}`;
    if (isBest) msg += '\n\n★ 新纪录！';
    else msg += `\n最佳：${GameProgress.formatTime(best)}`;
    if (sb > 0) msg += `\n\n🔥 连胜 +${sb}（${nxtStr}局）`;

    this.completionTitle = '挑战完成！';
    this.completionMsg = msg;
    this.showCompletion = true;
  }

  private strkBonus(s: number): number {
    if (s <= 1) return 0;
    if (s === 2) return 1;
    if (s === 3) return 3;
    if (s <= 5) return 5;
    if (s <= 10) return 8;
    return 12;
  }

  // ============== 按钮文本 ==============

  private hintText(): string {
    const n = HINT_CHECK_LIMIT - this.hintCheckCount;
    return n <= 0 ? '提示(已用完)' : `提示 剩${n}次`;
  }
  private checkText(): string {
    const n = HINT_CHECK_LIMIT - this.hintCheckCount;
    return n <= 0 ? '检查(已用完)' : `检查 剩${n}次`;
  }

  // ============== 工具：Toast（替代 deprecated 的 promptAction.showToast）=============

  private showToast(message: string, duration: number = 2000): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration });
    } catch (_e) { /* ignore */ }
  }

  // ============== 主题快捷 ==============

  private cBg(): ResourceColor { return this.isDark ? '#0F172A' : '#F3F7F8'; }
  private cInk(): ResourceColor { return this.isDark ? '#E2E8F0' : '#18324B'; }
  private cDim(): ResourceColor { return this.isDark ? '#94A3B8' : '#6E7F8D'; }
  private cSurf(): ResourceColor { return this.isDark ? '#1E293B' : '#FFFFFF'; }
  private cBdr(): ResourceColor { return this.isDark ? '#334155' : '#D7E1E8'; }
  private cTeal(): ResourceColor { return this.isDark ? '#14B8A6' : '#139B8E'; }
  private cTealD(): ResourceColor { return this.isDark ? '#5EEADC' : '#0B766E'; }
  private cCoral(): ResourceColor { return this.isDark ? '#FB7185' : '#F06449'; }

  // ============== UI ==============

  build() {
    Stack() {
      Column() {
        // 顶栏
        Row() {
          Column() {
            Text('OOXX').fontSize(25).fontWeight(FontWeight.Bold).fontColor(this.cInk())
            Text('纯逻辑 · 圈叉谜题').fontSize(13).fontColor(this.cDim()).margin({ top: 2 })
          }
          Blank()
          Button('规则').fontSize(14).fontColor(this.cInk())
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: this.cBdr(), style: BorderStyle.Solid })
            .borderRadius(14).height(44).onClick(() => { this.showRules = true; })
          Button('首页').fontSize(14).fontColor(this.cCoral())
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: this.cCoral(), style: BorderStyle.Solid })
            .borderRadius(14).height(44).margin({ left: 6 }).onClick(() => this.doExit())
        }.width('100%')

        // 信息栏
        Row() {
          Column() {
            Text(`第 ${this.levelIndex + 1} 题 · ${this.levelName} · ${this.boardSize}×${this.boardSize}`)
              .fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.cInk())
            Row() {
              Text(`已填 ${this.filled} / ${this.totalVal}`).fontSize(12).fontColor(this.cDim())
              Text(`积分 ${this.totalScore}`).fontSize(12).fontWeight(FontWeight.Bold)
                .fontColor(this.cTealD()).margin({ left: 12 })
              Text(`用时 ${this.timerText}`).fontSize(12).fontColor(this.cDim()).margin({ left: 12 })
            }.margin({ top: 2 })
          }.layoutWeight(1)

          Text(this.completed ? '已完成' : '解题中')
            .fontSize(13).fontWeight(FontWeight.Bold).fontColor(this.cTealD())
            .height(32).padding({ left: 12, right: 12 }).borderRadius(999)
            .backgroundColor(this.isDark ? '#134E4A' : '#E2F5F1').textAlign(TextAlign.Center)
        }
        .width('100%').height(52).padding({ left: 14, right: 14 })
        .borderRadius(14).backgroundColor(this.cSurf())
        .border({ width: 1, color: this.cBdr(), style: BorderStyle.Solid }).margin({ top: 14 })

        // 棋盘
        GameBoard({
          cells: this.cells, fixed: this.fixed, invalid: this.invalid,
          boardSize: this.boardSize, trigger: this.boardTrigger,
          onCellTap: (r: number, c: number) => this.onTap(r, c)
        }).width('100%').aspectRatio(1).margin({ top: 12 })

        // 提示栏
        Row() {
          Text('X').fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor(this.isDark ? '#60A5FA' : '#1976D2')
          Text('点按切换').fontSize(12).fontColor(this.cDim()).margin({ left: 5 })
          Text('O').fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor(this.isDark ? '#FB7185' : '#F06449').margin({ left: 10 })
          Text(this.message).fontSize(12).fontColor(this.cInk()).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1).textAlign(TextAlign.End).margin({ left: 12 })
        }
        .width('100%').height(42).padding({ left: 12, right: 12 })
        .borderRadius(14).backgroundColor(this.cSurf())
        .border({ width: 1, color: this.cBdr(), style: BorderStyle.Solid }).margin({ top: 8 })

        // 按钮行
        Row() {
          Button(this.hintText()).layoutWeight(1).height(48).fontSize(14)
            .fontColor('#FFFFFF').backgroundColor(this.cTeal()).borderRadius(12)
            .onClick(() => this.doHint())
          Button(this.checkText()).layoutWeight(1).height(48).fontSize(14)
            .fontColor('#FFFFFF').backgroundColor(this.cTeal()).borderRadius(12)
            .margin({ left: 6 }).onClick(() => this.doCheck())
        }.width('100%').margin({ top: 10 })

        Row() {
          Button('重置').layoutWeight(1).height(48).fontSize(14).fontColor(this.cInk())
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: this.cBdr(), style: BorderStyle.Solid })
            .borderRadius(12).onClick(() => this.doReset())
          Button('换一题(1积分)').layoutWeight(1).height(48).fontSize(14).fontColor(this.cInk())
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: this.cBdr(), style: BorderStyle.Solid })
            .borderRadius(12).margin({ left: 6 }).onClick(() => this.doRestart())
        }.width('100%').margin({ top: 6 })
      }
      .width('100%').height('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 12 })
      .backgroundColor(this.cBg())

      if (this.showCompletion) { this.compDialog() }
      if (this.showRules) { this.rulesDialog() }
    }
    .width('100%').height('100%')
  }

  @Builder compDialog() {
    Column() {
      Column() {
        Text(this.completionTitle).fontSize(20).fontWeight(FontWeight.Bold)
          .fontColor(this.cInk()).margin({ bottom: 16 })
        Text(this.completionMsg).fontSize(14).fontColor(this.cDim()).lineHeight(22)
        Row() {
          Button('返回首页').layoutWeight(1).fontSize(14).fontColor(this.cDim())
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: this.cBdr(), style: BorderStyle.Solid })
            .borderRadius(12).height(44).onClick(() => {
            this.showCompletion = false; this.streakCount = 0; this.doExit();
          })
          Button('再来一关').layoutWeight(1).fontSize(14).fontColor('#FFFFFF')
            .backgroundColor(this.cTeal()).borderRadius(12).height(44)
            .margin({ left: 10 }).onClick(() => {
            this.showCompletion = false; this.dialogShown = false;
            this.streakCount++; this.hintCheckCount = 0;
            this.model.restart(); this.refreshState();
            this.elapsedAcc = 0; this.startTimer();
          })
        }.width('100%').margin({ top: 20 })
      }
      .padding(24).borderRadius(20).backgroundColor(this.cSurf()).width('85%')
    }
    .width('100%').height('100%').backgroundColor('rgba(0, 0, 0, 0.5)')
    .justifyContent(FlexAlign.Center).onClick(() => {})
  }

  @Builder rulesDialog() {
    Column() {
      Column() {
        Text('游戏规则').fontSize(20).fontWeight(FontWeight.Bold)
          .fontColor(this.cInk()).margin({ bottom: 16 })
        Text('在所有空格中填入 X 或 O：\n\n1. 每一行和每一列中，X 与 O 的数量必须相同。\n\n2. 横向或纵向都不能出现三个连续相同的符号。\n\n3. 任意两行不能完全相同，任意两列也不能完全相同。\n\n深色格是题目给定的线索；点击空格会按 X → O → 空白 循环切换。')
          .fontSize(14).fontColor(this.cDim()).lineHeight(22)
        Button('知道了').width('100%').fontSize(14).fontColor('#FFFFFF')
          .backgroundColor(this.cTeal()).borderRadius(12).height(44)
          .margin({ top: 20 }).onClick(() => { this.showRules = false; })
      }
      .padding(24).borderRadius(20).backgroundColor(this.cSurf()).width('85%')
    }
    .width('100%').height('100%').backgroundColor('rgba(0, 0, 0, 0.5)')
    .justifyContent(FlexAlign.Center).onClick(() => { this.showRules = false; })
  }
}
