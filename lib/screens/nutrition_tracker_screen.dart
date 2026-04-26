import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/nutrition_persistence_service.dart';
import '../services/nutrition_service.dart';
import 'meal_planner_screen.dart';

class NutritionTrackerScreen extends StatefulWidget {
  final bool showAppBar;
  final bool isActive;

  const NutritionTrackerScreen({
    super.key,
    this.showAppBar = true,
    this.isActive = true,
  });

  @override
  State<NutritionTrackerScreen> createState() => _NutritionTrackerScreenState();
}

class _NutritionTrackerScreenState extends State<NutritionTrackerScreen> {
  static const _goalCaloriesKey = 'nutrition_calc_goal_calories';
  static const _goalProteinKey = 'nutrition_calc_goal_protein';
  static const _goalWaterKey = 'nutrition_calc_goal_water';

  final NutritionPersistenceService _persistence =
      NutritionPersistenceService.instance;
  List<_MealEntry> _entries = [];
  NutritionResult? _goalResult;
  double _waterGoalCups = 8;
  int? _savedCalorieGoal;
  double _savedProteinGoal = 0;
  double _savedWaterGoal = 0;
  bool _isLoading = true;
  String? _lastLoadedUserId;
  Timer? _midnightResetTimer;

  @override
  void initState() {
    super.initState();
    _loadTrackerData();
    _scheduleMidnightReset();
  }

  @override
  void dispose() {
    _midnightResetTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (_lastLoadedUserId != userId) {
      _loadTrackerData();
    }
  }

