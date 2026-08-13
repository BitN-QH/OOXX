/**
 * TicTacLogicModel — 纯游戏逻辑层（从 HarmonyOS/Android 移植）
 * 不含任何 UI 依赖，可独立进行单元测试。
 */

const EMPTY: number = 0;
const X: number = 1;
const O: number = 2;

interface LevelData {
  name: string;
  solution: string[];
  clues: string[];
}

const LEVELS: LevelData[] = [
  {
    name: '简单',
    solution: [
      'OXXOOX', 'OXXOXO', 'XOOXXO', 'OOXXOX', 'XXOOXO', 'XOOXOX'
    ],
    clues: [
      'O.X.O.', 'O.X..O', 'X.OX.O', 'OO.XO.', '.X..X.', 'X..X..'
    ]
  },
  {
    name: '中等',
    solution: [
      'XOOXOXOX', 'OXOXOXXO', 'OXXOXOOX', 'XOXOOXXO',
      'OXOXXOXO', 'OXOOXXOX', 'XOXXOOXO', 'XOXOXOOX'
    ],
    clues: [
      'X..XO.O.', '..O..X.O', '.X....O.', 'X...O.XO',
      '.X.X...O', '...O..O.', 'X.X.O.X.', '.O.O..O.'
    ]
  },
  {
    name: '困难',
    solution: [
      'OXOOXOXXOX', 'OXOXXOXXOO', 'XOXOOXOOXX', 'XXOXXOOXOO', 'OOXXOXXOXO',
      'OOXOXXOOXX', 'XXOXOOXXOO', 'XXOXOXOOXO', 'OOXOXOXOXX', 'XOXOOXOXOX'
    ],
    clues: [
      'O.OO..XX.X', '.XO..O.X.O', 'X...O...X.', 'X.O.....OO', 'O..X.....O',
      '.O...X....', '..OX..X..O', 'X.O.......', 'O...X....X', 'X......X.X'
    ]
  }
];

export interface Snapshot {
  level: number;
  levelName: string;
  size: number;
  filled: number;
  total: number;
  message: string;
  completed: boolean;
  canUndo: boolean;
}

export class TicTacLogicModel {
  private levelIndex: number;
  private cells: number[][];
  private fixed: boolean[][];
  private invalid: boolean[][];
  private currentSolution: string[];
  private history: number[][][];
  private lastCluesByLevel: string[][];
  private _message: string;
  private _completed: boolean;

  constructor() {
    this.levelIndex = 0;
    this.cells = [];
    this.fixed = [];
    this.invalid = [];
    this.currentSolution = [];
    this.history = [];
    this.lastCluesByLevel = [[], [], []];
    this._message = '点击空格依次填入 X、O；再次点击可清空';
    this._completed = false;
  }

  getMessage(): string { return this._message; }
  isCompleted(): boolean { return this._completed; }
  getLevelIndex(): number { return this.levelIndex; }
  getLevelName(): string { return LEVELS[this.levelIndex].name; }
  getSize(): number { return this.cells.length; }
  getCells(): number[][] { return this.cells; }
  getFixed(): boolean[][] { return this.fixed; }
  getInvalid(): boolean[][] { return this.invalid; }
  canUndo(): boolean { return this.history.length > 0; }

  getFilledCount(): number {
    let n = 0;
    for (const row of this.cells) {
      for (const v of row) {
        if (v !== EMPTY) {
          n++;
        }
      }
    }
    return n;
  }

  getSnapshot(): Snapshot {
    return {
      level: this.levelIndex,
      levelName: LEVELS[this.levelIndex].name,
      size: this.cells.length,
      filled: this.getFilledCount(),
      total: this.cells.length * this.cells.length,
      message: this._message,
      completed: this._completed,
      canUndo: this.history.length > 0
    };
  }

  selectDifficulty(difficulty: number): void {
    this.loadLevel(difficulty);
  }

  restart(): void {
    this.loadLevel(this.levelIndex);
    this._message = `已生成一道新的${LEVELS[this.levelIndex].name}题`;
  }

