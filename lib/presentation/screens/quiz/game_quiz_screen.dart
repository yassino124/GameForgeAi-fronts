import 'dart:math';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/local_notifications_service.dart';
import '../../../core/themes/app_theme.dart';

class GameQuizScreen extends StatefulWidget {
  const GameQuizScreen({super.key});

  @override
  State<GameQuizScreen> createState() => _GameQuizScreenState();
}

class _GameQuizScreenState extends State<GameQuizScreen> {
  static const _kPrefPracticeNonce = 'quiz_practice_nonce';
  static const _kPrefLastDate = 'quiz_last_date_ymd';
  static const _kPrefStreak = 'quiz_streak';
  static const _kPrefBestScore = 'quiz_best_score';
  static const _kPrefTotalXp = 'quiz_total_xp';
  static const _kPrefTotalPlays = 'quiz_total_plays';
  static const _kPrefBadges = 'quiz_badges';
  static const _kPrefLastXpEarned = 'quiz_last_xp_earned';
  static const _kPrefFreezeUsedWeekKey = 'quiz_freeze_used_week_key';

  static const _kModeDaily = 'daily';
  static const _kModePractice = 'practice';

  static const int _kDailyQuestionCount = 7;

  static const List<Map<String, Object>> _questionBank = [
    {
      'q': 'An “endless runner” game usually has…',
      'a': ['Turn-based combat', 'Auto-running + obstacles', 'City-building', 'Only dialogues'],
      'c': 1,
    },
    {
      'q': 'In a platformer, what helps jumps feel better?',
      'a': ['High input delay', 'Coyote time + jump buffer', 'No air control', 'Only cutscenes'],
      'c': 1,
    },
    {
      'q': 'A good “roguelite” loop is…',
      'a': ['One long mission', 'Short runs + upgrades + repeat', 'No progression', 'Only menus'],
      'c': 1,
    },
    {
      'q': '“Juice” in game feel means…',
      'a': ['UI colors only', 'Extra feedback (VFX/SFX/shake)', 'Server caching', 'Database backup'],
      'c': 1,
    },
    {
      'q': 'Best onboarding for most players is…',
      'a': ['Long tutorial text', 'Teach by playing (small steps)', 'Hide controls', 'Complex menus first'],
      'c': 1,
    },
    {
      'q': 'A good difficulty curve is…',
      'a': ['Random spikes', 'Gradual and fair', 'Impossible at level 1', 'Always the same'],
      'c': 1,
    },
    {
      'q': 'A “boss fight” is usually…',
      'a': ['A small tutorial', 'A big challenge at the end of a level', 'A settings menu', 'A loading screen'],
      'c': 1,
    },
    {
      'q': 'What helps casual games keep players coming back?',
      'a': ['Daily streaks / missions', 'Long credits', 'No rewards', 'Unskippable ads'],
      'c': 0,
    },
    {
      'q': 'For mobile controls, usually best is…',
      'a': ['Tiny buttons', 'Big buttons + feedback', 'No feedback', 'Hard gestures for jump'],
      'c': 1,
    },
    {
      'q': '“Meta progression” is…',
      'a': ['No unlocks ever', 'Permanent upgrades between runs', 'Only a tutorial', 'Random music'],
      'c': 1,
    },
    {
      'q': 'A strong marketplace hook is…',
      'a': ['No screenshots', 'Playable demo + remix button', 'Only a logo', 'No description'],
      'c': 1,
    },
    {
      'q': 'Which is important for good game audio?',
      'a': ['Mute everything', 'Clear SFX feedback for actions', 'Only one sound', 'No volume settings'],
      'c': 1,
    },
    {
      'q': 'A “prototype” is…',
      'a': ['A final polished game', 'A quick test version of an idea', 'A marketing video', 'A bug report'],
      'c': 1,
    },
    {
      'q': 'To make a character feel faster, you can…',
      'a': ['Add motion lines and speed sound', 'Remove animations', 'Lower FPS', 'Hide the character'],
      'c': 0,
    },
  ];

  List<Map<String, Object>> _questions = const [];
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _revealed = false;

  String _mode = _kModeDaily;

  bool _loadingPrefs = true;
  int _streak = 0;
  int _bestScore = 0;
  int _totalXp = 0;
  int _totalPlays = 0;
  List<String> _badges = const [];
  int _lastXpEarned = 0;
  int _xpEarnedThisRun = 0;
  List<String> _newBadgesThisRun = const [];
  String? _freezeUsedWeekKey;