  @override
  void didUpdateWidget(covariant NutritionTrackerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _loadTrackerData();
    }
  }

  Future<void> _loadTrackerData() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    final savedEntries = await _persistence.loadMealPlanEntries(userId);
    final calculatorState = await _persistence.loadCalculatorState(userId);
    final parsedEntries = savedEntries.map(_MealEntry.fromMealPlanJson).toList();
    final goal = _loadGoalFromCalculatorState(calculatorState);

    if (!mounted) return;
    setState(() {
      _lastLoadedUserId = userId;
      _entries = parsedEntries;
      _goalResult = goal;
      final calorieValue = calculatorState?[_goalCaloriesKey];
      _savedCalorieGoal = calorieValue is int
          ? calorieValue
          : int.tryParse(calorieValue?.toString() ?? '');
      _savedProteinGoal =
          double.tryParse(calculatorState?[_goalProteinKey]?.toString() ?? '') ?? 0;
      _savedWaterGoal =
          double.tryParse(calculatorState?[_goalWaterKey]?.toString() ?? '') ?? 0;
      _waterGoalCups =
          _savedWaterGoal > 0 ? _savedWaterGoal : _estimateWaterGoal(goal);
      _isLoading = false;
    });
    _scheduleMidnightReset();
  }

  void _scheduleMidnightReset() {
    _midnightResetTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightResetTimer = Timer(nextMidnight.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleMidnightReset();
    });
  }

  int _currentDayIndex() => DateTime.now().weekday - 1;

  Iterable<_MealEntry> get _todayEntries => _entries.where((entry) {
        if (entry.dayIndex != null) {
          return entry.dayIndex == _currentDayIndex();
        }

        final now = DateTime.now();
        final loggedAt = entry.loggedAt.toLocal();
        return loggedAt.year == now.year &&
            loggedAt.month == now.month &&
            loggedAt.day == now.day;
      });

  NutritionResult? _loadGoalFromCalculatorState(Map<String, dynamic>? state) {
    if (state == null) return null;
    final resultJson = state['result'];
    if (resultJson is! Map) return null;
    final resultMap = Map<String, dynamic>.from(resultJson);
    final nutrientsRaw = resultMap['nutrients'];
    final nutrients = nutrientsRaw is List
        ? nutrientsRaw
            .whereType<Map>()
            .map(
              (item) => NutrientTarget(
                label: item['label']?.toString() ?? '',
                amount: item['amount']?.toString() ?? '',
                adjustedAmount: item['adjustedAmount']?.toString(),
                detail: item['detail']?.toString() ?? '',
                foods: item['foods'] is List
                    ? (item['foods'] as List)
                        .map((food) => food.toString())
                        .toList()
                    : const [],
              ),
            )
            .toList()
        : const <NutrientTarget>[];

    return NutritionResult(
      calories: int.tryParse(resultMap['calories']?.toString() ?? '') ?? 0,
      healthyCalories: resultMap['healthyCalories'] == null
          ? null
          : int.tryParse(resultMap['healthyCalories'].toString()),
      bmi: double.tryParse(resultMap['bmi']?.toString() ?? '') ?? 0,
      bmiLabel: resultMap['bmiLabel']?.toString() ?? '',
      calorieDetail: resultMap['calorieDetail']?.toString() ?? '',
      healthyCaloriesDetail: resultMap['healthyCaloriesDetail']?.toString(),
      note: resultMap['note']?.toString() ?? '',
      nutrients: nutrients,
    );
  }

  double _estimateWaterGoal(NutritionResult? goal) {
    if (goal == null) {
      return 8;
    }
    final cups = goal.calories / 240;
    return cups.clamp(6, 14).toDouble();
  }

  Future<void> _saveEntries() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    await _persistence.saveTrackerEntries(
      userId,
      _entries.map((entry) => entry.toJson()).toList(),
    );
  }
  // ignore: unused_element
  Future<void> _showAddMealDialog() async {
    final navigator = Navigator.of(context);
    final nameController = TextEditingController();
    final itemsController = TextEditingController();
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final waterController = TextEditingController();
    String mealType = 'Breakfast';

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Meal Entry',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: mealType,
                decoration: const InputDecoration(labelText: 'Meal'),
                items: const [
                  DropdownMenuItem(value: 'Breakfast', child: Text('Breakfast')),
                  DropdownMenuItem(value: 'Lunch', child: Text('Lunch')),
                  DropdownMenuItem(value: 'Dinner', child: Text('Dinner')),
                  DropdownMenuItem(value: 'Snack', child: Text('Snack')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    mealType = value;
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Meal title',
                  hintText: 'Chicken salad',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: itemsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Items',
                  hintText: 'Chicken, lettuce, tomatoes',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: caloriesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Calories'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: proteinController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Protein (g)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: waterController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Water with meal (cups)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final calories = double.tryParse(caloriesController.text.trim());
              if (nameController.text.trim().isEmpty ||
                  itemsController.text.trim().isEmpty ||
                  calories == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please add a meal title, items, and calories.',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.red[600],
                  ),
                );
                return;
              }

              final protein =
                  double.tryParse(proteinController.text.trim()) ?? 0;
              final water = double.tryParse(waterController.text.trim()) ?? 0;

              setState(() {
                _entries = [
                  _MealEntry(
                    id: 'meal_${DateTime.now().millisecondsSinceEpoch}',
                    mealType: mealType,
                    title: nameController.text.trim(),
                    items: itemsController.text.trim(),
                    calories: calories,
                    protein: protein,
                    waterCups: water,
                    loggedAt: DateTime.now(),
                  ),
                  ..._entries,
                ];
              });
              await _saveEntries();
              if (!mounted) return;
              navigator.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Future<void> _deleteMeal(String id) async {
    setState(() {
      _entries = _entries.where((entry) => entry.id != id).toList();
    });
    await _saveEntries();
  }

  double get _totalCalories =>
      _todayEntries.fold(0, (sum, entry) => sum + entry.calories);

  double get _totalProtein =>
      _todayEntries.fold(0, (sum, entry) => sum + entry.protein);

  double get _totalWater =>
      _todayEntries.fold(0, (sum, entry) => sum + entry.waterCups);

  bool get _hasGoalData =>
      _savedCalorieGoal != null ||
      _savedProteinGoal > 0 ||
      _savedWaterGoal > 0 ||
      _goalResult != null;

  double get _proteinGoal {
    if (_savedProteinGoal > 0) {
      return _savedProteinGoal;
    }

    final proteinTargets = _goalResult?.nutrients
            .where((nutrient) => nutrient.label == 'Protein')
            .toList() ??
        const [];
    final proteinTarget = proteinTargets.isNotEmpty ? proteinTargets.first : null;
    final match = RegExp(r'[\d.]+').firstMatch(proteinTarget?.amount ?? '');
    return double.tryParse(match?.group(0) ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goalCalories =
        _savedCalorieGoal ?? _goalResult?.healthyCalories ?? _goalResult?.calories;

    final content = SafeArea(
      top: !widget.showAppBar,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.showAppBar)
                    Text(
                      'Nutrition Tracker',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF102A43),
                      ),
                    ),
                  if (!widget.showAppBar) const SizedBox(height: 16),
                  if (!_hasGoalData) ...[
                    const _TrackerNoticeCard(
                      title: 'Set calculator goals first',
                      body:
                          'Use the nutrition calculator once, then this tracker will automatically use those calorie and protein goals here.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: _TrackerStatCard(
                          title: 'Calories',
                          value: '${_totalCalories.round()} kcal',
                          detail: goalCalories == null
                              ? 'Add calculator goal first'
                              : 'of ${goalCalories.round()} kcal goal',
                          icon: Icons.local_fire_department_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TrackerStatCard(
                          title: 'Water',
                          value: '${_totalWater.toStringAsFixed(1)} cups',
                          detail:
                              '${(_waterGoalCups - _totalWater).clamp(0, 99).toStringAsFixed(1)} cups left',
                          icon: Icons.water_drop_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _TrackerStatCard(
                    title: 'Protein',
                    value: '${_totalProtein.toStringAsFixed(1)} g',
                    detail: _proteinGoal <= 0
                        ? 'Goal will appear after calculator use'
                        : 'of ${_proteinGoal.toStringAsFixed(0)} g goal',
                    icon: Icons.egg_alt_outlined,
                    wide: true,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Meal plan',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF102A43),
                        ),
                      ),
                      if (_entries.isNotEmpty)
                        Text(
                          '${_entries.length} logged',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey[500],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 720,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111B29) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF24364A)
                            : const Color(0xFFE4EDF5),
                      ),
                    ),
                    child: MealPlannerScreen(
                      embed: true,
                      allowAdd: _hasGoalData,
                      onChanged: _loadTrackerData,
                    ),
                  ),
                ],
              ),
            ),
    );

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nutrition Tracker',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: content,
    );
  }
}

