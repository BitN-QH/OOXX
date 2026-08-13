// game.ts — 游戏页面
import { TicTacLogicModel, CELL_X, CELL_O } from '../../utils/TicTacLogicModel'
import { GameProgress } from '../../utils/GameProgress'

const HINT_CHECK_LIMIT = 3

interface CellVM {
  r: number
  c: number
  text: string
  cls: string
}

interface BoardRow {
  r: number
  cells: CellVM[]
}

// 页面实例状态（game 页面同一时间仅一份实例，模块级单例安全）
const model = new TicTacLogicModel()
let timerId: number | null = null
let startedAt = 0
let elapsedAcc = 0
let dialogShown = false
let streakCount = 0
let hintCheckCount = 0

function streakBonus(s: number): number {
  if (s <= 1) return 0
  if (s === 2) return 1
  if (s === 3) return 3
  if (s <= 5) return 5
  if (s <= 10) return 8
  return 12
}

function buildRows(): BoardRow[] {
  const n = model.getSize()
  const cells = model.getCells()
  const fixed = model.getFixed()
  const invalid = model.getInvalid()
  const rows: BoardRow[] = []
  for (let r = 0; r < n; r++) {
    const row: CellVM[] = []
    for (let c = 0; c < n; c++) {
      const v = cells[r][c]
      let cls = 'cell'
      if (v === CELL_X) cls += ' x'
      else if (v === CELL_O) cls += ' o'
      else cls += ' empty'
      if (fixed[r][c]) cls += ' fixed'
      if (invalid[r][c]) cls += ' invalid'
      row.push({
        r,
        c,
        text: v === CELL_X ? 'X' : v === CELL_O ? 'O' : '',
        cls
      })
    }
    rows.push({ r, cells: row })
  }
  return rows
}

