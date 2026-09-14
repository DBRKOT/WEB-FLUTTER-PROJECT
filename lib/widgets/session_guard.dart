import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/session_config.dart';

class SessionGuard extends StatefulWidget {
  const SessionGuard({super.key, required this.child});

  final Widget child;

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard>
    with WidgetsBindingObserver {
  Timer? _ticker;
  bool _warningVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    debugPrint(
      '[Session] idle=${sessionIdleSeconds}s warn=${sessionWarnSeconds}s '
      'max=${sessionMaxSeconds}s',
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AuthNotifier>().touchActivity();
    }
  }

  Future<void> _tick() async {
    if (!mounted) return;
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated || auth.isRestoring) return;

    final now = DateTime.now();
    final started = auth.sessionStartedAt ?? now;
    final idleFor = now.difference(auth.lastActivityAt);
    final aliveFor = now.difference(started);
    final messenger = ScaffoldMessenger.maybeOf(context);

    if (aliveFor >= sessionMaxDuration) {
      await auth.logout(reason: 'истёк лимит длительности сессии');
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Сессия завершена: превышен лимит времени входа.'),
        ),
      );
      return;
    }

    final warnAfter = sessionIdleTimeout - sessionWarnBefore;
    if (idleFor >= sessionIdleTimeout) {
      if (_warningVisible && mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        _warningVisible = false;
      }
      await auth.logout(reason: 'неактивность');
      messenger?.showSnackBar(
        const SnackBar(content: Text('Сессия завершена из‑за неактивности.')),
      );
      return;
    }

    if (idleFor >= warnAfter && !_warningVisible) {
      _warningVisible = true;
      if (!mounted) return;
      final stay = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Сессия скоро завершится'),
          content: Text(
            'Вы неактивны. Выход через $sessionWarnSeconds с.\n'
            'Продолжить работу?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Выйти'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Остаться'),
            ),
          ],
        ),
      );
      _warningVisible = false;
      if (!mounted) return;
      if (stay == true) {
        auth.touchActivity();
      } else {
        await auth.logout(reason: 'пользователь подтвердил выход по таймауту');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => context.read<AuthNotifier>().touchActivity(),
      child: widget.child,
    );
  }
}
