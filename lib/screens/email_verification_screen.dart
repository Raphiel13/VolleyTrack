import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/auth_repository.dart';
import '../theme/app_theme.dart';

// Czas oczekiwania (w sekundach) między kolejnymi wysyłaniami linku weryfikacyjnego
const _kResendCooldownSeconds = 60;

// ─── Email Verification Screen ────────────────────────────────────────────────

// Ekran pośredni wyświetlany po rejestracji lub przy logowaniu na konto
// z niezweryfikowanym e-mailem. Blokuje dostęp do aplikacji do czasu
// potwierdzenia adresu przez kliknięcie linku z wiadomości.
class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _checking = false;
  bool _resending = false;
  String? _message;
  bool _isError = false;

  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // Uruchomienie odliczania blokady ponownego wysłania — ochrona przed nadużyciem
  void _startCooldown() {
    setState(() => _cooldownRemaining = _kResendCooldownSeconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldownRemaining <= 1) {
        t.cancel();
        if (mounted) setState(() => _cooldownRemaining = 0);
      } else {
        if (mounted) setState(() => _cooldownRemaining--);
      }
    });
  }

  // Przeładowanie danych użytkownika i weryfikacja aktualnego statusu e-maila
  Future<void> _checkVerification() async {
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      await ref.read(authRepositoryProvider).reloadUser();
      final verified =
          FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      if (verified) {
        // Sygnał do _AuthGate — wymuś przebudowanie z aktualnym statusem weryfikacji
        ref.read(emailVerifiedRefreshProvider.notifier).state++;
      } else {
        if (mounted) {
          setState(() {
            _message =
                'E-mail nie został jeszcze potwierdzony. Sprawdź skrzynkę i kliknij link.';
            _isError = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Nie udało się sprawdzić statusu. Spróbuj ponownie.';
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  // Ponowne wysłanie e-maila weryfikacyjnego z ochroną przed nadużyciem (cooldown)
  Future<void> _resendEmail() async {
    if (_cooldownRemaining > 0) return;
    setState(() {
      _resending = true;
      _message = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendEmailVerification();
      if (mounted) {
        setState(() {
          _message = 'Link weryfikacyjny został wysłany ponownie.';
          _isError = false;
        });
        _startCooldown();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Nie udało się wysłać wiadomości. Spróbuj za chwilę.';
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final busy = _checking || _resending;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _signOut,
            child: Text(
              'Wyloguj',
              style: AppTheme.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.red,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Ikona ─────────────────────────────────────────────────
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 40,
                      color: AppColors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Tytuł ─────────────────────────────────────────────────
                Center(
                  child: Text(
                    'Sprawdź skrzynkę',
                    style: AppTheme.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: t.label,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Opis ──────────────────────────────────────────────────
                Center(
                  child: Text(
                    'Na adres $email wysłaliśmy link weryfikacyjny. '
                    'Kliknij go, aby aktywować konto.',
                    textAlign: TextAlign.center,
                    style: AppTheme.inter(fontSize: 15, color: t.label2),
                  ),
                ),
                const SizedBox(height: 36),

                // ── Komunikat zwrotny ─────────────────────────────────────
                if (_message != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: (_isError ? AppColors.red : AppColors.green)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_isError ? AppColors.red : AppColors.green)
                            .withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      _message!,
                      style: AppTheme.inter(
                        fontSize: 13,
                        color: _isError ? AppColors.red : AppColors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Przycisk główny: sprawdzenie weryfikacji ──────────────
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: busy ? null : _checkVerification,
                    child: _checking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sprawdzam — odśwież'),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Przycisk pomocniczy: ponowne wysłanie z cooldownem ─────
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: (busy || _cooldownRemaining > 0)
                        ? null
                        : _resendEmail,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: t.separator, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      foregroundColor: t.label,
                    ),
                    child: _resending
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: t.label2,
                            ),
                          )
                        : Text(
                            _cooldownRemaining > 0
                                ? 'Poczekaj $_cooldownRemaining s'
                                : 'Wyślij ponownie',
                            style: AppTheme.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _cooldownRemaining > 0
                                  ? t.label3
                                  : t.label,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
