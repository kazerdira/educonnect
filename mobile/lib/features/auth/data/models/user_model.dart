import 'package:educonnect/features/auth/domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.role,
    required super.firstName,
    required super.lastName,
    required super.wilaya,
    required super.language,
    required super.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      role: json['role'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      wilaya: json['wilaya'] as String? ?? '',
      language: json['language'] as String? ?? 'fr',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'first_name': firstName,
      'last_name': lastName,
      'wilaya': wilaya,
      'language': language,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