  resetPuzzle(): void {
    const n = this.cells.length;
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        if (!this.fixed[r][c]) {
          this.cells[r][c] = EMPTY;
        }
      }
    }
    this.history = [];
    this.clearInvalid();
    this._completed = false;
    this._message = '已重置当前题目';
  }

  undo(): void {
    if (this.history.length === 0) {
      return;
    }
    this.cells = this.history.pop() as number[][];
    this._completed = false;
    this.clearInvalid();
    this._message = '已撤销上一步';
  }

  hint(): boolean {
    if (this._completed) {
      return false;
    }
    const n = this.cells.length;
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        const answer = this.answerAt(r, c);
        if (!this.fixed[r][c] && this.cells[r][c] !== answer) {
          this.pushHistory();
          this.cells[r][c] = answer;
          this.clearInvalid();
          this._message = '提示：已为你填入一个正确符号';
          this.updateCompleted();
          return true;
        }
      }
    }
    return false;
  }

  checkPuzzle(): void {
    this.clearInvalid();
    const n = this.cells.length;
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        if (!this.fixed[r][c] && this.cells[r][c] !== EMPTY && this.cells[r][c] !== this.answerAt(r, c)) {
          this.invalid[r][c] = true;
        }
      }
    }
    this.markRuleViolations();

    // 只保留第一个违规
    let kept = false;
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        if (this.invalid[r][c]) {
          if (kept) {
            this.invalid[r][c] = false;
          } else {
            kept = true;
          }
        }
      }
    }
    this.updateCompleted();
    if (this._completed) {
      this._message = '恭喜完成！所有行列都满足规则';
    } else if (kept) {
      this._message = '发现 1 处需要调整，修正后再检查';
    } else {
      this._message = '目前都正确，继续推理吧';
    }
  }

  /**
   * 处理格子点击 — X → O → 空白 循环
   * @returns 是否应该处理（格子非 fixed 且未完成）
   */
  handleCellTap(r: number, c: number): 'handled' | 'fixed' | 'completed' {
    if (this.fixed[r][c]) {
      this._message = '该格是题目给定的，不能修改';
      return 'fixed';
    }
    if (this._completed) {
      return 'completed';
    }
    this.pushHistory();
    this.cells[r][c] = (this.cells[r][c] + 1) % 3;
    this.clearInvalid();
    this.updateCompleted();
    this._message = this._completed ? '恭喜完成！所有行列都满足规则' : '继续填写，完成后将自动结算';
    return 'handled';
  }

  // ============== 内部方法 ==============

  private loadLevel(index: number): void {
    this.levelIndex = ((index % LEVELS.length) + LEVELS.length) % LEVELS.length;
    const level = LEVELS[this.levelIndex];

    // 随机变换避免重复
    let variant: number;
    let transformedClues: string[];
    let attempts = 0;
    do {
      variant = Math.floor(Math.random() * 16);
      transformedClues = this.transform(level.clues, variant);
      attempts++;
    } while (attempts < 32 && this.arrEquals(transformedClues, this.lastCluesByLevel[this.levelIndex]));

    this.currentSolution = this.transform(level.solution, variant);
    this.lastCluesByLevel[this.levelIndex] = [...transformedClues];

    const n = this.currentSolution.length;
    this.cells = [];
    this.fixed = [];
    this.invalid = [];
    for (let r = 0; r < n; r++) {
      this.cells[r] = new Array(n).fill(EMPTY);
      this.fixed[r] = new Array(n).fill(false);
      this.invalid[r] = new Array(n).fill(false);
    }
    this.history = [];
    this._completed = false;

    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        const clue = transformedClues[r].charAt(c);
        if (clue !== '.') {
          this.cells[r][c] = clue === 'X' ? X : O;
          this.fixed[r][c] = true;
        }
      }
    }
    this._message = '先找出两个相同符号之间的空格';
  }

  private transform(source: string[], variant: number): string[] {
    const n = source.length;
    const result: string[][] = [];
    const transpose = (variant & 1) !== 0;
    const flipRows = (variant & 2) !== 0;
    const flipColumns = (variant & 4) !== 0;
    const complement = (variant & 8) !== 0;

    for (let r = 0; r < n; r++) {
      result[r] = new Array(n).fill('.');
    }

    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        let sourceRow = flipRows ? n - 1 - r : r;
        let sourceCol = flipColumns ? n - 1 - c : c;
        if (transpose) {
          const swap = sourceRow;
          sourceRow = sourceCol;
          sourceCol = swap;
        }
        let value = source[sourceRow].charAt(sourceCol);
        if (complement) {
          if (value === 'X') {
            value = 'O';
          } else if (value === 'O') {
            value = 'X';
          }
        }
        result[r][c] = value;
      }
    }
    return result.map(row => row.join(''));
  }

  private answerAt(r: number, c: number): number {
    return this.currentSolution[r].charAt(c) === 'X' ? X : O;
  }

  private pushHistory(): void {
    const n = this.cells.length;
    const copy: number[][] = [];
    for (let i = 0; i < n; i++) {
      copy[i] = [...this.cells[i]];
    }
    this.history.push(copy);
    while (this.history.length > 80) {
      this.history.shift();
    }
  }

  private clearInvalid(): void {
    for (const row of this.invalid) {
      for (let i = 0; i < row.length; i++) {
        row[i] = false;
      }
    }
  }

  private updateCompleted(): void {
    const n = this.cells.length;
    this._completed = true;
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        if (this.cells[r][c] !== this.answerAt(r, c)) {
          this._completed = false;
          return;
        }
      }
    }
  }

  // ============== 规则违规标记 ==============

  private markRuleViolations(): number {
    const n = this.cells.length;
    const before = this.invalidCount();

    // 三连检测
    for (let r = 0; r < n; r++) {
      for (let c = 0; c <= n - 3; c++) {
        if (this.cells[r][c] !== EMPTY && this.cells[r][c] === this.cells[r][c + 1] && this.cells[r][c] === this.cells[r][c + 2]) {
          this.invalid[r][c] = this.invalid[r][c + 1] = this.invalid[r][c + 2] = true;
        }
      }
    }
    for (let c = 0; c < n; c++) {
      for (let r = 0; r <= n - 3; r++) {
        if (this.cells[r][c] !== EMPTY && this.cells[r][c] === this.cells[r + 1][c] && this.cells[r][c] === this.cells[r + 2][c]) {
          this.invalid[r][c] = this.invalid[r + 1][c] = this.invalid[r + 2][c] = true;
        }
      }
    }

    // 数量超限
    for (let r = 0; r < n; r++) {
      this.markOverfullRow(r);
    }
    for (let c = 0; c < n; c++) {
      this.markOverfullColumn(c);
    }

    // 行列唯一性
    for (let a = 0; a < n; a++) {
      for (let b = a + 1; b < n; b++) {
        if (this.sameFullRows(a, b)) {
          for (let c = 0; c < n; c++) {
            this.invalid[a][c] = this.invalid[b][c] = true;
          }
        }
        if (this.sameFullColumns(a, b)) {
          for (let r = 0; r < n; r++) {
            this.invalid[r][a] = this.invalid[r][b] = true;
          }
        }
      }
    }

    return this.invalidCount() - before;
  }

  private markOverfullRow(r: number): void {
    const n = this.cells.length;
    for (let value = X; value <= O; value++) {
      let count = 0;
      for (let c = 0; c < n; c++) {
        if (this.cells[r][c] === value) {
          count++;
        }
      }
      if (count > n / 2) {
        for (let c = 0; c < n; c++) {
          if (this.cells[r][c] === value) {
            this.invalid[r][c] = true;
          }
        }
      }
    }
  }

  private markOverfullColumn(c: number): void {
    const n = this.cells.length;
    for (let value = X; value <= O; value++) {
      let count = 0;
      for (let r = 0; r < n; r++) {
        if (this.cells[r][c] === value) {
          count++;
        }
      }
      if (count > n / 2) {
        for (let r = 0; r < n; r++) {
          if (this.cells[r][c] === value) {
            this.invalid[r][c] = true;
          }
        }
      }
    }
  }

  private sameFullRows(a: number, b: number): boolean {
    const n = this.cells.length;
    for (let c = 0; c < n; c++) {
      if (this.cells[a][c] === EMPTY || this.cells[a][c] !== this.cells[b][c]) {
        return false;
      }
    }
    return true;
  }

  private sameFullColumns(a: number, b: number): boolean {
    const n = this.cells.length;
    for (let r = 0; r < n; r++) {
      if (this.cells[r][a] === EMPTY || this.cells[r][a] !== this.cells[r][b]) {
        return false;
      }
    }
    return true;
  }

  private invalidCount(): number {
    let n = 0;
    for (const row of this.invalid) {
      for (const v of row) {
        if (v) {
          n++;
        }
      }
    }
    return n;
  }

  private arrEquals(a: string[], b: string[]): boolean {
    if (a.length !== b.length) {
      return false;
    }
    for (let i = 0; i < a.length; i++) {
      if (a[i] !== b[i]) {
        return false;
      }
    }
    return true;
  }
}

// 导出常量供外部使用
export const CELL_EMPTY = EMPTY;
export const CELL_X = X;
export const CELL_O = O;
export { LEVELS };