  bool _quizReminderEnabled = true;
  int _quizReminderHour = 20;
  int _quizReminderMinute = 0;

  @override
  void initState() {
    super.initState();
    _questions = _pickQuestionsForToday();
    _loadPrefs();
  }

  String _weekKey(DateTime d) {
    // Weekly key based on the Monday start date (no intl dependency).
    final date = DateTime(d.year, d.month, d.day);
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    return '${weekStart.year.toString().padLeft(4, '0')}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
  }

  String _currentWeekKey() => _weekKey(DateTime.now());

  String _badgeSubtitle(String id) {
    switch (id) {
      case 'first_win':
        return 'Answer at least 1 question correctly';
      case 'streak_3':
        return 'Keep a 3-day daily streak';
      case 'perfect':
        return 'Get a perfect score (daily)';
      case 'plays_10':
        return 'Complete 10 quizzes (daily or practice)';
      default:
        return '';
    }
  }

  IconData _badgeIcon(String id) {
    switch (id) {
      case 'first_win':
        return Icons.bolt_rounded;
      case 'streak_3':
        return Icons.local_fire_department_rounded;
      case 'perfect':
        return Icons.workspace_premium_rounded;
      case 'plays_10':
        return Icons.repeat_rounded;
      default:
        return Icons.verified_rounded;
    }
  }

  String _badgeProgressText(String id) {
    switch (id) {
      case 'first_win':
        return _bestScore > 0 ? 'Done' : '0/1';
      case 'streak_3':
        return '${min(_streak, 3)}/3';
      case 'perfect':
        return _bestScore >= _kDailyQuestionCount ? 'Done' : '${min(_bestScore, _kDailyQuestionCount)}/$_kDailyQuestionCount';
      case 'plays_10':
        return '${min(_totalPlays, 10)}/10';
      default:
        return '';
    }
  }