Page({
  data: {
    isDark: false,
    levelText: '',
    filled: 0,
    total: 0,
    message: '',
    completed: false,
    totalScore: 0,
    timerText: '00:00',
    rows: [] as BoardRow[],
    cellH: '60px',
    hintText: '提示 剩3次',
    checkText: '检查 剩3次',
    showCompletion: false,
    completionTitle: '',
    completionLines: [] as string[],
    showRules: false
  },

  onLoad(query: Record<string, string | undefined>) {
    const difficulty = Number(query.difficulty != null ? query.difficulty : 0)
    model.selectDifficulty(isNaN(difficulty) ? 0 : difficulty)
    const dark = GameProgress.getThemeMode() === 'dark'
    this.setData({ isDark: dark })
    this.applyNavBar(dark)
    this.refreshState()
    this.startTimer()
  },

  onReady() {
    const n = model.getSize()
    wx.createSelectorQuery()
      .select('#board')
      .boundingClientRect((res) => {
        let boardW = res && res.width > 0 ? res.width : 0
        if (boardW <= 0) {
          // 兜底：selector 查询失败时按窗口宽度估算棋盘宽度（左右各 36rpx 边距）
          boardW = wx.getSystemInfoSync().windowWidth * (1 - 2 * 36 / 750)
        }
        if (boardW > 0) {
          this.setData({ cellH: (boardW / n) + 'px' })
        }
      })
      .exec()
  },

  onShow() {
    const dark = GameProgress.getThemeMode() === 'dark'
    if (dark !== this.data.isDark) {
      this.setData({ isDark: dark })
      this.applyNavBar(dark)
    }
    this.setData({ totalScore: GameProgress.getTotalScore() })
    this.startTimer()
  },

  onHide() {
    this.stopTimer()
    elapsedAcc = Math.max(0, Date.now() - startedAt)
  },

  onUnload() {
    this.stopTimer()
  },

  // ============== 状态 ==============

  refreshState() {
    const snap = model.getSnapshot()
    const n = model.getSize()
    const left = HINT_CHECK_LIMIT - hintCheckCount
    this.setData({
      levelText: `第 ${snap.level + 1} 题 · ${snap.levelName} · ${n}×${n}`,
      filled: snap.filled,
      total: snap.total,
      message: snap.message,
      completed: snap.completed,
      rows: buildRows(),
      hintText: left <= 0 ? '提示(已用完)' : `提示 剩${left}次`,
      checkText: left <= 0 ? '检查(已用完)' : `检查 剩${left}次`
    })
  },

  applyNavBar(dark: boolean) {
    wx.setNavigationBarColor({
      frontColor: '#ffffff',
      backgroundColor: dark ? '#0F172A' : '#18324B',
      animation: { duration: 200, timingFunc: 'easeIn' }
    })
  },

  // ============== 计时器 ==============

  startTimer() {
    startedAt = Date.now() - elapsedAcc
    this.updateTimerText()
    this.stopTimer()
    timerId = setInterval(() => this.updateTimerText(), 1000) as unknown as number
  },

  stopTimer() {
    if (timerId !== null) {
      clearInterval(timerId)
      timerId = null
    }
  },

  updateTimerText() {
    this.setData({ timerText: GameProgress.formatTime(Math.max(0, Date.now() - startedAt)) })
  },

  // ============== 棋盘 ==============

  onCellTap(e: WechatMiniprogram.TouchEvent) {
    const r = Number(e.currentTarget.dataset.r)
    const c = Number(e.currentTarget.dataset.c)
    model.handleCellTap(r, c)
    this.refreshState()
    if (this.data.completed && !dialogShown) {
      this.doComplete()
    }
  },

  // ============== 操作 ==============

  doHint() {
    if (this.data.completed) return
    if (hintCheckCount >= HINT_CHECK_LIMIT) {
      this.showToast('本局提示/检查次数已用完（共3次）')
      return
    }
    if (!GameProgress.spend(2)) {
      this.showToast('积分不足，本操作需要 2 积分')
      return
    }
    hintCheckCount++
    this.setData({ totalScore: GameProgress.getTotalScore() })
    model.hint()
    this.refreshState()
    if (this.data.completed && !dialogShown) {
      this.doComplete()
    }
  },

  doCheck() {
    if (this.data.completed) return
    if (hintCheckCount >= HINT_CHECK_LIMIT) {
      this.showToast('本局提示/检查次数已用完（共3次）')
      return
    }
    if (!GameProgress.spend(1)) {
      this.showToast('积分不足，本操作需要 1 积分')
      return
    }
    hintCheckCount++
    this.setData({ totalScore: GameProgress.getTotalScore() })
    model.checkPuzzle()
    this.refreshState()
    if (this.data.completed && !dialogShown) {
      this.doComplete()
    }
  },

  doReset() {
    model.resetPuzzle()
    this.refreshState()
    elapsedAcc = 0
    this.startTimer()
  },

  doRestart() {
    if (!GameProgress.spend(1)) {
      this.showToast('积分不足，本操作需要 1 积分')
      return
    }
    this.setData({ totalScore: GameProgress.getTotalScore() })
    hintCheckCount = 0
    model.restart()
    this.refreshState()
    elapsedAcc = 0
    dialogShown = false
    this.startTimer()
  },

  doExit() {
    this.stopTimer()
    wx.navigateBack()
  },

  // ============== 完成 ==============

  doComplete() {
    dialogShown = true
    this.stopTimer()
    const levelIndex = model.getLevelIndex()
    const levelName = model.getLevelName()

    GameProgress.addCompletedCount(levelIndex)
    const earned = GameProgress.pointsForLevel(levelIndex)
    const elapsed = Math.max(0, Date.now() - startedAt)

    const best = GameProgress.recordTime(levelIndex, elapsed)
    const isBest = best === elapsed
    const sb = streakBonus(streakCount + 1)
    const newBestB = isBest ? 2 : 0
    const nxtStr = streakCount + 1

    let total = GameProgress.addCompletedLevel(levelIndex)
    if (newBestB > 0) total = GameProgress.addBonus(newBestB)
    if (sb > 0) total = GameProgress.addBonus(sb)
    this.setData({ totalScore: total })

    const lines: string[] = []
    lines.push(`"${levelName}"已正确完成！`)
    lines.push('')
    lines.push(`用时：${GameProgress.formatTime(elapsed)}`)
    lines.push(`获得：${earned} 积分`)
    if (newBestB > 0) lines.push(`新纪录 +${newBestB}`)
    lines.push(`总积分：${total}`)
    lines.push('')
    if (isBest) lines.push('★ 新纪录！')
    else lines.push(`最佳：${GameProgress.formatTime(best)}`)
    if (sb > 0) {
      lines.push('')
      lines.push(`🔥 连胜 +${sb}（${nxtStr}局）`)
    }

    this.setData({
      completionTitle: '挑战完成！',
      completionLines: lines,
      showCompletion: true
    })
  },

  onCompletionHome() {
    this.setData({ showCompletion: false })
    streakCount = 0
    this.doExit()
  },

  onCompletionNext() {
    this.setData({ showCompletion: false })
    dialogShown = false
    streakCount++
    hintCheckCount = 0
    model.restart()
    this.refreshState()
    elapsedAcc = 0
    this.startTimer()
  },

  // ============== 弹窗 ==============

  onShowRules() {
    this.setData({ showRules: true })
  },

  onCloseRules() {
    this.setData({ showRules: false })
  },

  onDialogBackdrop() {
    // 规则弹窗点遮罩关闭；完成弹窗不允许点遮罩关闭
    if (this.data.showRules) {
      this.setData({ showRules: false })
    }
  },

  noop() {
    // 阻止完成弹窗点击冒泡关闭
  },

  // ============== 工具 ==============

  showToast(message: string) {
    wx.showToast({ title: message, icon: 'none', duration: 2000 })
  }
})
