package com.qianh.ooxx;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.view.View;

import java.util.ArrayDeque;
import java.util.Arrays;
import java.util.Deque;
import java.util.Random;

public class TicTacLogicView extends View {
    public interface GameListener { void onGameChanged(Snapshot snapshot); }

    public static final class Snapshot {
        public final int level, size, filled, total;
        public final String levelName, message;
        public final boolean completed, canUndo;

        Snapshot(int level, String levelName, int size, int filled, String message,
                 boolean completed, boolean canUndo) {
            this.level = level;
            this.levelName = levelName;
            this.size = size;
            this.filled = filled;
            this.total = size * size;
            this.message = message;
            this.completed = completed;
            this.canUndo = canUndo;
        }
    }

    private static final int EMPTY = 0;
    private static final int X = 1;
    private static final int O = 2;

    private static final class Level {
        final String name;
        final String[] solution;
        final String[] clues;
        Level(String name, String[] solution, String[] clues) {
            this.name = name; this.solution = solution; this.clues = clues;
        }
    }

    private static final Level[] LEVELS = {
            new Level("简单", new String[]{
                    "OXXOOX", "OXXOXO", "XOOXXO", "OOXXOX", "XXOOXO", "XOOXOX"
            }, new String[]{
                    "O.X.O.", "O.X..O", "X.OX.O", "OO.XO.", ".X..X.", "X..X.."
            }),
            new Level("中等", new String[]{
                    "XOOXOXOX", "OXOXOXXO", "OXXOXOOX", "XOXOOXXO",
                    "OXOXXOXO", "OXOOXXOX", "XOXXOOXO", "XOXOXOOX"
            }, new String[]{
                    "X..XO.O.", "..O..X.O", ".X....O.", "X...O.XO",
                    ".X.X...O", "...O..O.", "X.X.O.X.", ".O.O..O."
            }),
            new Level("困难", new String[]{
                    "OXOOXOXXOX", "OXOXXOXXOO", "XOXOOXOOXX", "XXOXXOOXOO", "OOXXOXXOXO",
                    "OOXOXXOOXX", "XXOXOOXXOO", "XXOXOXOOXO", "OOXOXOXOXX", "XOXOOXOXOX"
            }, new String[]{
                    "O.OO..XX.X", ".XO..O.X.O", "X...O...X.", "X.O.....OO", "O..X.....O",
                    ".O...X....", "..OX..X..O", "X.O.......", "O...X....X", "X......X.X"
            })
    };

    public static final class Theme {
        public final int lineColor;
        public final int outerColor;
        public final int xColor;
        public final int oColor;
        Theme(int line, int outer, int x, int o) {
            lineColor = line; outerColor = outer; xColor = x; oColor = o;
        }
    }

    public static final Theme[] THEMES = {
            new Theme(0xFFD7E1EA, 0xFF888780, 0xFF1976D2, 0xFFF06449), // 浅色
            new Theme(0xFF334155, 0xFF64748B, 0xFF60A5FA, 0xFFFB7185), // 深色
    };

    private int currentThemeIndex() {
        int mode = getResources().getConfiguration().uiMode
                & android.content.res.Configuration.UI_MODE_NIGHT_MASK;
        return mode == android.content.res.Configuration.UI_MODE_NIGHT_YES ? 1 : 0;
    }

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint linePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF rect = new RectF();
    private final Deque<int[][]> history = new ArrayDeque<>();
    private final Random random = new Random();
    private final String[][] lastCluesByLevel = new String[LEVELS.length][];
    private GameListener listener;
    private int levelIndex;
    private int[][] cells;
    private boolean[][] fixed;
    private boolean[][] invalid;
    private String[] currentSolution;
    private float cellSize, boardSize, left, top;
    private String message = "点击空格依次填入 X、O；再次点击可清空";
    private boolean completed;

    public TicTacLogicView(Context context, AttributeSet attrs) {
        super(context, attrs);
        linePaint.setStrokeWidth(dp(1));
        linePaint.setColor(Color.parseColor("#CBD5E1"));
        loadLevel(0);
        setFocusable(true);
        setClickable(true);
    }

