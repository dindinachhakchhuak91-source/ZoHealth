enum UserRole { admin, user }

const Object _avatarUrlNotSet = Object();

class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final UserRole role;
  final DateTime createdAt;
  final DateTime? lastLogin;

  AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    required this.role,
    required this.createdAt,
    this.lastLogin,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      avatarUrl: json['avatar_url'],
      role: (json['role'] ?? 'user') == 'admin'
          ? UserRole.admin
          : UserRole.user,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'role': role == UserRole.admin ? 'admin' : 'user',
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? fullName,
    Object? avatarUrl = _avatarUrlNotSet,
    UserRole? role,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl:
          identical(avatarUrl, _avatarUrlNotSet) ? this.avatarUrl : avatarUrl as String?,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  bool get isAdmin => role == UserRole.admin;
}
