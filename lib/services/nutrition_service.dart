enum LifeStageMode { child, teen, adult }

enum BiologicalSex { male, female }

enum ActivityLevel { low, moderate, high }

class NutritionInput {
  final LifeStageMode mode;
  final BiologicalSex sex;
  final ActivityLevel activityLevel;
  final int age;
  final double weightKg;
  final double heightCm;

  const NutritionInput({
    required this.mode,
    required this.sex,
    required this.activityLevel,
    required this.age,
    required this.weightKg,
    required this.heightCm,
  });
}

class NutrientTarget {
  final String label;
  final String amount;
  final String? adjustedAmount;
  final String detail;
  final List<String> foods;

  const NutrientTarget({
    required this.label,
    required this.amount,
    this.adjustedAmount,
    required this.detail,
    required this.foods,
  });
}

class NutritionResult {
  final int calories;
  final int? healthyCalories;
  final double bmi;
  final String bmiLabel;
  final String calorieDetail;
  final String? healthyCaloriesDetail;
  final String note;
  final List<NutrientTarget> nutrients;

  const NutritionResult({
    required this.calories,
    this.healthyCalories,
    required this.bmi,
    required this.bmiLabel,
    required this.calorieDetail,
    this.healthyCaloriesDetail,
    required this.note,
    required this.nutrients,
  });
}

class NutritionService {
  const NutritionService();

  NutritionResult calculate(NutritionInput input) {
    _validateInput(input);

    final bmr = _schofieldBmr(input);
    final calories = (bmr * _activityMultiplier(input.activityLevel)).round();
    final bmi = input.weightKg / _metersSquared(input.heightCm);
    final healthyCalories = _healthyWeightCalories(input);
    final calorieRatio =
        healthyCalories == null ? 1.0 : healthyCalories / calories;

    return NutritionResult(
      calories: calories,
      healthyCalories: healthyCalories,
      bmi: bmi,
      bmiLabel: _bmiLabel(input, bmi),
      calorieDetail:
          'Estimated from WHO/FAO/UNU Schofield resting-energy equations plus an activity multiplier.',
      healthyCaloriesDetail:
          _healthyCaloriesDetail(input, bmi, healthyCalories),
      note:
          'These are general estimates for healthy people and should not replace advice from a doctor or dietitian, especially for pregnancy, kidney disease, anemia, eating disorders, or growth concerns.',
      nutrients: [
        NutrientTarget(
          label: 'Protein',
          amount: '${_proteinGrams(input)} g/day',
          adjustedAmount: healthyCalories == null
              ? null
              : '${_scaledValue(_proteinGrams(input).toDouble(), calorieRatio)} g/day',
          detail: 'RDA-style target based on age and sex.',
          foods: const [
            'Eggs',
            'Chicken',
            'Lentils',
            'Greek yogurt',
            'Tofu',
          ],
        ),
        NutrientTarget(
          label: 'Iron',
          amount: '${_ironMg(input)} mg/day',
          adjustedAmount: healthyCalories == null
              ? null
              : '${_scaledValue(_ironMg(input).toDouble(), calorieRatio)} mg/day',
          detail: 'Needs are higher for many teen and adult females.',
          foods: const [
            'Lean beef',
            'Spinach',
            'Lentils',
            'Beans',
            'Fortified cereal',
          ],
        ),
        NutrientTarget(
          label: 'Calcium',
          amount: '${_calciumMg(input)} mg/day',
          adjustedAmount: healthyCalories == null
              ? null
              : '${_scaledValue(_calciumMg(input).toDouble(), calorieRatio)} mg/day',
          detail: 'Supports bone growth and maintenance.',
          foods: const [
            'Milk',
            'Yogurt',
            'Cheese',
            'Tofu',
            'Sardines',
          ],
        ),
        NutrientTarget(
          label: 'Potassium',
          amount: '${_potassiumMg(input)} mg/day',
          adjustedAmount: healthyCalories == null
              ? null
              : '${_scaledValue(_potassiumMg(input).toDouble(), calorieRatio)} mg/day',
          detail: 'Food-first target; kidney disease can change safe intake.',
          foods: const [
            'Bananas',
            'Potatoes',
            'Beans',
            'Yogurt',
            'Tomatoes',
          ],
        ),
        NutrientTarget(
          label: 'Vitamin A',
          amount: '${_vitaminAMcg(input)} mcg RAE/day',
          adjustedAmount: healthyCalories == null
              ? null
              : '${_scaledValue(_vitaminAMcg(input).toDouble(), calorieRatio)} mcg/day',
          detail: 'Important for vision, immunity, and growth.',
          foods: const [
            'Sweet potato',
            'Carrots',
            'Spinach',
            'Eggs',
            'Fortified milk',
          ],
        ),
        NutrientTarget(
          label: 'Vitamin C',
          amount: '${_vitaminCMg(input)} mg/day',
          adjustedAmount: healthyCalories == null
              ? null
              : '${_scaledValue(_vitaminCMg(input).toDouble(), calorieRatio)} mg/day',
          detail: 'Supports collagen formation and iron absorption.',
          foods: const [
            'Guava',
            'Oranges',
            'Strawberries',
            'Bell peppers',
            'Broccoli',
          ],
        ),
        NutrientTarget(
          label: 'Vitamin D',
          amount:
              '${_vitaminDMcg(input)} mcg/day (${_vitaminDMcg(input) * 40} IU)',
          adjustedAmount: healthyCalories == null
              ? null
              : '${_scaledValue(_vitaminDMcg(input).toDouble(), calorieRatio)} mcg/day',
          detail: 'Important for calcium absorption and bone health.',
          foods: const [
            'Salmon',
            'Sardines',
            'Egg yolks',
            'Fortified milk',
            'Fortified cereal',
          ],
        ),
        NutrientTarget(
          label: 'Water',
          amount: '${_waterCups(input)} cups/day',
          adjustedAmount: null,
          detail:
              'Daily fluid goal based on age and sex as a general hydration target.',
          foods: const [
            'Water',
            'Watermelon',
            'Cucumber',
            'Oranges',
            'Lettuce',
            'Coconut water',
          ],
        ),
      ],
    );
  }

