import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:educonnect/features/auth/domain/entities/user.dart';
import 'package:educonnect/features/auth/domain/repositories/auth_repository.dart';

// ─── Events ─────────────────────────────────────────────────────

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterTeacherRequested extends AuthEvent {
  final String email;
  final String phone;
  final String password;
  final String firstName;
  final String lastName;
  final String wilaya;
  final String? bio;
  final int? experienceYears;

  const AuthRegisterTeacherRequested({
    required this.email,
    required this.phone,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.wilaya,
    this.bio,
    this.experienceYears,
  });

  @override
  List<Object?> get props => [
    email,
    phone,
    password,
    firstName,
    lastName,
    wilaya,
  ];
}

class AuthRegisterParentRequested extends AuthEvent {
  final String email;
  final String phone;
  final String password;
  final String firstName;
  final String lastName;
  final String wilaya;

  const AuthRegisterParentRequested({
    required this.email,
    required this.phone,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.wilaya,
  });

  @override
  List<Object?> get props => [
    email,
    phone,
    password,
    firstName,
    lastName,
    wilaya,
  ];
}

class AuthRegisterStudentRequested extends AuthEvent {
  final String email;
  final String phone;
  final String password;
  final String firstName;
  final String lastName;
  final String wilaya;
  final String levelCode;
  final String? school;
  final String? dateOfBirth;

  const AuthRegisterStudentRequested({
    required this.email,
    required this.phone,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.wilaya,
    required this.levelCode,
    this.school,
    this.dateOfBirth,
  });

  @override
  List<Object?> get props => [
    email,
    phone,
    password,
    firstName,
    lastName,
    wilaya,
    levelCode,
  ];
}

class AuthLogoutRequested extends AuthEvent {}

// ─── States ─────────────────────────────────────────────────────

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;

  const AuthAuthenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ─── Bloc ───────────────────────────────────────────────────────

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterTeacherRequested>(_onRegisterTeacher);
    on<AuthRegisterParentRequested>(_onRegisterParent);
    on<AuthRegisterStudentRequested>(_onRegisterStudent);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticated(user: user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (_) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await authRepository.login(
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(user: result.user));
    } catch (e) {
      emit(AuthError(message: _mapError(e)));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onRegisterTeacher(
    AuthRegisterTeacherRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await authRepository.registerTeacher(
        email: event.email,
        phone: event.phone,
        password: event.password,
        firstName: event.firstName,
        lastName: event.lastName,
        wilaya: event.wilaya,
        bio: event.bio,
        experienceYears: event.experienceYears,
      );
      emit(AuthAuthenticated(user: result.user));
    } catch (e) {
      emit(AuthError(message: _mapError(e)));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onRegisterParent(
    AuthRegisterParentRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await authRepository.registerParent(
        email: event.email,
        phone: event.phone,
        password: event.password,
        firstName: event.firstName,
        lastName: event.lastName,
        wilaya: event.wilaya,
      );
      emit(AuthAuthenticated(user: result.user));
    } catch (e) {
      emit(AuthError(message: _mapError(e)));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onRegisterStudent(
    AuthRegisterStudentRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await authRepository.registerStudent(
        email: event.email,
        phone: event.phone,
        password: event.password,
        firstName: event.firstName,
        lastName: event.lastName,
        wilaya: event.wilaya,
        levelCode: event.levelCode,
        school: event.school,
        dateOfBirth: event.dateOfBirth,
      );
      emit(AuthAuthenticated(user: result.user));
    } catch (e) {
      emit(AuthError(message: _mapError(e)));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await authRepository.logout();
    emit(AuthUnauthenticated());
  }

  String _mapError(dynamic e) {
    if (e.toString().contains('409')) {
      return 'Un compte avec cet email ou téléphone existe déjà';
    }
    if (e.toString().contains('401')) {
      return 'Email ou mot de passe incorrect';
    }
    return 'Une erreur est survenue. Veuillez réessayer.';
  }
}
