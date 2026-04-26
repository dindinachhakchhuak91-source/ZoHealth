import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/nutrition_persistence_service.dart';
import '../services/nutrition_service.dart';
import 'food_detail_screen.dart';

class NutritionCalculatorScreen extends StatefulWidget {
  final bool showAppBar;

  const NutritionCalculatorScreen({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<NutritionCalculatorScreen> createState() =>
      _NutritionCalculatorScreenState();
}

class _NutritionCalculatorScreenState extends State<NutritionCalculatorScreen> {
  static const _modeKey = 'nutrition_calc_mode';
  static const _sexKey = 'nutrition_calc_sex';
  static const _activityKey = 'nutrition_calc_activity';
  static const _usePoundsKey = 'nutrition_calc_use_pounds';
  static const _useFeetKey = 'nutrition_calc_use_feet';
  static const _ageKey = 'nutrition_calc_age';
  static const _weightKey = 'nutrition_calc_weight';
  static const _heightKey = 'nutrition_calc_height';
  static const _heightInchesKey = 'nutrition_calc_height_inches';
  static const _goalCaloriesKey = 'nutrition_calc_goal_calories';
  static const _goalProteinKey = 'nutrition_calc_goal_protein';
  static const _goalWaterKey = 'nutrition_calc_goal_water';

  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _resultSectionKey = GlobalKey();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _heightInchesController = TextEditingController();
  final _nutritionService = const NutritionService();
  final _persistence = NutritionPersistenceService.instance;

  LifeStageMode _mode = LifeStageMode.child;
  BiologicalSex _sex = BiologicalSex.female;
  ActivityLevel _activityLevel = ActivityLevel.moderate;
  bool _usePounds = false;
  bool _useFeet = false;
  NutritionResult? _result;
  String? _error;
  bool _isRestoringState = false;
  String? _lastLoadedUserId;

  @override
  void initState() {
    super.initState();
    _ageController.addListener(_saveCalculatorState);
    _weightController.addListener(_saveCalculatorState);
    _heightController.addListener(_saveCalculatorState);
    _heightInchesController.addListener(_saveCalculatorState);
    _loadSavedCalculatorState();
  }

  @override
  void dispose() {
    _ageController.removeListener(_saveCalculatorState);
    _weightController.removeListener(_saveCalculatorState);
    _heightController.removeListener(_saveCalculatorState);
    _heightInchesController.removeListener(_saveCalculatorState);
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _heightInchesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (_lastLoadedUserId != userId) {
      _loadSavedCalculatorState();
    }
  }

  Future<void> _loadSavedCalculatorState() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    _lastLoadedUserId = userId;
    final state = await _persistence.loadCalculatorState(userId);
    if (!mounted || state == null) return;

    _isRestoringState = true;
    setState(() {
      _mode = LifeStageMode.values[
          (state[_modeKey] as int?)?.clamp(0, LifeStageMode.values.length - 1) ?? 0];
      _sex = BiologicalSex.values[
          (state[_sexKey] as int?)?.clamp(0, BiologicalSex.values.length - 1) ?? 1];
      _activityLevel = ActivityLevel.values[
          (state[_activityKey] as int?)?.clamp(0, ActivityLevel.values.length - 1) ?? 1];
      _usePounds = state[_usePoundsKey] == true;
      _useFeet = state[_useFeetKey] == true;
      _result = _resultFromJson(state['result']);
      _error = state['error']?.toString();
      _ageController.text = state[_ageKey]?.toString() ?? '';
      _weightController.text = state[_weightKey]?.toString() ?? '';
      _heightController.text = state[_heightKey]?.toString() ?? '';
      _heightInchesController.text = state[_heightInchesKey]?.toString() ?? '';
    });
    _isRestoringState = false;
  }

  Future<void> _saveCalculatorState() async {
    if (_isRestoringState) return;

    final userId = context.read<AuthProvider>().currentUser?.id;
    await _persistence.saveCalculatorState(userId, {
      _modeKey: _mode.index,
      _sexKey: _sex.index,
      _activityKey: _activityLevel.index,
      _usePoundsKey: _usePounds,
      _useFeetKey: _useFeet,
      _ageKey: _ageController.text.trim(),
      _weightKey: _weightController.text.trim(),
      _heightKey: _heightController.text.trim(),
      _heightInchesKey: _heightInchesController.text.trim(),
      _goalCaloriesKey: _result == null ? null : (_result!.healthyCalories ?? _result!.calories),
      _goalProteinKey: _extractNumericTarget('Protein'),
      _goalWaterKey: _extractNumericTarget('Water'),
      'result': _result == null ? null : _resultToJson(_result!),
      'error': _error,
    });
  }

  double _extractNumericTarget(String label) {
    final target = _result?.nutrients.where((nutrient) => nutrient.label == label).firstOrNull;
    final source = target?.adjustedAmount ?? target?.amount ?? '';
    final match = RegExp(r'[\d.]+').firstMatch(source);
    return double.tryParse(match?.group(0) ?? '') ?? 0;
  }

  Map<String, dynamic> _resultToJson(NutritionResult result) => {
        'calories': result.calories,
        'healthyCalories': result.healthyCalories,
        'bmi': result.bmi,
        'bmiLabel': result.bmiLabel,
        'calorieDetail': result.calorieDetail,
        'healthyCaloriesDetail': result.healthyCaloriesDetail,
        'note': result.note,
        'nutrients': result.nutrients
            .map(
              (nutrient) => {
                'label': nutrient.label,
                'amount': nutrient.amount,
                'adjustedAmount': nutrient.adjustedAmount,
                'detail': nutrient.detail,
                'foods': nutrient.foods,
              },
            )
            .toList(),
      };

  NutritionResult? _resultFromJson(dynamic json) {
    if (json is! Map) return null;
    final data = Map<String, dynamic>.from(json);
    final nutrientsRaw = data['nutrients'];
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
                    ? (item['foods'] as List).map((food) => food.toString()).toList()
                    : const [],
              ),
            )
            .toList()
        : const <NutrientTarget>[];

