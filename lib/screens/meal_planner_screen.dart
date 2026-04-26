// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../providers/auth_provider.dart';
import '../services/nutrition_persistence_service.dart';

class MealPlannerScreen extends StatefulWidget {
  final bool embed;
  final bool allowAdd;
  final VoidCallback? onChanged;

  const MealPlannerScreen({
    super.key,
    this.embed = false,
    this.allowAdd = true,
    this.onChanged,
  });

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
  final _uuid = const Uuid();
  int _selectedDay = DateTime.now().weekday - 1; // 0 = Monday
  final List<String> _days = const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  final List<_MealPlanEntry> _entries = [];
  final NutritionPersistenceService _persistence =
      NutritionPersistenceService.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    final savedEntries = await _persistence.loadMealPlanEntries(userId);
    if (!mounted) return;
    setState(() {
      _entries
        ..clear()
        ..addAll(savedEntries.map(_MealPlanEntry.fromJson));
      _isLoading = false;
    });
    widget.onChanged?.call();
  }

  Future<void> _saveEntries() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    await _persistence.saveMealPlanEntries(
      userId,
      _entries.map((entry) => entry.toJson()).toList(),
    );
  }

  NutrientTotals _totalsForDay(int day) {
    final dayMeals = _entries.where((e) => e.dayIndex == day);
    return _sum(dayMeals);
  }

  NutrientTotals get _weekTotals => _sum(_entries);

  NutrientTotals _sum(Iterable<_MealPlanEntry> meals) {
    double calories = 0, protein = 0, carbs = 0, fat = 0;
    for (final m in meals) {
      calories += m.calories;
      protein += m.protein;
      carbs += m.carbs;
      fat += m.fat;
    }
    return NutrientTotals(calories, protein, carbs, fat);
  }

  void _showNeedCalculationMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Please calculate your nutrition goals first in the calculator.',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.red[600],
      ),
    );
  }

  Future<void> _addMealDialog() async {
    final nameController = TextEditingController();
    final foods = <_FoodInput>[
      _FoodInput(TextEditingController(), TextEditingController()),
    ];
    final manualCalories = TextEditingController();
    final manualProtein = TextEditingController();
    final manualCarbs = TextEditingController();
    final manualFat = TextEditingController();
    bool manualMode = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: Text(
            'Add Meal',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Meal name',
                    hintText: 'Breakfast / Post-workout',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Enter macros manually',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  value: manualMode,
                  onChanged: (v) => dialogSetState(() => manualMode = v),
                ),
                if (manualMode) ...[
                  const SizedBox(height: 8),
                  _numberField(manualCalories, 'Calories (kcal)'),
                  _numberField(manualProtein, 'Protein (g)'),
                  _numberField(manualCarbs, 'Carbs (g)'),
                  _numberField(manualFat, 'Fat (g)'),
                ] else ...[
                  Column(
                    children: [
                      for (int i = 0; i < foods.length; i++) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: foods[i].name,
                                decoration: const InputDecoration(
                                  labelText: 'Food name',
                                  hintText: 'Chicken breast, rice...',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 90,
                              child: TextField(
                                controller: foods[i].grams,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'g',
                                ),
                              ),
                            ),
                            if (foods.length > 1)
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    dialogSetState(() => foods.removeAt(i)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            if (foods.length >= 10) return;
                            dialogSetState(() => foods.add(_FoodInput(
                                  TextEditingController(),
                                  TextEditingController(),
                                )));
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add food'),
                        ),
                      ),
                    ],
                  ),
                ],
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
                final mealName = nameController.text.trim().isEmpty
                    ? 'Meal'
                    : nameController.text.trim();

                double calories = 0, protein = 0, carbs = 0, fat = 0;
                String foodsSummary = '';

                if (manualMode) {
                  calories =
                      double.tryParse(manualCalories.text.trim()) ?? 0.0;
                  protein = double.tryParse(manualProtein.text.trim()) ?? 0.0;
                  carbs = double.tryParse(manualCarbs.text.trim()) ?? 0.0;
                  fat = double.tryParse(manualFat.text.trim()) ?? 0.0;
                  foodsSummary = 'Manual entry';
                } else {
                  final validFoods = foods.where((f) =>
                      (double.tryParse(f.grams.text.trim()) ?? 0) > 0);
                  if (validFoods.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Add at least one food with grams.',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.red[600],
                      ),
                    );
                    return;
                  }

                  final summaries = <String>[];
                  for (final f in validFoods) {
                    final grams = double.tryParse(f.grams.text.trim()) ?? 0;
                    final name =
                        f.name.text.trim().isEmpty ? 'Food' : f.name.text.trim();
                    final n = _lookupNutrients(name, grams);
                    calories += n.calories;
                    protein += n.protein;
                    carbs += n.carbs;
                    fat += n.fat;
                    summaries.add('$name (${grams.toStringAsFixed(0)} g)');
                  }
                  foodsSummary = summaries.join(', ');
                }

                setState(() {
                  _entries.add(
                    _MealPlanEntry(
                      id: _uuid.v4(),
                      dayIndex: _selectedDay,
                      mealName: mealName,
                      foodsSummary: foodsSummary,
                      calories: calories,
                      protein: protein,
                      carbs: carbs,
                      fat: fat,
                    ),
                  );
                });
                await _saveEntries();
                widget.onChanged?.call();
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  static final List<_FoodKeywordProfile> _foodProfiles = [
    _FoodKeywordProfile(keywords: ['chicken', 'chicken breast', 'grilled chicken', 'chicken thigh'], nutrients: NutrientTotals(165, 31, 0, 3.6)),
    _FoodKeywordProfile(keywords: ['rice', 'white rice', 'brown rice', 'basmati', 'jasmine rice'], nutrients: NutrientTotals(130, 2.7, 28, 0.3)),
    _FoodKeywordProfile(keywords: ['egg', 'eggs', 'boiled egg', 'omelette'], nutrients: NutrientTotals(143, 13, 1.1, 10)),
    _FoodKeywordProfile(keywords: ['milk', 'whole milk', 'low fat milk'], nutrients: NutrientTotals(61, 3.2, 4.8, 3.3)),
    _FoodKeywordProfile(keywords: ['lentil', 'lentils', 'dal', 'dahl'], nutrients: NutrientTotals(116, 9, 20, 0.4)),
    _FoodKeywordProfile(keywords: ['tofu', 'soy paneer'], nutrients: NutrientTotals(76, 8, 1.9, 4.8)),
    _FoodKeywordProfile(keywords: ['banana', 'bananas'], nutrients: NutrientTotals(89, 1.1, 23, 0.3)),
    _FoodKeywordProfile(keywords: ['apple', 'apples'], nutrients: NutrientTotals(52, 0.3, 14, 0.2)),
    _FoodKeywordProfile(keywords: ['oat', 'oats', 'oatmeal', 'porridge'], nutrients: NutrientTotals(389, 16.9, 66.3, 6.9)),
    _FoodKeywordProfile(keywords: ['peanut', 'peanuts', 'peanut butter'], nutrients: NutrientTotals(588, 25, 20, 50)),
    _FoodKeywordProfile(keywords: ['oil', 'olive oil', 'sunflower oil', 'vegetable oil'], nutrients: NutrientTotals(884, 0, 0, 100)),
    _FoodKeywordProfile(keywords: ['fish', 'salmon', 'tuna', 'sardine'], nutrients: NutrientTotals(208, 20, 0, 13)),
    _FoodKeywordProfile(keywords: ['beef', 'steak', 'ground beef'], nutrients: NutrientTotals(250, 26, 0, 15)),
    _FoodKeywordProfile(keywords: ['mutton', 'lamb'], nutrients: NutrientTotals(294, 25, 0, 21)),
    _FoodKeywordProfile(keywords: ['paneer', 'cottage cheese'], nutrients: NutrientTotals(265, 18, 1.2, 20)),
    _FoodKeywordProfile(keywords: ['yogurt', 'curd', 'greek yogurt'], nutrients: NutrientTotals(97, 9, 3.6, 4)),
    _FoodKeywordProfile(keywords: ['bread', 'toast', 'roti', 'chapati'], nutrients: NutrientTotals(265, 9, 49, 3.2)),
    _FoodKeywordProfile(keywords: ['pasta', 'noodles', 'spaghetti'], nutrients: NutrientTotals(131, 5, 25, 1.1)),
    _FoodKeywordProfile(keywords: ['potato', 'potatoes', 'fries'], nutrients: NutrientTotals(77, 2, 17, 0.1)),
    _FoodKeywordProfile(keywords: ['sweet potato'], nutrients: NutrientTotals(86, 1.6, 20, 0.1)),
    _FoodKeywordProfile(keywords: ['beans', 'kidney beans', 'black beans', 'chickpeas'], nutrients: NutrientTotals(164, 9, 27, 2.6)),
    _FoodKeywordProfile(keywords: ['cheese', 'cheddar', 'mozzarella'], nutrients: NutrientTotals(402, 25, 1.3, 33)),
    _FoodKeywordProfile(keywords: ['avocado'], nutrients: NutrientTotals(160, 2, 9, 15)),
    _FoodKeywordProfile(keywords: ['broccoli'], nutrients: NutrientTotals(35, 2.4, 7.2, 0.4)),
    _FoodKeywordProfile(keywords: ['spinach'], nutrients: NutrientTotals(23, 2.9, 3.6, 0.4)),
    _FoodKeywordProfile(keywords: ['carrot', 'carrots'], nutrients: NutrientTotals(41, 0.9, 10, 0.2)),
    _FoodKeywordProfile(keywords: ['beansprout', 'bean sprout', 'vegetable salad', 'salad'], nutrients: NutrientTotals(33, 2, 6, 0.4)),
    _FoodKeywordProfile(keywords: ['burger', 'hamburger'], nutrients: NutrientTotals(295, 17, 30, 13)),
    _FoodKeywordProfile(keywords: ['pizza'], nutrients: NutrientTotals(266, 11, 33, 10)),
    _FoodKeywordProfile(keywords: ['biryani', 'fried rice'], nutrients: NutrientTotals(180, 5, 25, 6)),
  ];

  NutrientTotals _lookupNutrients(String foodName, double grams) {
    final normalized = foodName.toLowerCase().trim();
    final matched = _foodProfiles.firstWhere(
      (profile) => profile.matches(normalized),
      orElse: () => const _FoodKeywordProfile(keywords: ['fallback'], nutrients: NutrientTotals(100, 5, 15, 3)),
    );
    final per100 = matched.nutrients;
    final factor = grams / 100.0;
    return NutrientTotals(
      per100.calories * factor,
      per100.protein * factor,
      per100.carbs * factor,
      per100.fat * factor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dayMeals =
        _entries.where((e) => e.dayIndex == _selectedDay).toList(growable: false);
    final dayTotals = _totalsForDay(_selectedDay);

    final plannerBody = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan your meals for the week. Add up to 10 meals (or more) per day and see macros instantly.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.blueGrey[700],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.swipe, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Text(
                    'Swipe to see other days',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.blueGrey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_days.length, (index) {
                final selected = _selectedDay == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      _days[index],
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.blueGrey[700]),
                      ),
                    ),
                    selected: selected,
                    selectedColor: const Color.fromARGB(255, 22, 99, 167),
                    backgroundColor:
                        isDark ? const Color(0xFF162231) : Colors.grey[200],
                    onSelected: (_) => setState(() => _selectedDay = index),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          _TotalsBar(
            title: '${_days[_selectedDay]} totals',
            totals: dayTotals,
          ),
          const SizedBox(height: 8),
          _TotalsBar(
            title: 'Week totals',
            totals: _weekTotals,
            accent: Colors.teal,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: dayMeals.isEmpty
                ? Center(
                    child: Text(
                      'No meals yet. Tap “Add Meal”.',
                      style: GoogleFonts.poppins(
                        color: isDark ? Colors.white70 : Colors.blueGrey[500],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: dayMeals.length,
                    itemBuilder: (context, index) {
                      final meal = dayMeals[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      meal.mealName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF102A43),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      setState(() {
                                        _entries.removeWhere((m) => m.id == meal.id);
                                      });
                                      await _saveEntries();
                                      widget.onChanged?.call();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                meal.foodsSummary,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.blueGrey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 6,
                                children: [
                                  _chip('Cal', meal.calories),
                                  _chip('Protein', meal.protein, suffix: 'g'),
                                  _chip('Carbs', meal.carbs, suffix: 'g'),
                                  _chip('Fat', meal.fat, suffix: 'g'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    if (widget.embed) {
      return Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed:
                      widget.allowAdd ? _addMealDialog : _showNeedCalculationMessage,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Meal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 22, 99, 167),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color.fromARGB(255, 120, 154, 189),
                    disabledForegroundColor: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: plannerBody),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Meal Planner',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMealDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Meal'),
      ),
      body: plannerBody,
    );
  }

  Widget _chip(String label, double value, {String suffix = 'kcal'}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBDD5F1)),
      ),
      child: Text(
        '$label: ${value.toStringAsFixed(1)}$suffix',
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color.fromARGB(255, 22, 99, 167),
        ),
      ),
    );
  }
}

