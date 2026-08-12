/**
 * GameBoard — 棋盘组件
 * 用 Grid 原生布局渲染 N×N 等宽等高网格，支持深色模式
 */
import { CELL_EMPTY, CELL_X, CELL_O } from '../model/TicTacLogicModel';
import { ConfigurationConstant } from '@kit.AbilityKit';

interface CellData {
  row: number;
  col: number;
  value: number;
}

@Component
export struct GameBoard {
  @Prop cells: number[][] = [];
  @Prop fixed: boolean[][] = [];
  @Prop invalid: boolean[][] = [];
  @Prop boardSize: number = 6;
  @Prop trigger: number = 0;
  onCellTap?: (row: number, col: number) => void;

  private isDark(): boolean {
    const mode = AppStorage.get<ConfigurationConstant.ColorMode>('colorMode');
    return mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  /**
   * 根据 boardSize 动态生成 columnsTemplate / rowsTemplate，
   * 例如 6 → "1fr 1fr 1fr 1fr 1fr 1fr"
   */
  private frTemplate(): string {
    if (this.boardSize <= 0) {
      return '1fr';
    }
    let s = '1fr';
    for (let i = 1; i < this.boardSize; i++) {
      s += ' 1fr';
    }
    return s;
  }

  private symbolSize(): number {
    if (this.boardSize <= 6) return 20;
    if (this.boardSize <= 8) return 16;
    return 13;
  }

  private cellBg(row: number, col: number): ResourceColor {
    if (this.invalid[row] && this.invalid[row][col]) {
      return this.isDark() ? '#3F1D1D' : '#FEE2E2';
    }
    if (this.fixed[row] && this.fixed[row][col]) {
      return this.isDark() ? '#0F172A' : '#EAF0F3';
    }
    return Color.Transparent;
  }

  /**
   * 把 this.cells 摊平成一维数组（按行优先），
   * 让单个 ForEach 即可驱动整个 Grid，每个 key 都唯一。
   */
  private flatCells(): CellData[] {
    const out: CellData[] = [];
    const n = this.boardSize;
    if (n <= 0 || this.cells.length === 0) return out;
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        out.push({
          row: r,
          col: c,
          value: this.cells[r]?.[c] ?? CELL_EMPTY
        });
      }
    }
    return out;
  }

  build() {
    Grid() {
      ForEach(this.flatCells(), (cell: CellData) => {
        GridItem() {
          this.cellContent(cell)
        }
      }, (cell: CellData): string => `c_${cell.row}_${cell.col}_${this.trigger}`)
    }
    .columnsTemplate(this.frTemplate())
    .rowsTemplate(this.frTemplate())
    .columnsGap(0)
    .rowsGap(0)
    .width('100%')
    .aspectRatio(1)
    .border({
      width: 2,
      color: this.isDark() ? '#64748B' : '#888780',
      style: BorderStyle.Solid
    })
    .borderRadius(4)
    .backgroundColor(this.isDark() ? '#1E293B' : '#FFFFFF')
  }

  @Builder
  cellContent(cellData: CellData) {
    Column() {
      if (cellData.value === CELL_X) {
        Text('X')
          .fontSize(this.symbolSize())
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isDark() ? '#60A5FA' : '#1976D2')
      } else if (cellData.value === CELL_O) {
        Text('O')
          .fontSize(this.symbolSize())
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isDark() ? '#FB7185' : '#F06449')
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.cellBg(cellData.row, cellData.col))
    .border({
      width: { right: 0.5, bottom: 0.5 },
      color: this.isDark() ? '#334155' : '#D7E1EA',
      style: BorderStyle.Solid
    })
    .onClick(() => {
      if (this.onCellTap) {
        this.onCellTap(cellData.row, cellData.col);
      }
    })
  }
}
