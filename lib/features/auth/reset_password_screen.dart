import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_assets_base64.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

const _kTruckBgAsset = 'assets/images/login_bg_trucks.png';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({this.token = '', super.key});

  final String token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  late final TextEditingController _tokenCtrl;
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _tokenCtrl = TextEditingController(text: widget.token);
    _passCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  /// 0–4 strength score driving the meter.
  int get _strength {
    final String p = _passCtrl.text;
    if (p.isEmpty) return 0;
    int score = 0;
    if (p.length >= 6) score++;
    if (p.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p) && RegExp(r'[^A-Za-z0-9]').hasMatch(p)) {
      score++;
    }
    return score.clamp(0, 4);
  }

  Future<void> _submit() async {
    final String token = _tokenCtrl.text.trim();
    final String pass = _passCtrl.text;
    final String confirm = _confirmCtrl.text;

    if (token.isEmpty) {
      _showError('Please provide a valid reset token');
      return;
    }
    if (pass.isEmpty) {
      _showError('Please enter a new password');
      return;
    }
    if (pass.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }
    if (pass != confirm) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    final bool ok = await ref.read(authProvider.notifier).resetPassword(
          token: token,
          password: pass,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      setState(() => _success = true);
    } else {
      final String? err = ref.read(authProvider).error;
      _showError(err ?? 'Could not reset password. The token may be expired or invalid.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFFE63946),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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

                              const SizedBox(height: 32),

                              // Form or Success
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 400),
                                child: _success
                                    ? _buildSuccessCard().animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.95, 0.95))
                                    : _buildResetForm().animate().fadeIn(delay: 200.ms, duration: 700.ms).slideY(begin: 0.05),
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
        const SizedBox(height: 14),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'FUEL',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFFE63946),
                letterSpacing: -0.01 * 32,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'TRACKS',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0084FF),
                letterSpacing: -0.01 * 32,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResetForm() {
    const List<String> labels = <String>['', 'Weak', 'Fair', 'Good', 'Strong'];
    const List<Color> colors = <Color>[
      AppColors.offline,
      AppColors.danger,
      AppColors.idle,
      AppColors.signal,
      AppColors.moving,
    ];

    final bool isTokenPreset = widget.token.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Reset Password',
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
          'Create a new secure password for your account.',
          style: GoogleFonts.playfairDisplay(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Reset Token Input
        if (!isTokenPreset) ...[
          _buildInput(
            controller: _tokenCtrl,
            hint: 'Paste Reset Token',
            icon: Icons.vpn_key_outlined,
          ),
          const SizedBox(height: 16),
        ],

        // New Password
        _buildInput(
          controller: _passCtrl,
          hint: 'New Password',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          obscureText: _obscurePass,
          onToggleObscure: () => setState(() => _obscurePass = !_obscurePass),
        ),

        const SizedBox(height: 10),

        // Password Strength Meter
        if (_passCtrl.text.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                ...List<Widget>.generate(
                  4,
                  (int i) => Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: i < _strength
                            ? colors[_strength]
                            : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 48,
                  child: Text(
                    labels[_strength],
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors[_strength],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ] else
          const SizedBox(height: 6),

        // Confirm Password
        _buildInput(
          controller: _confirmCtrl,
          hint: 'Confirm New Password',
          icon: Icons.lock_person_outlined,
          isPassword: true,
          obscureText: _obscureConfirm,
          onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),

        const SizedBox(height: 28),

        _buildGradientButton(
          label: 'RESET PASSWORD',
          icon: Icons.check_circle_outline_rounded,
          onPressed: _isLoading ? null : _submit,
          isLoading: _isLoading,
        ),

        const SizedBox(height: 20),

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
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
                  Icons.check_circle_rounded,
                  color: Color(0xFF34D399),
                  size: 38,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Password Reset!',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Your password has been successfully updated. You can now sign in with your new password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              _buildGradientButton(
                label: 'SIGN IN NOW',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => context.go('/login'),
                isLoading: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: TextField(
          controller: controller,
          obscureText: isPassword && obscureText,
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
            suffixIcon: isPassword
                ? GestureDetector(
                    onTap: onToggleObscure,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Icon(
                        obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(minWidth: 40),
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
        ),
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
