import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_assets_base64.dart';
import '../../providers/auth_provider.dart';

const _kTruckBgAsset = 'assets/images/login_bg_trucks.png';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  bool _obscurePassword = true;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);

    final success = await ref.read(authProvider.notifier).login(
          identifier: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.go('/dashboard');
      } else {
        final error = ref.read(authProvider).error;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              backgroundColor: const Color(0xFFE63946),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030508), // Dark background
      body: Stack(
        children: [
          // ── 1. FULL SCREEN IMAGE (Trucks fully visible) ──
          Positioned.fill(
            child: Image.asset(
              _kTruckBgAsset,
              fit: BoxFit.cover,
            ),
          ),
          
          // Subtle dark overlay to make white text perfectly readable
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8), // Dark at bottom where form is
                    Colors.black.withOpacity(0.2), // Lighter at top where logo is
                  ],
                ),
              ),
            ),
          ),

          // ── 2. SCROLLABLE UI ──
          SafeArea(
            child: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const Spacer(), // Pushes header down
                        
                        // Header
                        _buildHeader().animate().fadeIn(duration: 800.ms).slideY(begin: -0.05),
                        
                        const SizedBox(height: 40), // Space between header and form
                        
                        // Form seamlessly sitting on the white background
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: _buildLoginForm().animate().fadeIn(delay: 200.ms, duration: 800.ms).slideY(begin: 0.05),
                        ),
                        
                        const SizedBox(height: 48),
                        
                        // Footer seamlessly at the bottom
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 448),
                          child: _buildFooterNav().animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                        ),
                        
                        const SizedBox(height: 32),
                      ],
                    ),
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
          height: 80,
        ),
        const SizedBox(height: 16),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'FUEL',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Color(0xFFE63946),
                letterSpacing: -0.01 * 36,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'TRACKS',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0084FF),
                letterSpacing: -0.01 * 36,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'FUEL MONITORING NOW ONLINE.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(0.8),
            letterSpacing: 2.4,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    // Notice: NO Container, NO Border, NO Shadow, NO Glass. Just pure content on white.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Welcome back',
          style: GoogleFonts.playfairDisplay(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to monitor your fleet in real time.',
          style: GoogleFonts.playfairDisplay(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        
        _buildMinimalInput(
          controller: _emailCtrl,
          hint: 'Email or username',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 16),
        _buildMinimalInput(
          controller: _passCtrl,
          hint: 'Password',
          icon: Icons.lock_outline,
          isPassword: true,
        ),
        
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => context.push('/forgot-password'),
            child: const Text(
              'Forgot password?',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        _buildGradientButton(),
      ],
    );
  }

  Widget _buildMinimalInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), // Frosted glass effect
        child: TextField(
          controller: controller,
          obscureText: isPassword && _obscurePassword,
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
            fillColor: Colors.white.withOpacity(0.15), // Milky highlight
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 20, right: 12),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 52),
            suffixIcon: isPassword
                ? GestureDetector(
                    onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(minWidth: 40),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5), // Visible resting border
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF00D2FF), width: 2), // Bright brand blue highlight when tapped
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton() {
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
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sign In',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildFooterNav() {
    // Instead of a glass pill, a clean minimal row that sits on the white background
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user, color: Colors.white70, size: 16),
            SizedBox(width: 8),
            Text(
              'SECURED WITH END-TO-END ENCRYPTION',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _buildFooterNavItem(
              icon: Icons.query_stats,
              iconColor: const Color(0xFF0084FF),
              bgColor: const Color(0xFFEFF6FF),
              title: 'Monitoring',
            ),
            const SizedBox(width: 8),
            _buildFooterNavItem(
              icon: Icons.shield_outlined,
              iconColor: const Color(0xFF4F46E5),
              bgColor: const Color(0xFFEEF2FF),
              title: 'Security',
            ),
            const SizedBox(width: 8),
            _buildFooterNavItem(
              icon: Icons.notifications_active_outlined,
              iconColor: const Color(0xFFE63946),
              bgColor: const Color(0xFFFEF2F2),
              title: 'Alerts',
            ),
            const SizedBox(width: 8),
            _buildFooterNavItem(
              icon: Icons.local_gas_station_outlined,
              iconColor: const Color(0xFF059669),
              bgColor: const Color(0xFFECFDF5),
              title: 'Efficiency',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooterNavItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