    public void setListener(GameListener listener) { this.listener = listener; notifyChanged(); }

    private void loadLevel(int index) {
        levelIndex = (index + LEVELS.length) % LEVELS.length;
        Level level = LEVELS[levelIndex];
        int variant;
        String[] transformedClues;
        int attempts = 0;
        do {
            variant = random.nextInt(16);
            transformedClues = transform(level.clues, variant);
            attempts++;
        } while (attempts < 32 && Arrays.equals(transformedClues, lastCluesByLevel[levelIndex]));
        currentSolution = transform(level.solution, variant);
        lastCluesByLevel[levelIndex] = Arrays.copyOf(transformedClues, transformedClues.length);

        int n = currentSolution.length;
        cells = new int[n][n];
        fixed = new boolean[n][n];
        invalid = new boolean[n][n];
        history.clear();
        completed = false;
        for (int r = 0; r < n; r++) {
            for (int c = 0; c < n; c++) {
                char clue = transformedClues[r].charAt(c);
                if (clue != '.') {
                    cells[r][c] = clue == 'X' ? X : O;
                    fixed[r][c] = true;
                }
            }
        }
        message = "先找出两个相同符号之间的空格";
        requestLayout(); invalidate(); notifyChanged();
    }

    public void previousLevel() { loadLevel(levelIndex - 1); }
    public void nextLevel() { loadLevel(levelIndex + 1); }
    public void selectDifficulty(int difficulty) { loadLevel(difficulty); }

    public void restart() {
        loadLevel(levelIndex);
        message = "已生成一道新的" + LEVELS[levelIndex].name + "题";
        notifyChanged();
    }

    public void resetPuzzle() {
        for (int r = 0; r < cells.length; r++) {
            for (int c = 0; c < cells.length; c++) {
                if (!fixed[r][c]) cells[r][c] = EMPTY;
            }
        }
        history.clear();
        clearInvalid();
        completed = false;
        message = "已重置当前题目";
        invalidate();
        notifyChanged();
    }

    public void undo() {
        if (history.isEmpty()) return;
        cells = history.pop();
        completed = false;
        clearInvalid();
        message = "已撤销上一步";
        invalidate(); notifyChanged();
    }

    public void hint() {
        if (completed) return;
        for (int r = 0; r < cells.length; r++) {
            for (int c = 0; c < cells.length; c++) {
                int answer = answerAt(r, c);
                if (!fixed[r][c] && cells[r][c] != answer) {
                    pushHistory();
                    cells[r][c] = answer;
                    clearInvalid();
                    message = "提示：已为你填入一个正确符号";
                    updateCompleted();
                    invalidate(); notifyChanged();
                    return;
                }
            }
        }
    }

    public void checkPuzzle() {
        clearInvalid();
        for (int r = 0; r < cells.length; r++) {
            for (int c = 0; c < cells.length; c++) {
                if (!fixed[r][c] && cells[r][c] != EMPTY && cells[r][c] != answerAt(r, c)) {
                    invalid[r][c] = true;
                }
            }
        }
        markRuleViolations();
        boolean kept = false;
        for (int r = 0; r < cells.length; r++) {
            for (int c = 0; c < cells.length; c++) {
                if (invalid[r][c]) {
                    if (kept) {
                        invalid[r][c] = false;
                    } else {
                        kept = true;
                    }
                }
            }
        }
        updateCompleted();
        if (completed) message = "恭喜完成！所有行列都满足规则";
        else if (kept) message = "发现 1 处需要调整，修正后再检查";
        else message = "目前都正确，继续推理吧";
        invalidate(); notifyChanged();
    }