  void _openAchievements() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _buildAchievementsSheet(context);
      },
    );
  }

  Widget _buildAchievementsSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final level = _levelFromXp(_totalXp);
    final badges = const <String>['first_win', 'streak_3', 'perfect', 'plays_10'];
    final freezeAvailable = (_freezeUsedWeekKey ?? '') != _currentWeekKey();

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppBorderRadius.xlarge),
              topRight: Radius.circular(AppBorderRadius.xlarge),
            ),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.emoji_events_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Achievements',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Level $level • ${_totalXp} XP',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: _statChip(
                        context,
                        icon: Icons.local_fire_department_rounded,
                        label: 'Daily streak',
                        value: _loadingPrefs ? '…' : _streak.toString(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _statChip(
                        context,
                        icon: Icons.repeat_rounded,
                        label: 'Plays',
                        value: _loadingPrefs ? '…' : _totalPlays.toString(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: _statChip(
                        context,
                        icon: Icons.ac_unit_rounded,
                        label: 'Freeze',
                        value: _loadingPrefs ? '…' : (freezeAvailable ? 'Available' : 'Used'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notifications_active_rounded, color: cs.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Daily reminder',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Switch.adaptive(
                            value: _quizReminderEnabled,
                            onChanged: (v) async {
                              await LocalNotificationsService.setDailyQuizReminderEnabled(v);
                              if (!mounted) return;
                              setState(() => _quizReminderEnabled = v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LayoutBuilder(
                        builder: (context, c) {
                          final timeLabel = _quizReminderEnabled
                              ? 'Every day at ${_quizReminderHour.toString().padLeft(2, '0')}:${_quizReminderMinute.toString().padLeft(2, '0')}'
                              : 'Disabled';

                          final timeText = Text(
                            timeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                          );

                          final changeBtn = IconButton(
                            tooltip: 'Change time',
                            onPressed: _quizReminderEnabled ? _pickQuizReminderTime : null,
                            icon: const Icon(Icons.schedule_rounded),
                            color: cs.primary,
                          );

                          if (c.maxWidth < 360) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                timeText,
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: changeBtn,
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: timeText),
                              changeBtn,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await LocalNotificationsService.showQuizTestNotification();
                          },
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Send test notification'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxxl),
                  itemCount: badges.length,
                  itemBuilder: (context, idx) {
                    final id = badges[idx];
                    final unlocked = _badges.contains(id);
                    final title = _badgeLabel(id);
                    final subtitle = _badgeSubtitle(id);
                    final icon = _badgeIcon(id);
                    final progress = _badgeProgressText(id);

                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(AppBorderRadius.large),
                        border: Border.all(
                          color: unlocked ? cs.primary.withOpacity(0.32) : cs.outlineVariant.withOpacity(0.6),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: (unlocked ? cs.primary : cs.surfaceVariant).withOpacity(unlocked ? 0.14 : 1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                            ),
                            child: Icon(
                              icon,
                              color: unlocked ? cs.primary : cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                if (subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: unlocked ? AppColors.success.withOpacity(0.12) : cs.surfaceVariant,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                                ),
                                child: Text(
                                  unlocked ? 'Unlocked' : 'Locked',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: unlocked ? AppColors.success : cs.onSurfaceVariant,
                                      ),
                                ),
                              ),
                              if (!unlocked && progress.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  progress,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _stableHash(String s) {
    // djb2
    var h = 5381;
    for (var i = 0; i < s.length; i++) {
      h = ((h << 5) + h) ^ s.codeUnitAt(i);
    }
    return h & 0x7fffffff;
  }

  List<Map<String, Object>> _pickQuestionsForToday() {
    final seed = _stableHash(_todayYmd());
    final rnd = Random(seed);
    final copy = List<Map<String, Object>>.from(_questionBank);
    copy.shuffle(rnd);
    return copy.take(7).toList(growable: false);
  }

  List<Map<String, Object>> _pickQuestionsForPractice(int nonce) {
    final seed = _stableHash('${_todayYmd()}_practice_$nonce');
    final rnd = Random(seed);
    final copy = List<Map<String, Object>>.from(_questionBank);
    copy.shuffle(rnd);
    return copy.take(7).toList(growable: false);
  }

  Future<void> _switchMode(String next) async {
    if (next == _mode) return;

    final p = await SharedPreferences.getInstance();
    final nonce = (p.getInt(_kPrefPracticeNonce) ?? 0) + 1;
    await p.setInt(_kPrefPracticeNonce, nonce);

    if (!mounted) return;
    setState(() {
      _mode = next;
      _index = 0;
      _score = 0;
      _selected = null;
      _revealed = false;
      _xpEarnedThisRun = 0;
      _newBadgesThisRun = const [];
      _questions = (next == _kModeDaily) ? _pickQuestionsForToday() : _pickQuestionsForPractice(nonce);
    });
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _streak = p.getInt(_kPrefStreak) ?? 0;
      _bestScore = p.getInt(_kPrefBestScore) ?? 0;
      _totalXp = p.getInt(_kPrefTotalXp) ?? 0;
      _totalPlays = p.getInt(_kPrefTotalPlays) ?? 0;
      _badges = p.getStringList(_kPrefBadges) ?? const [];
      _lastXpEarned = p.getInt(_kPrefLastXpEarned) ?? 0;
      _freezeUsedWeekKey = p.getString(_kPrefFreezeUsedWeekKey);
      _quizReminderEnabled = p.getBool(LocalNotificationsService.kPrefQuizReminderEnabled) ?? true;
      _quizReminderHour = p.getInt(LocalNotificationsService.kPrefQuizReminderHour) ?? 20;
      _quizReminderMinute = p.getInt(LocalNotificationsService.kPrefQuizReminderMinute) ?? 0;
      _loadingPrefs = false;
    });
  }

  Future<void> _pickQuizReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _quizReminderHour, minute: _quizReminderMinute),
    );
    if (picked == null) return;

    await LocalNotificationsService.setDailyQuizReminderTime(
      hour: picked.hour,
      minute: picked.minute,
    );

    if (!mounted) return;
    setState(() {
      _quizReminderHour = picked.hour;
      _quizReminderMinute = picked.minute;
    });
  }

  int _levelFromXp(int xp) {
    // Simple curve: 0-99 => lvl 1, 100-219 => lvl 2, etc.
    final v = max(0, xp);
    return (sqrt(v / 100).floor()) + 1;
  }

  String _todayYmd() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _yesterdayYmd() {
    final d = DateTime.now().subtract(const Duration(days: 1));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _finishAndPersist() async {
    final p = await SharedPreferences.getInstance();
    final today = _todayYmd();
    final last = p.getString(_kPrefLastDate);

    final currentWeekKey = _currentWeekKey();
    final freezeUsedWeekKey = p.getString(_kPrefFreezeUsedWeekKey);
    final freezeAvailableThisWeek = freezeUsedWeekKey != currentWeekKey;

    int nextStreak = p.getInt(_kPrefStreak) ?? 0;
    if (_mode == _kModeDaily) {
      if (last == today) {
        nextStreak = p.getInt(_kPrefStreak) ?? 0;
      } else if (last == _yesterdayYmd()) {
        nextStreak = (p.getInt(_kPrefStreak) ?? 0) + 1;
      } else {
        final currentStreak = p.getInt(_kPrefStreak) ?? 0;
        if (currentStreak > 0 && freezeAvailableThisWeek) {
          // Use weekly freeze to protect streak (doesn't increase it).
          nextStreak = currentStreak;
          await p.setString(_kPrefFreezeUsedWeekKey, currentWeekKey);
        } else {
          nextStreak = 1;
        }
      }
    }

    final nextBest = max(p.getInt(_kPrefBestScore) ?? 0, _score);

    final total = _questions.length;
    final prevXp = p.getInt(_kPrefTotalXp) ?? 0;
    final prevPlays = p.getInt(_kPrefTotalPlays) ?? 0;
    final prevBadges = p.getStringList(_kPrefBadges) ?? <String>[];

    var earned = _score * (_mode == _kModeDaily ? 10 : 5);
    if (_mode == _kModeDaily && _score >= total) earned += 15;
    if (_mode == _kModeDaily) earned += min(10, nextStreak * 2);

    final nextXp = prevXp + earned;
    final nextPlays = prevPlays + 1;

    final newBadges = <String>[];
    void unlock(String id) {
      if (prevBadges.contains(id)) return;
      prevBadges.add(id);
      newBadges.add(id);
    }

    if (_score > 0) unlock('first_win');
    if (nextStreak >= 3) unlock('streak_3');
    if (_score >= total) unlock('perfect');
    if (nextPlays >= 10) unlock('plays_10');

    if (_mode == _kModeDaily) {
      await p.setString(_kPrefLastDate, today);
      await p.setInt(_kPrefStreak, nextStreak);
    }
    await p.setInt(_kPrefBestScore, nextBest);
    await p.setInt(_kPrefTotalXp, nextXp);
    await p.setInt(_kPrefTotalPlays, nextPlays);
    await p.setStringList(_kPrefBadges, prevBadges);
    await p.setInt(_kPrefLastXpEarned, earned);

    if (!mounted) return;
    setState(() {
      _streak = nextStreak;
      _bestScore = nextBest;
      _totalXp = nextXp;
      _totalPlays = nextPlays;
      _badges = List<String>.from(prevBadges);
      _lastXpEarned = earned;
      _xpEarnedThisRun = earned;
      _newBadgesThisRun = List<String>.from(newBadges);
      _freezeUsedWeekKey = p.getString(_kPrefFreezeUsedWeekKey);
    });

    if (_mode == _kModeDaily) {
      try {
        await LocalNotificationsService.bootstrapDailyQuizReminder();
      } catch (_) {}
    }
  }

  void _select(int idx) {
    if (_revealed) return;
    setState(() {
      _selected = idx;
    });
  }

  Future<void> _confirm() async {
    if (_selected == null || _revealed) return;
    final correct = _questions[_index]['c'] as int;
    final ok = _selected == correct;

    setState(() {
      _revealed = true;
      if (ok) _score += 1;
    });

    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (!mounted) return;

    if (_index >= _questions.length - 1) {
      await _finishAndPersist();
      setState(() {
        _index = _questions.length;
      });
      return;
    }

    setState(() {
      _index += 1;
      _selected = null;
      _revealed = false;
    });
  }

  void _restart() {
    setState(() {
      _index = 0;
      _score = 0;
      _selected = null;
      _revealed = false;
      _xpEarnedThisRun = 0;
      _newBadgesThisRun = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final isDone = _index >= _questions.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Quiz'),
        actions: [
          IconButton(
            tooltip: 'Achievements',
            onPressed: _openAchievements,
            icon: const Icon(Icons.emoji_events_rounded),
          ),
          if (!isDone)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Center(
                child: Text(
                  '${min(_index + 1, _questions.length)}/${_questions.length}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary.withOpacity(0.10),
                  cs.surface,
                  cs.surface,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: isDone ? _buildResult(context) : _buildQuestion(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = _questions[_index];
    final question = q['q'] as String;
    final answers = (q['a'] as List).cast<String>();
    final correct = q['c'] as int;

    final progress = (_index + 1) / _questions.length;

    Color borderFor(int i) {
      if (!_revealed) {
        if (_selected == i) return cs.primary;
        return cs.outlineVariant.withOpacity(0.6);
      }
      if (i == correct) return AppColors.success;
      if (_selected == i && _selected != correct) return cs.error;
      return cs.outlineVariant.withOpacity(0.6);
    }

    Color fillFor(int i) {
      if (!_revealed) {
        if (_selected == i) return cs.primary.withOpacity(0.10);
        return cs.surface;
      }
      if (i == correct) return AppColors.success.withOpacity(0.10);
      if (_selected == i && _selected != correct) return cs.error.withOpacity(0.08);
      return cs.surface;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.quiz_rounded, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _mode == _kModeDaily ? 'Daily Game Quiz' : 'Practice Quiz',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Score: $_score • ${_mode == _kModeDaily ? 'Streak' : 'Daily streak'}: ${_loadingPrefs ? '…' : _streak}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.92),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Level: ${_loadingPrefs ? '…' : _levelFromXp(_totalXp)} • XP: ${_loadingPrefs ? '…' : _totalXp}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.88),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _modePill(
                  context,
                  label: 'Daily',
                  active: _mode == _kModeDaily,
                  onTap: () => _switchMode(_kModeDaily),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _modePill(
                  context,
                  label: 'Practice',
                  active: _mode == _kModePractice,
                  onTap: () => _switchMode(_kModePractice),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: cs.surfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Container(
              key: ValueKey('q_$_index'),
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ...List.generate(answers.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppBorderRadius.large),
                          onTap: () => _select(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: fillFor(i),
                              borderRadius: BorderRadius.circular(AppBorderRadius.large),
                              border: Border.all(color: borderFor(i), width: 1.4),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (_selected == i) ? cs.primary : cs.surfaceVariant,
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + i),
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                            color: (_selected == i) ? cs.onPrimary : cs.onSurfaceVariant,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.lg),
                                Expanded(
                                  child: Text(
                                    answers[i],
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (_revealed && i == correct)
                                  Icon(Icons.check_circle_rounded, color: AppColors.success)
                                else if (_revealed && _selected == i && _selected != correct)
                                  Icon(Icons.cancel_rounded, color: cs.error)
                                else
                                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_selected == null || _revealed) ? null : _confirm,
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = _questions.length;
    final level = _levelFromXp(_totalXp);
    final earned = _xpEarnedThisRun > 0 ? _xpEarnedThisRun : _lastXpEarned;

    String title;
    String subtitle;
    if (_score >= total - 1) {
      title = 'Legend!';
      subtitle = 'You really know your game dev.';
    } else if (_score >= (total * 0.7).floor()) {
      title = 'Great run!';
      subtitle = 'Nice instincts. Keep the streak.';
    } else {
      title = 'Good start!';
      subtitle = 'Try again tomorrow and level up.';
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
              ),
              child: Column(
                children: [
                  Text('Your score', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text('$_score / $total', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: _statChip(
                          context,
                          icon: Icons.local_fire_department_rounded,
                          label: 'Streak',
                          value: _loadingPrefs ? '…' : _streak.toString(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _statChip(
                          context,
                          icon: Icons.star_rounded,
                          label: 'Best',
                          value: _bestScore.toString(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _statChip(
                          context,
                          icon: Icons.bolt_rounded,
                          label: 'XP +',
                          value: earned.toString(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _statChip(
                          context,
                          icon: Icons.rocket_launch_rounded,
                          label: 'Level',
                          value: level.toString(),
                        ),
                      ),
                    ],
                  ),
                  if (_newBadgesThisRun.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'New badges',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _newBadgesThisRun.map((b) {
                        final label = _badgeLabel(b);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: cs.surfaceVariant,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, color: cs.primary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                label,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        );
                      }).toList(growable: false),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _restart,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Play again'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Share.share('I scored $_score/$total on GameForge AI Quiz! 🎮🔥');
                    },
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Come back tomorrow to keep your streak.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  String _badgeLabel(String id) {
    switch (id) {
      case 'first_win':
        return 'First Win';
      case 'streak_3':
        return '3-Day Streak';
      case 'perfect':
        return 'Perfect Score';
      case 'plays_10':
        return '10 Quizzes';
      default:
        return id;
    }
  }

  Widget _statChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _modePill(
    BuildContext context, {
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? cs.primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? cs.primary.withOpacity(0.35) : Colors.transparent),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: active ? cs.primary : cs.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