  List<Map<String, String>> sources() => const [
        {
          'title': 'WHO/FAO/UNU Human Energy Requirements',
          'url': 'https://www.fao.org/4/y5686e/y5686e00.htm',
        },
        {
          'title': 'NIH ODS Calcium Fact Sheet',
          'url': 'https://ods.od.nih.gov/factsheets/Calcium-Consumer/',
        },
        {
          'title': 'NIH ODS Iron Fact Sheet',
          'url': 'https://ods.od.nih.gov/factsheets/Iron-Consumer/',
        },
        {
          'title': 'NIH ODS Potassium Fact Sheet',
          'url': 'https://ods.od.nih.gov/factsheets/Potassium-Consumer/',
        },
        {
          'title': 'NIH ODS Vitamin A Fact Sheet',
          'url': 'https://ods.od.nih.gov/factsheets/VitaminA-Consumer/',
        },
        {
          'title': 'NIH ODS Vitamin C Fact Sheet',
          'url': 'https://ods.od.nih.gov/factsheets/VitaminC-Consumer/',
        },
        {
          'title': 'NIH ODS Vitamin D Fact Sheet',
          'url': 'https://ods.od.nih.gov/factsheets/VitaminD-Consumer/',
        },
      ];

  void _validateInput(NutritionInput input) {
    if (input.age < 2 || input.age > 80) {
      throw Exception('Please enter an age between 2 and 80 years.');
    }
    if (input.weightKg <= 0 || input.heightCm <= 0) {
      throw Exception('Weight and height must be greater than zero.');
    }

    if (input.mode == LifeStageMode.child && input.age > 9) {
      throw Exception('Child mode is designed for ages 2 to 9.');
    }
    if (input.mode == LifeStageMode.teen &&
        (input.age < 10 || input.age > 18)) {
      throw Exception('Teen mode is designed for ages 10 to 18.');
    }
    if (input.mode == LifeStageMode.adult && input.age < 19) {
      throw Exception('Adult mode is designed for ages 19 and above.');
    }
  }

  double _schofieldBmr(NutritionInput input) {
    final weight = input.weightKg;
    final male = input.sex == BiologicalSex.male;

    if (input.age < 10) {
      return male ? (22.7 * weight) + 495 : (22.5 * weight) + 499;
    }
    if (input.age <= 18) {
      return male ? (17.5 * weight) + 651 : (12.2 * weight) + 746;
    }
    if (input.age <= 30) {
      return male ? (15.3 * weight) + 679 : (14.7 * weight) + 496;
    }
    if (input.age <= 60) {
      return male ? (11.6 * weight) + 879 : (8.7 * weight) + 829;
    }
    return male ? (13.5 * weight) + 487 : (10.5 * weight) + 596;
  }