    @Override protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        int width = MeasureSpec.getSize(widthMeasureSpec);
        int height = MeasureSpec.getSize(heightMeasureSpec);
        int side = Math.min(width, height == 0 ? width : height);
        setMeasuredDimension(resolveSize(side, widthMeasureSpec), resolveSize(side, heightMeasureSpec));
    }

    @Override protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        updateBoardMetrics();
    }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        updateBoardMetrics();
        int n = cells.length;
        // 整体大矩形底色
        paint.setStyle(Paint.Style.FILL);
        boolean isDark = (getResources().getConfiguration().uiMode
                & android.content.res.Configuration.UI_MODE_NIGHT_MASK)
                == android.content.res.Configuration.UI_MODE_NIGHT_YES;
        paint.setColor(isDark ? 0xFF1E293B : Color.WHITE);
        rect.set(left, top, left + boardSize, top + boardSize);
        canvas.drawRect(rect, paint);
        // invalid 格浅红高亮
        paint.setColor(isDark ? 0xFF3F1D1D : Color.parseColor("#FEE2E2"));
        for (int r = 0; r < n; r++) {
            for (int c = 0; c < n; c++) {
                if (invalid[r][c]) {
                    rect.set(left + c * cellSize, top + r * cellSize,
                            left + (c + 1) * cellSize, top + (r + 1) * cellSize);
                    canvas.drawRect(rect, paint);
                }
            }
        }
        // 网格线
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(dp(1));
        paint.setColor(THEMES[currentThemeIndex()].lineColor);
        for (int i = 0; i <= n; i++) {
            float pos = left + i * cellSize;
            canvas.drawLine(pos, top, pos, top + boardSize, paint);
            canvas.drawLine(left, top + i * cellSize, left + boardSize, top + i * cellSize, paint);
        }
        // 外边框加粗
        paint.setStrokeWidth(dp(1.5f));
        paint.setColor(THEMES[currentThemeIndex()].outerColor);
        rect.set(left, top, left + boardSize, top + boardSize);
        canvas.drawRect(rect, paint);
        // 符号
        for (int r = 0; r < n; r++) {
            for (int c = 0; c < n; c++) {
                drawSymbol(canvas, r, c);
            }
        }
    }

    private void drawSymbol(Canvas canvas, int r, int c) {
        int value = cells[r][c];
        if (value == EMPTY) return;
        float cx = left + (c + .5f) * cellSize;
        float cy = top + (r + .5f) * cellSize;
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(Math.max(dp(3), cellSize * .09f));
        paint.setColor(value == X ? THEMES[currentThemeIndex()].xColor : THEMES[currentThemeIndex()].oColor);
        float d = cellSize * .22f;
        if (value == X) {
            canvas.drawLine(cx - d, cy - d, cx + d, cy + d, paint);
            canvas.drawLine(cx + d, cy - d, cx - d, cy + d, paint);
        } else {
            canvas.drawCircle(cx, cy, d, paint);
        }
    }

    @Override public boolean onTouchEvent(MotionEvent event) {
        if (event.getActionMasked() != MotionEvent.ACTION_UP) return true;
        updateBoardMetrics();
        if (cellSize <= 0f) return true;
        int c = (int) ((event.getX() - left) / cellSize);
        int r = (int) ((event.getY() - top) / cellSize);
        if (r < 0 || c < 0 || r >= cells.length || c >= cells.length) return true;
        performClick();
        if (fixed[r][c]) {
            message = "该格是题目给定的，不能修改";
        } else if (!completed) {
            pushHistory();
            cells[r][c] = (cells[r][c] + 1) % 3;
            clearInvalid();
            updateCompleted();
            message = completed ? "恭喜完成！所有行列都满足规则" :
                    "继续填写，完成后将自动结算";
        }
        invalidate(); notifyChanged();
        return true;
    }

    @Override public boolean performClick() { super.performClick(); return true; }

    private int markRuleViolations() {
        int n = cells.length;
        int before = invalidCount();
        for (int r = 0; r < n; r++) for (int c = 0; c <= n - 3; c++)
            if (cells[r][c] != EMPTY && cells[r][c] == cells[r][c+1] && cells[r][c] == cells[r][c+2])
                invalid[r][c] = invalid[r][c+1] = invalid[r][c+2] = true;
        for (int c = 0; c < n; c++) for (int r = 0; r <= n - 3; r++)
            if (cells[r][c] != EMPTY && cells[r][c] == cells[r+1][c] && cells[r][c] == cells[r+2][c])
                invalid[r][c] = invalid[r+1][c] = invalid[r+2][c] = true;
        for (int r = 0; r < n; r++) markOverfullRow(r);
        for (int c = 0; c < n; c++) markOverfullColumn(c);
        for (int a = 0; a < n; a++) for (int b = a + 1; b < n; b++) {
            if (sameFullRows(a, b)) for (int c = 0; c < n; c++) invalid[a][c] = invalid[b][c] = true;
            if (sameFullColumns(a, b)) for (int r = 0; r < n; r++) invalid[r][a] = invalid[r][b] = true;
        }
        return invalidCount() - before;
    }

    private void markOverfullRow(int r) {
        int n = cells.length;
        for (int value = X; value <= O; value++) {
            int count = 0; for (int c = 0; c < n; c++) if (cells[r][c] == value) count++;
            if (count > n / 2) for (int c = 0; c < n; c++) if (cells[r][c] == value) invalid[r][c] = true;
        }
    }

    private void markOverfullColumn(int c) {
        int n = cells.length;
        for (int value = X; value <= O; value++) {
            int count = 0; for (int r = 0; r < n; r++) if (cells[r][c] == value) count++;
            if (count > n / 2) for (int r = 0; r < n; r++) if (cells[r][c] == value) invalid[r][c] = true;
        }
    }

    private boolean sameFullRows(int a, int b) {
        for (int c = 0; c < cells.length; c++) if (cells[a][c] == EMPTY || cells[a][c] != cells[b][c]) return false;
        return true;
    }

    private boolean sameFullColumns(int a, int b) {
        for (int r = 0; r < cells.length; r++) if (cells[r][a] == EMPTY || cells[r][a] != cells[r][b]) return false;
        return true;
    }

    private void pushHistory() {
        int[][] copy = new int[cells.length][];
        for (int i = 0; i < cells.length; i++) copy[i] = Arrays.copyOf(cells[i], cells[i].length);
        history.push(copy);
        while (history.size() > 80) history.removeLast();
    }

    private void updateCompleted() {
        completed = true;
        for (int r = 0; r < cells.length; r++) for (int c = 0; c < cells.length; c++)
            if (cells[r][c] != answerAt(r, c)) completed = false;
    }

    private String[] transform(String[] source, int variant) {
        int n = source.length;
        char[][] result = new char[n][n];
        boolean transpose = (variant & 1) != 0;
        boolean flipRows = (variant & 2) != 0;
        boolean flipColumns = (variant & 4) != 0;
        boolean complement = (variant & 8) != 0;
        for (int r = 0; r < n; r++) {
            for (int c = 0; c < n; c++) {
                int sourceRow = flipRows ? n - 1 - r : r;
                int sourceColumn = flipColumns ? n - 1 - c : c;
                if (transpose) {
                    int swap = sourceRow;
                    sourceRow = sourceColumn;
                    sourceColumn = swap;
                }
                char value = source[sourceRow].charAt(sourceColumn);
                if (complement) {
                    if (value == 'X') value = 'O';
                    else if (value == 'O') value = 'X';
                }
                result[r][c] = value;
            }
        }
        String[] rows = new String[n];
        for (int r = 0; r < n; r++) rows[r] = new String(result[r]);
        return rows;
    }

    private int answerAt(int r, int c) { return currentSolution[r].charAt(c) == 'X' ? X : O; }

    private void clearInvalid() { for (boolean[] row : invalid) Arrays.fill(row, false); }
    private int invalidCount() { int n = 0; for (boolean[] row : invalid) for (boolean v : row) if (v) n++; return n; }
    private int filledCount() { int n = 0; for (int[] row : cells) for (int v : row) if (v != EMPTY) n++; return n; }
    private float dp(float value) { return value * getResources().getDisplayMetrics().density; }

    private void updateBoardMetrics() {
        int width = getWidth();
        int height = getHeight();
        if (width <= 0 || height <= 0 || cells == null || cells.length == 0) return;
        boardSize = Math.max(0f, Math.min(width, height) - dp(4));
        cellSize = boardSize / cells.length;
        left = (width - boardSize) / 2f;
        top = (height - boardSize) / 2f;
    }

    private void notifyChanged() {
        if (listener != null) listener.onGameChanged(new Snapshot(levelIndex, LEVELS[levelIndex].name,
                cells.length, filledCount(), message, completed, !history.isEmpty()));
    }
}
