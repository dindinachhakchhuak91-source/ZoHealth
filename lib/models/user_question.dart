/// Represents a user question submitted through the Q&A section
class UserQuestion {
  final String id;
  final String question;
  final String userName;
  final String gender;
  final int age;
  final double heightCm;
  final double weightKg;
  final String recentEatingWindow;
  final String recentFood;
  final DateTime askedAt;
  final String? reply;
  final DateTime? repliedAt;
  final bool isAnswered;

  UserQuestion({
    required this.id,
    required this.question,
    required this.userName,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.recentEatingWindow,
    required this.recentFood,
    required this.askedAt,
    this.reply,
    this.repliedAt,
    this.isAnswered = false,
  });

  factory UserQuestion.fromJson(Map<String, dynamic> json) => UserQuestion(
        id: json['id']?.toString() ?? '',
        question: json['question']?.toString() ?? '',
        userName: json['user_name']?.toString() ?? '',
        gender: json['gender']?.toString() ?? '',
        age: int.tryParse(json['age']?.toString() ?? '') ?? 0,
        heightCm: double.tryParse(json['height_cm']?.toString() ?? '') ?? 0,
        weightKg: double.tryParse(json['weight_kg']?.toString() ?? '') ?? 0,
        recentEatingWindow: json['recent_eating_window']?.toString() ?? '',
        recentFood: json['recent_food']?.toString() ?? '',
        askedAt:
            DateTime.tryParse(json['asked_at']?.toString() ?? '') ?? DateTime.now(),
        reply: json['reply']?.toString(),
        repliedAt: json['replied_at'] != null
            ? DateTime.tryParse(json['replied_at'].toString())
            : null,
        isAnswered: json['is_answered'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'user_name': userName,
        'gender': gender,
        'age': age,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'recent_eating_window': recentEatingWindow,
        'recent_food': recentFood,
        'asked_at': askedAt.toIso8601String(),
        'reply': reply,
        'replied_at': repliedAt?.toIso8601String(),
        'is_answered': isAnswered,
      };

  UserQuestion copyWith({
    String? id,
    String? question,
    String? userName,
    String? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    String? recentEatingWindow,
    String? recentFood,
    DateTime? askedAt,
    String? reply,
    DateTime? repliedAt,
    bool? isAnswered,
  }) =>
      UserQuestion(
        id: id ?? this.id,
        question: question ?? this.question,
        userName: userName ?? this.userName,
        gender: gender ?? this.gender,
        age: age ?? this.age,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        recentEatingWindow: recentEatingWindow ?? this.recentEatingWindow,
        recentFood: recentFood ?? this.recentFood,
        askedAt: askedAt ?? this.askedAt,
        reply: reply ?? this.reply,
        repliedAt: repliedAt ?? this.repliedAt,
        isAnswered: isAnswered ?? this.isAnswered,
      );

  String get adminIntakeSummary =>
      'Gender: $gender | Age: $age | Height: ${heightCm.toStringAsFixed(heightCm.truncateToDouble() == heightCm ? 0 : 1)} cm | Weight: ${weightKg.toStringAsFixed(weightKg.truncateToDouble() == weightKg ? 0 : 1)} kg | Last ate: $recentEatingWindow | Food: $recentFood';
}
