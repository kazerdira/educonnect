import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String phone;
  final String role;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String wilaya;
  final String language;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    this.phone = '',
    required this.role,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.wilaya,
    required this.language,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, email, role, firstName, lastName];
}
