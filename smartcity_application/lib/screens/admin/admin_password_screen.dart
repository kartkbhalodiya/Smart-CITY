import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';

class AdminPasswordScreen extends StatefulWidget {
  const AdminPasswordScreen({super.key});

  @override
  State<AdminPasswordScreen> createState() => _AdminPasswordScreenState();
}

class _AdminPasswordScreenState extends State<AdminPasswordScreen> {
  static const _bg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF0B1020);
  static const _text = Color(0xFF101828);
  static const _muted = Color(0xFF5B6B86);
  static const _line = Color(0xFFEEF2F6);
  static const _primary = Color(0xFF2F80ED);

  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _saving = false;
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _saving = true);
    final response = await ApiService.post(ApiConfig.adminChangePassword, {
      'current_password': _currentController.text.trim(),
      'new_password': _newController.text.trim(),
      'confirm_password': _confirmController.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);

    if (response['success'] == true) {
      HapticFeedback.selectionClick();
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']?.toString() ??
              'Password updated successfully.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message']?.toString() ?? 'Password failed.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 18, 24, 34 + bottomInset),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _topBar(),
                  const SizedBox(height: 18),
                  _heroCard(),
                  const SizedBox(height: 18),
                  _formCard(),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          _iconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          const SizedBox(width: 12),
          Image.asset('assets/images/logo.png',
              width: 118, fit: BoxFit.contain),
        ],
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 24),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              color: _primary,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Change Password', style: _displayStyle(size: 23)),
                const SizedBox(height: 6),
                Text(
                  'Update the password for this admin account.',
                  style: _labelStyle(
                    size: 12,
                    weight: FontWeight.w700,
                    color: _muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _passwordField(
              controller: _currentController,
              label: 'Current password',
              hidden: _hideCurrent,
              onToggle: () => setState(() => _hideCurrent = !_hideCurrent),
            ),
            const SizedBox(height: 12),
            _passwordField(
              controller: _newController,
              label: 'New password',
              hidden: _hideNew,
              onToggle: () => setState(() => _hideNew = !_hideNew),
            ),
            const SizedBox(height: 12),
            _passwordField(
              controller: _confirmController,
              label: 'Confirm password',
              hidden: _hideConfirm,
              onToggle: () => setState(() => _hideConfirm = !_hideConfirm),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Confirm password is required';
                }
                if (value!.trim() != _newController.text.trim()) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            _blackButton(
              label: _saving ? 'Saving...' : 'Save Password',
              icon: Icons.check_rounded,
              onTap: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool hidden,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: hidden,
      style: _labelStyle(size: 15, weight: FontWeight.w800, color: _text),
      validator: validator ??
          (value) {
            if ((value ?? '').trim().isEmpty) return '$label is required';
            if (label == 'New password' && value!.trim().length < 8) {
              return 'Use at least 8 characters';
            }
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        labelStyle:
            _labelStyle(size: 13, weight: FontWeight.w700, color: _muted),
        suffixIcon: IconButton(
          icon: Icon(
            hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: _muted,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _ink, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: Icon(icon, color: _ink, size: 21),
          ),
        ),
      ),
    );
  }

  Widget _blackButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.65 : 1,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A1A), Color(0xFF050505)],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: _labelStyle(
                  size: 15,
                  weight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration({required double radius}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _line),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  TextStyle _displayStyle({
    required double size,
    double height = 1.08,
    Color color = _ink,
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      height: height,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
      color: color,
    );
  }

  TextStyle _labelStyle({
    required double size,
    required FontWeight weight,
    required Color color,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      height: height,
      fontWeight: weight,
      letterSpacing: 0,
      color: color,
    );
  }
}