  double _activityMultiplier(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.low:
        return 1.55;
      case ActivityLevel.moderate:
        return 1.75;
      case ActivityLevel.high:
        return 1.95;
    }
  }

  double _metersSquared(double heightCm) {
    final meters = heightCm / 100;
    return meters * meters;
  }

  String _bmiLabel(NutritionInput input, double bmi) {
    if (input.mode != LifeStageMode.adult) {
      return 'For children and teens, BMI should be interpreted with age-specific growth charts.';
    }
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Healthy range';
    if (bmi < 30) return 'Overweight';
    return 'Obesity range';
  }

  int? _healthyWeightCalories(NutritionInput input) {
    if (input.mode != LifeStageMode.adult) return null;
    final bmi = input.weightKg / _metersSquared(input.heightCm);
    if (bmi >= 18.5 && bmi < 25) return null;

    final targetBmi = bmi < 18.5 ? 18.5 : 24.9;
    final targetWeightKg = targetBmi * _metersSquared(input.heightCm);
    final targetInput = NutritionInput(
      mode: input.mode,
      sex: input.sex,
      activityLevel: input.activityLevel,
      age: input.age,
      weightKg: targetWeightKg,
      heightCm: input.heightCm,
    );
    final targetBmr = _schofieldBmr(targetInput);
    return (targetBmr * _activityMultiplier(input.activityLevel)).round();
  }

  String? _healthyCaloriesDetail(
    NutritionInput input,
    double bmi,
    int? healthyCalories,
  ) {
    if (healthyCalories == null) return null;
    if (input.mode != LifeStageMode.adult) return null;
    if (bmi < 18.5) {
      return 'To move toward the healthy BMI range, an intake around $healthyCalories kcal/day may be more appropriate.';
    }
    if (bmi >= 25) {
      return 'To move toward the healthy BMI range, an intake around $healthyCalories kcal/day may be more appropriate.';
    }
    return null;
  }

  String _scaledValue(double value, double ratio) {
    final scaled = value * ratio;
    if (scaled >= 100) return scaled.round().toString();
    if (scaled >= 10) return scaled.toStringAsFixed(1);
    return scaled.toStringAsFixed(1);
  }

  int _proteinGrams(NutritionInput input) {
    if (input.age <= 3) return 13;
    if (input.age <= 8) return 19;
    if (input.age <= 13) return 34;
    if (input.age <= 18) {
      return input.sex == BiologicalSex.male ? 52 : 46;
    }
    return input.sex == BiologicalSex.male ? 56 : 46;
  }

  int _ironMg(NutritionInput input) {
    if (input.age <= 3) return 7;
    if (input.age <= 8) return 10;
    if (input.age <= 13) return 8;
    if (input.age <= 18) {
      return input.sex == BiologicalSex.male ? 11 : 15;
    }
    if (input.sex == BiologicalSex.male) return 8;
    return input.age >= 51 ? 8 : 18;
  }

  int _calciumMg(NutritionInput input) {
    if (input.age <= 3) return 700;
    if (input.age <= 8) return 1000;
    if (input.age <= 18) return 1300;
    if (input.sex == BiologicalSex.female && input.age >= 51) return 1200;
    if (input.sex == BiologicalSex.male && input.age >= 71) return 1200;
    return 1000;
  }

  int _potassiumMg(NutritionInput input) {
    if (input.age <= 3) return 2000;
    if (input.age <= 8) return 2300;
    if (input.age <= 13) {
      return input.sex == BiologicalSex.male ? 2500 : 2300;
    }
    if (input.age <= 18) {
      return input.sex == BiologicalSex.male ? 3000 : 2300;
    }
    return input.sex == BiologicalSex.male ? 3400 : 2600;
  }

  int _vitaminAMcg(NutritionInput input) {
    if (input.age <= 3) return 300;
    if (input.age <= 8) return 400;
    if (input.age <= 13) return 600;
    if (input.age <= 18) {
      return input.sex == BiologicalSex.male ? 900 : 700;
    }
    return input.sex == BiologicalSex.male ? 900 : 700;
  }

  int _vitaminCMg(NutritionInput input) {
    if (input.age <= 3) return 15;
    if (input.age <= 8) return 25;
    if (input.age <= 13) return 45;
    if (input.age <= 18) {
      return input.sex == BiologicalSex.male ? 75 : 65;
    }
    return input.sex == BiologicalSex.male ? 90 : 75;
  }

  int _vitaminDMcg(NutritionInput input) {
    if (input.age >= 71) return 20;
    return 15;
  }

  int _waterCups(NutritionInput input) {
    if (input.age <= 3) return 4;
    if (input.age <= 8) return 5;
    if (input.age <= 13) {
      return input.sex == BiologicalSex.male ? 8 : 7;
    }
    if (input.age <= 18) {
      return input.sex == BiologicalSex.male ? 11 : 8;
    }
    return input.sex == BiologicalSex.male ? 13 : 9;
  }
}