class _TotalsBar extends StatelessWidget {
  final String title;
  final NutrientTotals totals;
  final Color accent;

  const _TotalsBar({
    required this.title,
    required this.totals,
    this.accent = const Color.fromARGB(255, 22, 99, 167),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
          _miniStat('Cal', totals.calories),
          _miniStat('P', totals.protein, suffix: 'g'),
          _miniStat('C', totals.carbs, suffix: 'g'),
          _miniStat('F', totals.fat, suffix: 'g'),
        ],
      ),
    );
  }

  Widget _miniStat(String label, double value, {String suffix = 'kcal'}) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Text(
        '$label ${value.toStringAsFixed(0)}$suffix',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          color: accent,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MealPlanEntry {
  final String id;
  final int dayIndex;
  final String mealName;
  final String foodsSummary;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  _MealPlanEntry({
    required this.id,
    required this.dayIndex,
    required this.mealName,
    required this.foodsSummary,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory _MealPlanEntry.fromJson(Map<String, dynamic> json) => _MealPlanEntry(
        id: json['id']?.toString() ?? '',
        dayIndex: int.tryParse(json['day_index']?.toString() ?? '') ?? 0,
        mealName: json['meal_name']?.toString() ?? 'Meal',
        foodsSummary: json['foods_summary']?.toString() ?? '',
        calories: double.tryParse(json['calories']?.toString() ?? '') ?? 0,
        protein: double.tryParse(json['protein']?.toString() ?? '') ?? 0,
        carbs: double.tryParse(json['carbs']?.toString() ?? '') ?? 0,
        fat: double.tryParse(json['fat']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'day_index': dayIndex,
        'meal_name': mealName,
        'foods_summary': foodsSummary,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };
}

class _FoodKeywordProfile {
  final List<String> keywords;
  final NutrientTotals nutrients;

  const _FoodKeywordProfile({
    required this.keywords,
    required this.nutrients,
  });

  bool matches(String input) =>
      keywords.any((keyword) => input.contains(keyword));
}

class _FoodInput {
  final TextEditingController name;
  final TextEditingController grams;

  _FoodInput(this.name, this.grams);
}

class NutrientTotals {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const NutrientTotals(
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
  );
}








