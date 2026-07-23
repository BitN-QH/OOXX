package com.example.ooxx;

import android.content.Context;
import android.content.SharedPreferences;

final class GameProgress {
    private static final String PREFS_NAME = "tic_tac_logic_progress";
    private static final String KEY_TOTAL_SCORE = "total_score";
    private static final String KEY_INITIALIZED = "score_initialized";
    private static final int INITIAL_SCORE = 2;
    private static final int[] LEVEL_POINTS = {2, 5, 7};
    private static final String KEY_BEST_TIME_PREFIX = "best_time_";
    private static final String KEY_COMPLETED_PREFIX = "completed_";
    private static final String KEY_THEME_INDEX = "theme_index";

    private GameProgress() { }

    static int getTotalScore(Context context) {
        SharedPreferences preferences = preferences(context);
        if (!preferences.getBoolean(KEY_INITIALIZED, false)) {
            SharedPreferences.Editor editor = preferences.edit().putBoolean(KEY_INITIALIZED, true);
            if (!preferences.contains(KEY_TOTAL_SCORE)) {
                editor.putInt(KEY_TOTAL_SCORE, INITIAL_SCORE);
            }
            editor.apply();
        }
        return preferences.getInt(KEY_TOTAL_SCORE, INITIAL_SCORE);
    }

    static int pointsForLevel(int level) {
        return LEVEL_POINTS[Math.max(0, Math.min(level, LEVEL_POINTS.length - 1))];
    }

    static int addCompletedLevel(Context context, int level) {
        int total = getTotalScore(context) + pointsForLevel(level);
        preferences(context).edit().putInt(KEY_TOTAL_SCORE, total).apply();
        return total;
    }

    static int addBonus(Context context, int bonus) {
        int total = getTotalScore(context) + bonus;
        preferences(context).edit().putInt(KEY_TOTAL_SCORE, total).apply();
        return total;
    }

    static long getBestTime(Context context, int level) {
        return preferences(context).getLong(KEY_BEST_TIME_PREFIX + level, -1L);
    }

    static long recordTime(Context context, int level, long millis) {
        long best = getBestTime(context, level);
        if (best < 0 || millis < best) {
            preferences(context).edit().putLong(KEY_BEST_TIME_PREFIX + level, millis).apply();
            return millis;
        }
        return best;
    }

    static String formatTime(long millis) {
        long totalSeconds = millis / 1000;
        return String.format(java.util.Locale.getDefault(), "%02d:%02d",
                totalSeconds / 60, totalSeconds % 60);
    }

    static int getCompletedCount(Context context, int level) {
        return preferences(context).getInt(KEY_COMPLETED_PREFIX + level, 0);
    }

    static int addCompletedCount(Context context, int level) {
        int count = getCompletedCount(context, level) + 1;
        preferences(context).edit().putInt(KEY_COMPLETED_PREFIX + level, count).apply();
        return count;
    }

    static int getThemeIndex(Context context) {
        return preferences(context).getInt(KEY_THEME_INDEX, 0);
    }

    static void setThemeIndex(Context context, int index) {
        preferences(context).edit().putInt(KEY_THEME_INDEX, index).apply();
    }

    static boolean spend(Context context, int cost) {
        int total = getTotalScore(context);
        if (total < cost) return false;
        preferences(context).edit().putInt(KEY_TOTAL_SCORE, total - cost).apply();
        return true;
    }

    private static SharedPreferences preferences(Context context) {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }
}
