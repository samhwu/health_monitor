// lib/models/user_profile.dart

class UserProfile {
  final String name;
  final int? age;
  final String? gender;       // 'male' | 'female' | 'other'
  final double? heightCm;
  final int? targetHRMax;     // 目標最大心率（預設 220 - 年齡）

  const UserProfile({
    required this.name,
    this.age,
    this.gender,
    this.heightCm,
    this.targetHRMax,
  });

  int get effectiveHRMax {
    if (targetHRMax != null) return targetHRMax!;
    if (age != null) return 220 - age!;
    return 180;
  }

  UserProfile copyWith({
    String? name,
    int? age,
    String? gender,
    double? heightCm,
    int? targetHRMax,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      targetHRMax: targetHRMax ?? this.targetHRMax,
    );
  }
}