    return NutritionResult(
      calories: int.tryParse(data['calories']?.toString() ?? '') ?? 0,
      healthyCalories: data['healthyCalories'] == null
          ? null
          : int.tryParse(data['healthyCalories'].toString()),
      bmi: double.tryParse(data['bmi']?.toString() ?? '') ?? 0,
      bmiLabel: data['bmiLabel']?.toString() ?? '',
      calorieDetail: data['calorieDetail']?.toString() ?? '',
      healthyCaloriesDetail: data['healthyCaloriesDetail']?.toString(),
      note: data['note']?.toString() ?? '',
      nutrients: nutrients,
    );
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final result = _nutritionService.calculate(
        NutritionInput(
          mode: _mode,
          sex: _sex,
          activityLevel: _activityLevel,
          age: int.parse(_ageController.text.trim()),
          weightKg: _weightInKg(),
          heightCm: _heightInCm(),
        ),
      );

      setState(() {
        _result = result;
        _error = null;
      });
      _saveCalculatorState();
      _scrollToResult();
    } catch (e) {
      setState(() {
        _result = null;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      _saveCalculatorState();
    }
  }

  void _scrollToResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _resultSectionKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        alignment: 0.05,
      );
    });
  }

  String _modeLabel(LifeStageMode mode) {
    switch (mode) {
      case LifeStageMode.child:
        return 'Child';
      case LifeStageMode.teen:
        return 'Teen';
      case LifeStageMode.adult:
        return 'Adult';
    }
  }

  String _sexLabel(BiologicalSex sex) {
    switch (sex) {
      case BiologicalSex.male:
        return 'Male';
      case BiologicalSex.female:
        return 'Female';
    }
  }

  String _activityLabel(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.low:
        return 'Low';
      case ActivityLevel.moderate:
        return 'Moderate';
      case ActivityLevel.high:
        return 'High';
    }
  }

  double _weightInKg() {
    final weight = double.parse(_weightController.text.trim());
    return _usePounds ? weight * 0.45359237 : weight;
  }

  double _heightInCm() {
    if (_useFeet) {
      final feet = double.parse(_heightController.text.trim());
      final inches = double.tryParse(_heightInchesController.text.trim()) ?? 0;
      return ((feet * 12) + inches) * 2.54;
    }
    return double.parse(_heightController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isNarrow = MediaQuery.of(context).size.width < 420;
    final isWideForm = MediaQuery.of(context).size.width >= 900;

    final content = SafeArea(
      top: !widget.showAppBar,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.showAppBar)
                Text(
                  'Nutrition Calculator',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              if (!widget.showAppBar) const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF124E8C), Color(0xFF3F78B5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Nutrition Needs',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter age, weight, height, sex, and activity level to get an evidence-based estimate.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(title: 'Life Stage'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: LifeStageMode.values.map((mode) {
                        final selected = mode == _mode;
                        return ChoiceChip(
                          label: Text(_modeLabel(mode)),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _mode = mode;
                              _result = null;
                              _error = null;
                            });
                            _saveCalculatorState();
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const _SectionTitle(title: 'Sex'),
                    Wrap(
                      spacing: 8,
                      children: BiologicalSex.values.map((sex) {
                        return ChoiceChip(
                          label: Text(_sexLabel(sex)),
                          selected: sex == _sex,
                          onSelected: (_) {
                            setState(() {
                              _sex = sex;
                              _result = null;
                            });
                            _saveCalculatorState();
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    if (isWideForm)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionTitle(title: 'Activity Level'),
                                DropdownButtonFormField<ActivityLevel>(
                                  initialValue: _activityLevel,
                                  decoration:
                                      _inputDecoration('Choose activity level'),
                                  items: ActivityLevel.values
                                      .map(
                                        (level) => DropdownMenuItem(
                                          value: level,
                                          child: Text(_activityLabel(level)),
                                        ),
                                      )
                                      .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _activityLevel = value);
                                  _saveCalculatorState();
                                },
                              ),
                            ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionTitle(title: 'Age'),
                                TextFormField(
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration('Age (years)'),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Required';
                                    }
                                    final age = int.tryParse(value.trim());
                                    if (age == null) return 'Invalid age';
                                    if (age < 2 || age > 80) return 'Use 2-80';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      const _SectionTitle(title: 'Activity Level'),
                      DropdownButtonFormField<ActivityLevel>(
                        initialValue: _activityLevel,
                        decoration: _inputDecoration('Choose activity level'),
                        items: ActivityLevel.values
                            .map(
                              (level) => DropdownMenuItem(
                                value: level,
                                child: Text(_activityLabel(level)),
                              ),
                            )
                            .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _activityLevel = value);
                        _saveCalculatorState();
                      },
                    ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Age (years)'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          final age = int.tryParse(value.trim());
                          if (age == null) return 'Invalid age';
                          if (age < 2 || age > 80) return 'Use 2-80';
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (isWideForm)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _UnitSelector(
                                  title: 'Weight Unit',
                                  leftLabel: 'kg',
                                  rightLabel: 'lb',
                                  rightSelected: _usePounds,
                                onChanged: (value) {
                                  setState(() {
                                    _usePounds = value;
                                    _result = null;
                                  });
                                  _saveCalculatorState();
                                },
                              ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _weightController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: _inputDecoration(
                                    _usePounds ? 'Weight (lb)' : 'Weight (kg)',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Required';
                                    }
                                    final weight =
                                        double.tryParse(value.trim());
                                    if (weight == null || weight <= 0) {
                                      return 'Invalid';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _UnitSelector(
                                  title: 'Height Unit',
                                  leftLabel: 'cm',
                                  rightLabel: 'ft/in',
                                  rightSelected: _useFeet,
                                onChanged: (value) {
                                  setState(() {
                                    _useFeet = value;
                                    _result = null;
                                  });
                                  _saveCalculatorState();
                                },
                              ),
                                const SizedBox(height: 12),
                                if (_useFeet)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _heightController,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(
                                            decimal: true,
                                          ),
                                          decoration:
                                              _inputDecoration('Height (ft)'),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Required';
                                            }
                                            final feet =
                                                double.tryParse(value.trim());
                                            if (feet == null || feet <= 0) {
                                              return 'Invalid';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _heightInchesController,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(
                                            decimal: true,
                                          ),
                                          decoration:
                                              _inputDecoration('Inches'),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return null;
                                            }
                                            final inches =
                                                double.tryParse(value.trim());
                                            if (inches == null || inches < 0) {
                                              return 'Invalid';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  TextFormField(
                                    controller: _heightController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: _inputDecoration('Height (cm)'),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Required';
                                      }
                                      final height =
                                          double.tryParse(value.trim());
                                      if (height == null || height <= 0) {
                                        return 'Invalid';
                                      }
                                      return null;
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _UnitSelector(
                        title: 'Weight Unit',
                        leftLabel: 'kg',
                        rightLabel: 'lb',
                        rightSelected: _usePounds,
                      onChanged: (value) {
                        setState(() {
                          _usePounds = value;
                          _result = null;
                        });
                        _saveCalculatorState();
                      },
                    ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration(
                          _usePounds ? 'Weight (lb)' : 'Weight (kg)',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          final weight = double.tryParse(value.trim());
                          if (weight == null || weight <= 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _UnitSelector(
                        title: 'Height Unit',
                        leftLabel: 'cm',
                        rightLabel: 'ft/in',
                        rightSelected: _useFeet,
                      onChanged: (value) {
                        setState(() {
                          _useFeet = value;
                          _result = null;
                        });
                        _saveCalculatorState();
                      },
                    ),
                      const SizedBox(height: 12),
                      if (_useFeet)
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _heightController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: _inputDecoration('Height (ft)'),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  final feet = double.tryParse(value.trim());
                                  if (feet == null || feet <= 0) {
                                    return 'Invalid';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _heightInchesController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: _inputDecoration('Additional in'),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return null;
                                  }
                                  final inches = double.tryParse(value.trim());
                                  if (inches == null || inches < 0) {
                                    return 'Invalid';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        )
                      else
                        TextFormField(
                          controller: _heightController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _inputDecoration('Height (cm)'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            final height = double.tryParse(value.trim());
                            if (height == null || height <= 0) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _calculate,
                        icon: const Icon(Icons.calculate_outlined),
                        label: const Text('Calculate Daily Needs'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF124E8C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                _MessageCard(
                  color: Colors.red,
                  title: 'Check your inputs',
                  body: _error!,
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 24),
                KeyedSubtree(
                  key: _resultSectionKey,
                  child: _ResultHero(result: _result!),
                ),
                const SizedBox(height: 16),
                _MessageCard(
                  color: Colors.blueGrey,
                  title: 'How to read this',
                  body: _result!.calorieDetail,
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _result!.nutrients.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isNarrow ? 1 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: isNarrow ? 1.15 : 2.1,
                  ),
                  itemBuilder: (context, index) {
                    final target = _result!.nutrients[index];
                    return _NutrientCard(target: target);
                  },
                ),
                const SizedBox(height: 16),
                _MessageCard(
                  color: const Color(0xFF124E8C),
                  title: 'Important note',
                  body: _result!.note,
                ),
                const SizedBox(height: 16),
                _SourcesCard(sources: _nutritionService.sources()),
              ],
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
          'Nutrition Calculator',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: content,
    );
  }

  InputDecoration _inputDecoration(String hint) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[500]),
      filled: true,
      fillColor: isDark ? theme.cardColor : Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2A3A4E) : Colors.grey[300]!,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2A3A4E) : Colors.grey[300]!,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF124E8C), width: 1.4),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _UnitSelector extends StatelessWidget {
  final String title;
  final String leftLabel;
  final String rightLabel;
  final bool rightSelected;
  final ValueChanged<bool> onChanged;

  const _UnitSelector({
    required this.title,
    required this.leftLabel,
    required this.rightLabel,
    required this.rightSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).cardColor
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A3A4E)
                : Colors.grey[200]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(value: false, label: Text(leftLabel)),
                ButtonSegment<bool>(value: true, label: Text(rightLabel)),
              ],
              selected: {rightSelected},
              onSelectionChanged: (selection) => onChanged(selection.first),
            ),
          ],
        ),
      );
}

