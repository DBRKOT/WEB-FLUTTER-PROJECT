import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/auth_notifier.dart';
import '../core/validators.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _fieldErrors = {};
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await context.read<AuthNotifier>().register(
        email: _emailController.text,
        password: _passwordController.text,
        fullName: _fullNameController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Аккаунт создан. Войдите в систему.')),
      );
      context.go('/login');
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = Map<String, String>.from(e.errors);
        _error = e.message;
      });
      _formKey.currentState!.validate();
    } on ConflictException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = Map<String, String>.from(e.errors);
        _error = 'Этот адрес почты уже занят.';
      });
      _formKey.currentState!.validate();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось зарегистрироваться: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Регистрация',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Новый клиент ТехноМаркет',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'ФИО',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final api = _fieldErrors['fullName'];
                        if (api != null) return api;
                        return V.combine([
                          V.required(),
                          V.length(min: 2, max: 120),
                        ])(value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Электронная почта',
                        border: OutlineInputBorder(),
                        helperText: 'Используется как логин',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final api = _fieldErrors['email'];
                        if (api != null) return api;
                        return V.combine([V.required(), V.email()])(value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Пароль',
                        border: const OutlineInputBorder(),
                        helperText: '≥8 символов, цифра и спецсимвол (!@#)',
                        suffixIcon: IconButton(
                          tooltip: _obscure
                              ? 'Показать пароль'
                              : 'Скрыть пароль',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final api = _fieldErrors['password'];
                        if (api != null) return api;
                        return V.combine([V.required(), V.strongPassword()])(
                          value,
                        );
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Зарегистрироваться'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => context.go('/login'),
                      child: const Text('Уже есть аккаунт'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
