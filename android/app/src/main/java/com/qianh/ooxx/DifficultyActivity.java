package com.qianh.ooxx;

import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Color;
import android.os.Bundle;
import android.widget.TextView;

import androidx.activity.EdgeToEdge;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.app.AppCompatDelegate;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

import com.google.android.material.card.MaterialCardView;

public class DifficultyActivity extends AppCompatActivity {
    public static final String EXTRA_DIFFICULTY = "difficulty";
    private TextView scoreText;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        EdgeToEdge.enable(this);
        setContentView(R.layout.activity_difficulty);
        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.difficultyRoot), (view, insets) -> {
            Insets bars = insets.getInsets(WindowInsetsCompat.Type.systemBars());
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom);
            return insets;
        });

        scoreText = findViewById(R.id.tvTotalScore);
        findViewById(R.id.btnEasy).setOnClickListener(v -> startGame(0));
        findViewById(R.id.btnMedium).setOnClickListener(v -> startGame(1));
        findViewById(R.id.btnHard).setOnClickListener(v -> startGame(2));
        findViewById(R.id.btnThemeToggle).setOnClickListener(v -> toggleTheme());
    }

    @Override
    protected void onResume() {
        super.onResume();
        scoreText.setText(getString(R.string.total_score_format, GameProgress.getTotalScore(this)));
        updateDifficultyButtons();
        updateThemeToggleText();
        applyCardTheme();
    }

    private void updateDifficultyButtons() {
        int[] ids = {R.id.tvBestEasy, R.id.tvBestMedium, R.id.tvBestHard};
        for (int i = 0; i < 3; i++) {
            long best = GameProgress.getBestTime(this, i);
            int count = GameProgress.getCompletedCount(this, i);
            String bestText = best < 0 ? "暂无记录" : "最佳 " + GameProgress.formatTime(best);
            String text = bestText + "  ·  已完成 " + count + " 局";
            TextView tv = findViewById(ids[i]);
            tv.setText(text);
        }
    }

    private void updateThemeToggleText() {
        int nightMode = getResources().getConfiguration().uiMode
                & Configuration.UI_MODE_NIGHT_MASK;
        boolean isDark = nightMode == Configuration.UI_MODE_NIGHT_YES;
        TextView btn = findViewById(R.id.btnThemeToggle);
        btn.setText(isDark ? "浅色模式" : "深色模式");
    }

    private void applyCardTheme() {
        int nightMode = getResources().getConfiguration().uiMode
                & Configuration.UI_MODE_NIGHT_MASK;
        boolean isDark = nightMode == Configuration.UI_MODE_NIGHT_YES;
        MaterialCardView card = findViewById(R.id.cardHeader);
        card.setCardBackgroundColor(Color.parseColor(isDark ? "#1E293B" : "#18324B"));
    }

    private void toggleTheme() {
        int nightMode = getResources().getConfiguration().uiMode
                & Configuration.UI_MODE_NIGHT_MASK;
        boolean isDark = nightMode == Configuration.UI_MODE_NIGHT_YES;
        AppCompatDelegate.setDefaultNightMode(
                isDark ? AppCompatDelegate.MODE_NIGHT_NO : AppCompatDelegate.MODE_NIGHT_YES);
    }

    private void startGame(int difficulty) {
        Intent intent = new Intent(this, MainActivity.class);
        intent.putExtra(EXTRA_DIFFICULTY, difficulty);
        startActivity(intent);
    }
}
