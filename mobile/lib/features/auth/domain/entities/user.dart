import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String role;
  final String firstName;
  final String lastName;
  final String wilaya;
  final String language;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.wilaya,
    required this.language,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, email, role, firstName, lastName];
}