class _TrackerNoticeCard extends StatelessWidget {
  final String title;
  final String body;

  const _TrackerNoticeCard({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF162231) : const Color(0xFFEAF3FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2D425A) : const Color(0xFFBED7F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF102A43),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.blueGrey[700],
                height: 1.5,
              ),
            ),
          ],
        ),
      );
  }
}

class _TrackerStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final bool wide;

  const _TrackerStatCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162231) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF24364A) : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F2B47) : const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color.fromARGB(255, 22, 99, 167),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: wide ? 14 : 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.blueGrey[600],
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      fontSize: wide ? 24 : 22,
                    fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF102A43),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  maxLines: wide ? 1 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.blueGrey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _MealEntryCard extends StatelessWidget {
  final _MealEntry entry;
  final VoidCallback onDelete;

  const _MealEntryCard({
    required this.entry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162231) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF24364A) : const Color(0xFFE4EDF5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F2B47) : const Color(0xFFD9EAF9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              color: Color.fromARGB(255, 22, 99, 167),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.mealType,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF102A43),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                Text(
                  entry.title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color.fromARGB(255, 22, 99, 167),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.items,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.blueGrey[600],
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MealChip(label: '${entry.calories.round()} kcal'),
                    _MealChip(label: '${entry.protein.toStringAsFixed(1)} g protein'),
                    _MealChip(label: '${entry.waterCups.toStringAsFixed(1)} cups water'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MealChip extends StatelessWidget {
  final String label;

  const _MealChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF0F2B47)
              : const Color(0xFFEAF3FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color.fromARGB(255, 22, 99, 167),
          ),
        ),
      );
}

class _MealEntry {
  final String id;
  final String mealType;
  final String title;
  final String items;
  final double calories;
  final double protein;
  final double waterCups;
  final DateTime loggedAt;
  final int? dayIndex;

  const _MealEntry({
    required this.id,
    required this.mealType,
    required this.title,
    required this.items,
    required this.calories,
    required this.protein,
    required this.waterCups,
    required this.loggedAt,
    this.dayIndex,
  });

  // ignore: unused_element
  factory _MealEntry.fromJson(Map<String, dynamic> json) => _MealEntry(
        id: json['id']?.toString() ?? '',
        mealType: json['meal_type']?.toString() ?? 'Meal',
        title: json['title']?.toString() ?? '',
        items: json['items']?.toString() ?? '',
        calories: double.tryParse(json['calories']?.toString() ?? '') ?? 0,
        protein: double.tryParse(json['protein']?.toString() ?? '') ?? 0,
        waterCups: double.tryParse(json['water_cups']?.toString() ?? '') ?? 0,
        loggedAt: DateTime.tryParse(json['logged_at']?.toString() ?? '') ??
            DateTime.now(),
        dayIndex: int.tryParse(json['day_index']?.toString() ?? ''),
      );

  factory _MealEntry.fromMealPlanJson(Map<String, dynamic> json) => _MealEntry(
        id: json['id']?.toString() ?? '',
        mealType: _mealTypeFromDayIndex(
          int.tryParse(json['day_index']?.toString() ?? '') ?? 0,
        ),
        title: json['meal_name']?.toString() ?? 'Meal',
        items: json['foods_summary']?.toString() ?? '',
        calories: double.tryParse(json['calories']?.toString() ?? '') ?? 0,
        protein: double.tryParse(json['protein']?.toString() ?? '') ?? 0,
        waterCups: 0,
        loggedAt: DateTime.now(),
        dayIndex: int.tryParse(json['day_index']?.toString() ?? ''),
      );

  static String _mealTypeFromDayIndex(int dayIndex) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (dayIndex < 0 || dayIndex >= days.length) {
      return 'Meal';
    }
    return days[dayIndex];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'meal_type': mealType,
        'title': title,
        'items': items,
        'calories': calories,
        'protein': protein,
        'water_cups': waterCups,
        'logged_at': loggedAt.toIso8601String(),
        'day_index': dayIndex,
      };
}















