import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:educonnect/features/payment/presentation/bloc/payment_bloc.dart';

class InitiatePaymentPage extends StatefulWidget {
  const InitiatePaymentPage({super.key});

  @override
  State<InitiatePaymentPage> createState() => _InitiatePaymentPageState();
}

class _InitiatePaymentPageState extends State<InitiatePaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _sessionIdController = TextEditingController();
  final _courseIdController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedMethod = 'CCP';
  final List<String> _paymentMethods = ['CCP', 'Baridimob', 'Edahabia'];

  @override
  void dispose() {
    _sessionIdController.dispose();
    _courseIdController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final sessionId = _sessionIdController.text.trim();
    final courseId = _courseIdController.text.trim();
    final description = _descriptionController.text.trim();

    context.read<PaymentBloc>().add(
          InitiatePaymentRequested(
            sessionId: sessionId.isNotEmpty ? sessionId : null,
            courseId: courseId.isNotEmpty ? courseId : null,
            amount: double.parse(_amountController.text.trim()),
            paymentMethod: _selectedMethod,
            description: description.isNotEmpty ? description : null,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau paiement')),
      body: BlocListener<PaymentBloc, PaymentState>(
        listener: (context, state) {
          if (state is PaymentInitiated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Paiement initié avec succès')),
            );
            Navigator.of(context).pop();
          }
          if (state is PaymentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: BlocBuilder<PaymentBloc, PaymentState>(
          builder: (context, state) {
            final isLoading = state is PaymentLoading;

            return SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Session ID (optional)
                    TextFormField(
                      controller: _sessionIdController,
                      decoration: const InputDecoration(
                        labelText: 'ID de la séance (optionnel)',
                        prefixIcon: Icon(Icons.event),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Course ID (optional)
                    TextFormField(
                      controller: _courseIdController,
                      decoration: const InputDecoration(
                        labelText: 'ID du cours (optionnel)',
                        prefixIcon: Icon(Icons.school),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Amount
                    TextFormField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Montant (DA)',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez entrer un montant';
                        }
                        final parsed = double.tryParse(value.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Montant invalide';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12.h),

                    // Payment method dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedMethod,
                      decoration: const InputDecoration(
                        labelText: 'Méthode de paiement',
                        prefixIcon: Icon(Icons.payment),
                      ),
                      items: _paymentMethods
                          .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedMethod = value);
                        }
                      },
                    ),
                    SizedBox(height: 12.h),

                    // Description (optional)
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (optionnel)',
                        prefixIcon: Icon(Icons.description),
                        alignLabelWithHint: true,
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Submit button
                    SizedBox(
                      height: 48.h,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _submit,
                        icon: isLoading
                            ? SizedBox(
                                width: 20.w,
                                height: 20.h,
                                child: const CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        label: Text(
                          isLoading ? 'Envoi...' : 'Initier le paiement',
                          style: TextStyle(fontSize: 16.sp),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
