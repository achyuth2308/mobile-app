import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_assets_base64.dart';
import '../../providers/auth_provider.dart';

const _kTruckBgAsset = 'assets/images/login_bg_trucks.png';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please enter your email address',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFE63946),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please enter a valid email address',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFE63946),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    final bool ok =
        await ref.read(authProvider.notifier).forgotPassword(email);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      setState(() => _sent = true);
    } else {
      final String? err = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err ?? 'Could not send the reset link. Please try again.',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFE63946),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030508),
      body: Stack(
        children: [
          // ── 1. BACKGROUND IMAGE ──
          Positioned.fill(
            child: Image.asset(
              _kTruckBgAsset,
              fit: BoxFit.cover,
            ),
          ),

          // Subtle dark overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.black.withOpacity(0.35),
                  ],
                ),
              ),
            ),
          ),

          // ── 2. SCROLLABLE UI ──
          SafeArea(
            child: Column(
              children: [
                // Top Bar with Back Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/login');
                        }
                      },
                    ),
                  ),
                ),

                Expanded(
                  child: CustomScrollView(
                    physics: const ClampingScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            children: [
                              const Spacer(),

                              // Header
                              _buildHeader().animate().fadeIn(duration: 700.ms).slideY(begin: -0.05),

                              const SizedBox(height: 36),

                              // Form or Success
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 400),
                                child: _sent
                                    ? _buildSuccessCard().animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.95, 0.95))
                                    : _buildForgotForm().animate().fadeIn(delay: 200.ms, duration: 700.ms).slideY(begin: 0.05),
                              ),

                              const Spacer(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Image.memory(
          AppAssetsB64.logoIcon,
          height: 70,
        ),
      ],
    );
  }

  Widget _buildForgotForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Forgot Password?',
          style: GoogleFonts.playfairDisplay(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the email address registered with your account and we\'ll send you a password reset link.',
          style: GoogleFonts.playfairDisplay(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),

        _buildMinimalInput(
          controller: _emailCtrl,
          hint: 'Enter your email address',
          icon: Icons.mail_outline_rounded,
        ),

        const SizedBox(height: 28),

        _buildGradientButton(
          label: 'SEND RESET LINK',
          icon: Icons.arrow_forward_rounded,
          onPressed: _isLoading ? null : _submit,
          isLoading: _isLoading,
        ),

        const SizedBox(height: 24),

        // Direct link to Reset Password if token already received
        Center(
          child: GestureDetector(
            onTap: () => context.push('/reset-password'),
            child: const Text(
              'Already have a reset token? Enter it here',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF00D2FF),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        Center(
          child: GestureDetector(
            onTap: () => context.go('/login'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 16),
                SizedBox(width: 6),
                Text(
                  'Back to Sign In',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessCard() {
    final String email = _emailCtrl.text.trim();
    final Widget cardContent = Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF10B981), width: 2),
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: Color(0xFF34D399),
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Check Your Inbox',
            style: GoogleFonts.playfairDisplay(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.white70,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'If an account exists for '),
                TextSpan(
                  text: email,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const TextSpan(text: ', an email has been sent with a password reset link (valid for 60 minutes).'),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _buildGradientButton(
            label: 'ENTER RESET TOKEN',
            icon: Icons.vpn_key_rounded,
            onPressed: () => context.push('/reset-password'),
            isLoading: false,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _sent = false),
            child: const Text(
              'Use a different email address',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_back_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'Back to Sign In',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: kIsWeb
          ? cardContent
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: cardContent,
            ),
    );
  }

  Widget _buildMinimalInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    final textField = TextField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.15),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 20, right: 12),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 52),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF00D2FF), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: kIsWeb
          ? textField
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: textField,
            ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isLoading,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2B63FF),
            Color(0xFF00D2FF),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2B63FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(icon, color: Colors.white, size: 20),
                ],
              ),
      ),
    );
  }
}