class _ResultHero extends StatelessWidget {
  final NutritionResult result;

  const _ResultHero({required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF162231) : const Color(0xFFF2F7FC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2D425A) : const Color(0xFFB8D2EA),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                _CalorieBlock(
                  label: 'Estimated Daily Calories',
                  value: '${result.calories} kcal',
                ),
                if (result.healthyCalories != null)
                  _CalorieBlock(
                    label: 'Healthy-Weight Calorie Goal',
                    value: '${result.healthyCalories} kcal',
                    accent: const Color(0xFF1565C0),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'BMI: ${result.bmi.toStringAsFixed(1)}',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              result.bmiLabel,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.grey[700],
                height: 1.4,
              ),
            ),
            if (result.healthyCaloriesDetail != null) ...[
              const SizedBox(height: 10),
              Text(
                result.healthyCaloriesDetail!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.grey[800],
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      );
  }
}

class _CalorieBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _CalorieBlock({
    required this.label,
    required this.value,
    this.accent = const Color(0xFF124E8C),
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      );
}

class _NutrientCard extends StatelessWidget {
  final NutrientTarget target;

  const _NutrientCard({required this.target});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF162231) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2A3A4E) : Colors.grey[200]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              target.label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              target.amount,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF124E8C),
              ),
            ),
            if (target.adjustedAmount != null) ...[
              const SizedBox(height: 4),
              Text(
                'Healthy-calorie plan: ${target.adjustedAmount}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1565C0),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              target.detail,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: isDark ? Colors.white70 : Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Best foods',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: target.foods
                  .map(
                    (food) => InkWell(
                        borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => FoodDetailScreen(
                              foodName: food,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F2B47)
                              : const Color(0xFFEAF3FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          food,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1565C0),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      );
  }
}

class _MessageCard extends StatelessWidget {
  final Color color;
  final String title;
  final String body;

  const _MessageCard({
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? color.withValues(alpha: 0.18)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? color.withValues(alpha: 0.38)
                : color.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.grey[800],
                height: 1.5,
              ),
            ),
          ],
        ),
      );
  }
}

class _SourcesCard extends StatelessWidget {
  final List<Map<String, String>> sources;

  const _SourcesCard({required this.sources});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF162231) : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF2A3A4E) : Colors.grey[200]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sources Used',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 10),
            ...sources.map(
              (source) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${source['title']}\n${source['url']}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.grey[800],
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }
}



