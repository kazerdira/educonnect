import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/core/theme/app_theme.dart';
import 'package:educonnect/features/auth/presentation/bloc/auth_bloc.dart';

class RegisterPage extends StatefulWidget {
  final String role;

  const RegisterPage({super.key, required this.role});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _wilayaController = TextEditingController();
  bool _obscurePassword = true;

  // Teacher-specific
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();

  // Student-specific
  String? _selectedLevelCode;

  String get _roleLabel {
    switch (widget.role) {
      case 'teacher':
        return 'Enseignant';
      case 'parent':
        return 'Parent';
      case 'student':
        return 'Élève';
      default:
        return 'Utilisateur';
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _wilayaController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  void _onRegister() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    switch (widget.role) {
      case 'teacher':
        context.read<AuthBloc>().add(
          AuthRegisterTeacherRequested(
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            wilaya: _wilayaController.text.trim(),
            bio: _bioController.text.trim().isNotEmpty
                ? _bioController.text.trim()
                : null,
            experienceYears: int.tryParse(_experienceController.text),
          ),
        );
        break;
      case 'parent':
        context.read<AuthBloc>().add(
          AuthRegisterParentRequested(
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            wilaya: _wilayaController.text.trim(),
          ),
        );
        break;
      case 'student':
        context.read<AuthBloc>().add(
          AuthRegisterStudentRequested(
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            wilaya: _wilayaController.text.trim(),
            levelCode: _selectedLevelCode ?? '',
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inscription $_roleLabel')),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.go('/home');
          }
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.error,
              ),
            );
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 24.h),

                  // Common fields
                  _buildTextField(
                    controller: _firstNameController,
                    label: 'Prénom',
                    icon: Icons.person_outline,
                    validator: _required,
                  ),
                  SizedBox(height: 12.h),
                  _buildTextField(
                    controller: _lastNameController,
                    label: 'Nom',
                    icon: Icons.person_outline,
                    validator: _required,
                  ),
                  SizedBox(height: 12.h),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email requis';
                      if (!v.contains('@')) return 'Email invalide';
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Téléphone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: _required,
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Mot de passe requis';
                      if (v.length < 8) return 'Minimum 8 caractères';
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),
                  _buildTextField(
                    controller: _wilayaController,
                    label: 'Wilaya',
                    icon: Icons.location_on_outlined,
                    validator: _required,
                  ),

                  // Role-specific fields
                  if (widget.role == 'teacher') ..._buildTeacherFields(),
                  if (widget.role == 'student') ..._buildStudentFields(),

                  SizedBox(height: 32.h),

                  // Register button
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      return ElevatedButton(
                        onPressed: state is AuthLoading ? null : _onRegister,
                        child: state is AuthLoading
                            ? SizedBox(
                                height: 24.h,
                                width: 24.w,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text("S'inscrire"),
                      );
                    },
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Déjà un compte ?'),
                      TextButton(
                        onPressed: () => context.go('/auth/login'),
                        child: const Text('Se connecter'),
                      ),
                    ],
                  ),
                  SizedBox(height: 32.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTeacherFields() {
    return [
      SizedBox(height: 12.h),
      _buildTextField(
        controller: _bioController,
        label: 'Bio (optionnel)',
        icon: Icons.description_outlined,
        maxLines: 3,
      ),
      SizedBox(height: 12.h),
      _buildTextField(
        controller: _experienceController,
        label: "Années d'expérience",
        icon: Icons.work_outline,
        keyboardType: TextInputType.number,
      ),
    ];
  }

  List<Widget> _buildStudentFields() {
    return [
      SizedBox(height: 12.h),
      DropdownButtonFormField<String>(
        value: _selectedLevelCode,
        decoration: const InputDecoration(
          labelText: 'Niveau scolaire',
          prefixIcon: Icon(Icons.school_outlined),
        ),
        items: const [
          DropdownMenuItem(value: '1AP', child: Text('1ère Année Primaire')),
          DropdownMenuItem(value: '2AP', child: Text('2ème Année Primaire')),
          DropdownMenuItem(value: '3AP', child: Text('3ème Année Primaire')),
          DropdownMenuItem(value: '4AP', child: Text('4ème Année Primaire')),
          DropdownMenuItem(value: '5AP', child: Text('5ème Année Primaire')),
          DropdownMenuItem(value: '1AM', child: Text('1ère Année Moyenne')),
          DropdownMenuItem(value: '2AM', child: Text('2ème Année Moyenne')),
          DropdownMenuItem(value: '3AM', child: Text('3ème Année Moyenne')),
          DropdownMenuItem(value: '4AM', child: Text('4ème Année Moyenne')),
          DropdownMenuItem(value: '1AS-ST', child: Text('1ère AS - Sciences')),
          DropdownMenuItem(value: '1AS-L', child: Text('1ère AS - Lettres')),
          DropdownMenuItem(
            value: '2AS-SE',
            child: Text('2ème AS - Sciences Expérimentales'),
          ),
          DropdownMenuItem(
            value: '2AS-M',
            child: Text('2ème AS - Mathématiques'),
          ),
          DropdownMenuItem(
            value: '3AS-SE',
            child: Text('3ème AS - Sciences Expérimentales'),
          ),
          DropdownMenuItem(
            value: '3AS-M',
            child: Text('3ème AS - Mathématiques'),
          ),
        ],
        onChanged: (v) => setState(() => _selectedLevelCode = v),
        validator: (v) => v == null ? 'Niveau requis' : null,
      ),
    ];
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: validator,
    );
  }

  String? _required(String? v) {
    if (v == null || v.isEmpty) return 'Ce champ est requis';
    return null;
  }
}
