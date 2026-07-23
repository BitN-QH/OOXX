package com.example.ooxx;

import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.widget.TextView;
import android.widget.Toast;

import androidx.activity.EdgeToEdge;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

public class MainActivity extends AppCompatActivity implements TicTacLogicView.GameListener {
    private TicTacLogicView puzzleView;
    private TextView levelText;
    private TextView progressText;
    private TextView messageText;
    private TextView statusText;
    private TextView scoreText;
    private TextView timerText;
    private boolean completionDialogShown;
    private long puzzleStartedAt;
    private final Handler timerHandler = new Handler(Looper.getMainLooper());
    private final Runnable timerTick = new Runnable() {
        @Override
        public void run() {
            updateTimerText(elapsedMillis());
            timerHandler.postDelayed(this, 1000);
        }
    };
    private static final int HINT_CHECK_LIMIT = 3;
    private int hintCheckCount;
    private int streakCount;
    private com.google.android.material.button.MaterialButton hintBtn;
    private com.google.android.material.button.MaterialButton checkBtn;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        EdgeToEdge.enable(this);
        setContentView(R.layout.activity_main);
        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.main), (view, insets) -> {
            Insets bars = insets.getInsets(WindowInsetsCompat.Type.systemBars());
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom);
            return insets;
        });

        puzzleView = findViewById(R.id.puzzleView);
        levelText = findViewById(R.id.tvLevel);
        progressText = findViewById(R.id.tvProgress);
        messageText = findViewById(R.id.tvMessage);
        statusText = findViewById(R.id.tvStatus);
        scoreText = findViewById(R.id.tvScore);
        timerText = findViewById(R.id.tvTimer);

        hintBtn = findViewById(R.id.btnHint);
        checkBtn = findViewById(R.id.btnCheck);
        hintBtn.setOnClickListener(v -> runHintCheckAction(2, puzzleView::hint));
        checkBtn.setOnClickListener(v -> runHintCheckAction(1, puzzleView::checkPuzzle));
        findViewById(R.id.btnReset).setOnClickListener(v -> {
            puzzleView.resetPuzzle();
            startTimer();
        });
        findViewById(R.id.btnRestart).setOnClickListener(v ->
                runPaidAction(1, () -> {
                    hintCheckCount = 0;
                    updateHintCheckButtons();
                    startNewPuzzle(puzzleView::restart);
                }));
        findViewById(R.id.btnExit).setOnClickListener(v -> returnToHome());
        findViewById(R.id.btnRules).setOnClickListener(v -> showRules());
        int difficulty = getIntent().getIntExtra(DifficultyActivity.EXTRA_DIFFICULTY, 0);
        puzzleView.selectDifficulty(difficulty);
        startTimer();
        puzzleView.setListener(this);
        updateHintCheckButtons();
    }

    @Override
    protected void onResume() {
        super.onResume();
        timerHandler.removeCallbacks(timerTick);
        timerHandler.post(timerTick);
    }

    @Override
    protected void onPause() {
        timerHandler.removeCallbacks(timerTick);
        super.onPause();
    }

    private void runPaidAction(int cost, Runnable action) {
        if (!GameProgress.spend(this, cost)) {
            Toast.makeText(this, getString(R.string.insufficient_score, cost), Toast.LENGTH_SHORT).show();
            return;
        }
        updateScoreText(GameProgress.getTotalScore(this));
        action.run();
    }

    private void runHintCheckAction(int cost, Runnable action) {
        if (hintCheckCount >= HINT_CHECK_LIMIT) {
            Toast.makeText(this, "本局提示/检查次数已用完（共" + HINT_CHECK_LIMIT + "次）",
                    Toast.LENGTH_SHORT).show();
            return;
        }
        if (!GameProgress.spend(this, cost)) {
            Toast.makeText(this, getString(R.string.insufficient_score, cost), Toast.LENGTH_SHORT).show();
            return;
        }
        hintCheckCount++;
        updateScoreText(GameProgress.getTotalScore(this));
        action.run();
        updateHintCheckButtons();
    }

    private void updateHintCheckButtons() {
        int left = HINT_CHECK_LIMIT - hintCheckCount;
        if (left > 0) {
            hintBtn.setText(getString(R.string.btn_hint) + " 剩" + left + "次");
            checkBtn.setText(getString(R.string.btn_check) + " 剩" + left + "次");
        } else {
            hintBtn.setText("提示(已用完)");
            checkBtn.setText("检查(已用完)");
        }
    }

    private static int streakBonus(int streak) {
        if (streak <= 1) return 0;
        if (streak == 2) return 1;
        if (streak == 3) return 3;
        if (streak <= 5) return 5;
        if (streak <= 10) return 8;
        return 12;
    }

    private void startNewPuzzle(Runnable action) {
        action.run();
        startTimer();
    }

    private void returnToHome() {
        Intent intent = new Intent(this, DifficultyActivity.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        startActivity(intent);
        finish();
    }

    private void startTimer() {
        puzzleStartedAt = SystemClock.elapsedRealtime();
        updateTimerText(0);
    }

    private long elapsedMillis() {
        return Math.max(0, SystemClock.elapsedRealtime() - puzzleStartedAt);
    }

    private void updateTimerText(long millis) {
        long totalSeconds = millis / 1000;
        timerText.setText(getString(R.string.timer_format, totalSeconds / 60, totalSeconds % 60));
    }

    private String formatElapsedTime(long millis) {
        long totalSeconds = millis / 1000;
        return String.format(java.util.Locale.getDefault(), "%02d:%02d", totalSeconds / 60, totalSeconds % 60);
    }

    private void showRules() {
        new AlertDialog.Builder(this)
                .setTitle(R.string.rules_title)
                .setMessage(R.string.rules_body)
                .setPositiveButton(R.string.got_it, null)
                .show();
    }

    @Override
    public void onGameChanged(TicTacLogicView.Snapshot snapshot) {
        levelText.setText(getString(R.string.level_format, snapshot.level + 1,
                snapshot.levelName, snapshot.size, snapshot.size));
        progressText.setText(getString(R.string.progress_format, snapshot.filled, snapshot.total));
        messageText.setText(snapshot.message);
        statusText.setText(snapshot.completed ? R.string.status_done : R.string.status_playing);
        updateScoreText(GameProgress.getTotalScore(this));
        if (!snapshot.completed) {
            completionDialogShown = false;
        } else if (!completionDialogShown) {
            completionDialogShown = true;
            timerHandler.removeCallbacks(timerTick);
            GameProgress.addCompletedCount(this, snapshot.level);
            int earned = GameProgress.pointsForLevel(snapshot.level);
            int total = GameProgress.addCompletedLevel(this, snapshot.level);
            long elapsed = elapsedMillis();
            long best = GameProgress.recordTime(this, snapshot.level, elapsed);
            boolean isNewBest = (best == elapsed);
            int sb = streakBonus(streakCount + 1);
            int isNewBestBonus = isNewBest ? 2 : 0;
            int earnedTotal = earned + isNewBestBonus + sb;
            int nextStreak = streakCount + 1;
            if (isNewBestBonus > 0) {
                total = GameProgress.addBonus(this, isNewBestBonus);
            }
            if (sb > 0) {
                total = GameProgress.addBonus(this, sb);
            }
            updateScoreText(total);
            showCompletionDialog(snapshot, earnedTotal, total, GameProgress.formatTime(elapsed),
                    GameProgress.formatTime(best), isNewBest, nextStreak, sb);
        }
    }

    private void updateScoreText(int total) {
        scoreText.setText(getString(R.string.score_format, total));
    }

    private void showCompletionDialog(TicTacLogicView.Snapshot snapshot, int earned, int total,
                                      String elapsedTime, String bestTime, boolean isNewBest,
                                      int streak, int streakBonus) {
        String message = getString(R.string.completion_message, snapshot.levelName,
                elapsedTime, earned, total);
        message += isNewBest ? "\n\n★ 新纪录！（额外 +2 积分）" : "\n\n最佳时间：" + bestTime;
        if (streakBonus > 0) {
            message += "\n\n🔥 连胜 +" + streakBonus + " 积分（" + streak + " 局）";
        }
        new AlertDialog.Builder(this)
                .setTitle(R.string.completion_title)
                .setMessage(message)
                .setCancelable(false)
                .setPositiveButton(R.string.return_home,
                        (dialog, which) -> {
                            streakCount = 0;
                            returnToHome();
                        })
                .setNegativeButton("再来一关", (dialog, which) -> {
                    completionDialogShown = false;
                    streakCount++;
                    puzzleView.restart();
                    startTimer();
                })
                .show();
    }
}
