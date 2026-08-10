import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Step { onboarding, login, register }

class _AuthScreenState extends State<AuthScreen> {
  _Step _step = _Step.onboarding;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _password.text;
    final name = _name.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Заполни email и пароль');
      return;
    }
    if (_step == _Step.register && name.isEmpty) {
      setState(() => _error = 'Введи имя');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final app = context.read<AppState>();
    try {
      final ok = _step == _Step.register
          ? await app.register(email, pass, name, phone: _phone.text.trim())
          : await app.login(email, pass);
      if (!ok && mounted) setState(() => _error = 'Не удалось войти');
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('401')) return 'Неверный email или пароль';
    if (s.contains('409')) return 'Этот email уже зарегистрирован';
    if (s.contains('400')) return 'Проверь введённые данные';
    if (s.contains('SocketException') || s.contains('Connection refused')) {
      return 'Нет связи с сервером';
    }
    return 'Ошибка: $s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (_step) {
            _Step.onboarding => _onboarding(),
            _Step.login => _form('Вход', registerLink: true),
            _Step.register => _form('Регистрация', registerLink: false),
          },
        ),
      ),
    );
  }

  Widget _onboarding() {
    return Center(
      key: const ValueKey('onb'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: softShadow(opacity: 0.15),
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 54,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'GB Messenger',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: GBTheme.whatsAppDark,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Быстрые сообщения, звонки, статусы.\nБезопасно и удобно.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GBTheme.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 40),
            NeonButton(
              label: 'Начать',
              icon: Icons.arrow_forward_rounded,
              onPressed: () => setState(() => _step = _Step.register),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _step = _Step.login),
              child: const Text(
                'Уже есть аккаунт? Войти',
                style: TextStyle(color: GBTheme.whatsAppGreen),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(String title, {required bool registerLink}) {
    return SingleChildScrollView(
      key: ValueKey(title),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: GBTheme.whatsAppDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Синхронизируйся с контактами и историей',
            style: TextStyle(color: GBTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          if (_step == _Step.register) ...[
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Имя'),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Email'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Номер телефона (+7...)',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: _obscure,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Пароль',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: GBTheme.textSecondary,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
          const SizedBox(height: 28),
          NeonButton(
            label: title,
            onPressed: _busy ? null : _submit,
            loading: _busy,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _step = registerLink ? _Step.login : _Step.register;
                      _error = null;
                    });
                  },
            child: Text(
              registerLink
                  ? 'Уже есть аккаунт? Войти'
                  : 'Нет аккаунта? Зарегистрироваться',
            ),
          ),
        ],
      ),
    );
  }
}
