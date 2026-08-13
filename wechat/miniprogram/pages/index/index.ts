// index.ts — 首页 / 难度选择
import { GameProgress, ThemeMode } from '../../utils/GameProgress'

interface DiffCard {
  key: string
  title: string
  desc: string
  reward: string
  badge: string
  badgeBg: string
  accent: string
  border: string
  bestText: string
  completed: number
  level: number
}

interface Colors {
  bg: string
  surface: string
  border: string
  ink: string
  dim: string
  headerBg: string
  headerDim: string
  teal: string
  navBg: string
}

const LIGHT: Colors = {
  bg: '#F3F7F8',
  surface: '#FFFFFF',
  border: '#D7E1E8',
  ink: '#18324B',
  dim: '#6E7F8D',
  headerBg: '#18324B',
  headerDim: '#B9C8D5',
  teal: '#139B8E',
  navBg: '#18324B'
}

const DARK: Colors = {
  bg: '#0F172A',
  surface: '#1E293B',
  border: '#334155',
  ink: '#E2E8F0',
  dim: '#94A3B8',
  headerBg: '#1E293B',
  headerDim: '#94A3B8',
  teal: '#14B8A6',
  navBg: '#0F172A'
}

const DIFF_META = [
  { key: 'easy', badge: '6', badgeBg: '#E2F5F1', accent: '#0B766E', border: '#B6E3DC' },
  { key: 'medium', badge: '8', badgeBg: '#E7F1FA', accent: '#1976D2', border: '#BED5E8' },
  { key: 'hard', badge: '10', badgeBg: '#FDEAE5', accent: '#F06449', border: '#F6C7BC' }
]

Page({
  data: {
    totalScore: 0,
    isDark: false,
    c: LIGHT as Colors,
    cards: [] as DiffCard[]
  },

  onLoad() {
    const dark = GameProgress.getThemeMode() === 'dark'
    this.setData({ isDark: dark, c: dark ? DARK : LIGHT })
    this.applyNavBar(dark)
  },

  onShow() {
    this.loadData()
  },

  loadData() {
    const totalScore = GameProgress.getTotalScore()
    const cards: DiffCard[] = DIFF_META.map((meta, i) => {
      const best = GameProgress.getBestTime(i)
      return {
        key: meta.key,
        title: ['简单　6×6', '中等　8×8', '困难　10×10'][i],
        desc: ['轻量棋盘 · 快速入门', '更多组合 · 进阶推理', '大型棋盘 · 深度挑战'][i],
        reward: ['+2 分', '+5 分', '+7 分'][i],
        badge: meta.badge,
        badgeBg: meta.badgeBg,
        accent: meta.accent,
        border: meta.border,
        bestText: best < 0 ? '暂无记录' : `最佳 ${GameProgress.formatTime(best)}`,
        completed: GameProgress.getCompletedCount(i),
        level: i
      }
    })
    this.setData({ totalScore, cards })
  },

  onThemeToggle() {
    const dark = !this.data.isDark
    const mode: ThemeMode = dark ? 'dark' : 'light'
    GameProgress.setThemeMode(mode)
    this.setData({ isDark: dark, c: dark ? DARK : LIGHT })
    this.applyNavBar(dark)
  },

  applyNavBar(dark: boolean) {
    wx.setNavigationBarColor({
      frontColor: '#ffffff',
      backgroundColor: dark ? DARK.navBg : LIGHT.navBg,
      animation: { duration: 200, timingFunc: 'easeIn' }
    })
  },

  onStartGame(e: WechatMiniprogram.TouchEvent) {
    const level = Number(e.currentTarget.dataset.level)
    wx.navigateTo({
      url: `/pages/game/game?difficulty=${level}`
    })
  }
})
