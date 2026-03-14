import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../services/api_service.dart';

class GuestTrackScreen extends StatefulWidget {
  const GuestTrackScreen({super.key});
  @override
  State<GuestTrackScreen> createState() => _GuestTrackScreenState();
}

class _GuestTrackScreenState extends State<GuestTrackScreen> with SingleTickerProviderStateMixin {
  final _complaintCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _complaint;
  late AnimationController _ac;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    _complaintCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _track() async {
    if (_complaintCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter both complaint ID and mobile number');
      return;
    }
    setState(() { _isLoading = true; _error = null; _complaint = null; });
    final res = await ApiService.post(
      ApiConfig.trackGuest,
      {'complaint_number': _complaintCtrl.text.trim(), 'phone': _phoneCtrl.text.trim()},
      includeAuth: false,
    );
    setState(() {
      _isLoading = false;
      if (res['success'] == true) {
        _complaint = res['complaint'] as Map<String, dynamic>;
      } else {
        _error = res['message'] ?? 'Complaint not found';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Image.network(
          'https://res.cloudinary.com/dk1q50evg/image/upload/v1773349886/tracking-mobile.png',
          fit: BoxFit.cover, width: double.infinity, height: double.infinity,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            )),
          ),
        ),
        Container(color: const Color(0x331E66F5)),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SlideTransition(
                position: _slide,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                    boxShadow: [BoxShadow(color: const Color(0x261E66F5), blurRadius: 50, offset: const Offset(0, 20))],
                  ),
                  padding: const EdgeInsets.all(30),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // Error alert
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECACA))),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFF991B1B), size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF991B1B)))),
                        ]),
                      ),
                    ],

                    // Logo + heading
                    Image.network(
                      'https://res.cloudinary.com/dk1q50evg/image/upload/logo',
                      height: 60,
                      errorBuilder: (_, __, ___) => const Icon(Icons.location_city, size: 56, color: Color(0xFF1E66F5)),
                    ),
                    const SizedBox(height: 6),
                    Text('COMPLAINT MANAGEMENT SYSTEM', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF1E66F5), letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Text('Track Your Complaint', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
                    const SizedBox(height: 24),

                    // Complaint ID field
                    _inputField(_complaintCtrl, 'Enter Complaint ID', Icons.tag),
                    const SizedBox(height: 12),
                    _inputField(_phoneCtrl, 'Enter Mobile Number', Icons.phone_outlined, type: TextInputType.phone),
                    const SizedBox(height: 16),

                    // Track button
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF1E66F5), Color(0xFF2ECC71)]),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: const Color(0xFF1E66F5).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8))],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _track,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('TRACK COMPLAINT', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // OR divider
                    Row(children: [
                      const Expanded(child: Divider(color: Color(0x1A000000))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748b))),
                      ),
                      const Expanded(child: Divider(color: Color(0x1A000000))),
                    ]),
                    const SizedBox(height: 16),

                    // QR button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR Scanner feature coming soon!'))),
                        icon: const Icon(Icons.qr_code_scanner, size: 18, color: Color(0xFF1E66F5)),
                        label: Text('Scan Complaint QR', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E66F5))),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFe2e8f0), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),

                    // Result section
                    if (_complaint != null) ...[
                      const SizedBox(height: 24),
                      const Divider(color: Color(0x0D000000)),
                      const SizedBox(height: 16),
                      Text('Complaint Status', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF0f172a))),
                      const SizedBox(height: 16),
                      _infoGrid(_complaint!),
                      const SizedBox(height: 20),
                      _timeline(_complaint!['work_status'] as String, _complaint!),
                    ],

                    // Back link
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.arrow_back, size: 14, color: Color(0xFF1E66F5)),
                        const SizedBox(width: 6),
                        Text('Back to Home', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E66F5))),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _inputField(TextEditingController c, String hint, IconData icon, {TextInputType type = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5)),
      child: TextField(
        controller: c, keyboardType: type,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0f172a)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748b)),
          prefixIcon: Icon(icon, color: const Color(0xFF64748b), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _infoGrid(Map<String, dynamic> c) {
    final items = [
      ('Complaint ID', '#${c['complaint_number']}'),
      ('Category', c['complaint_type'] ?? ''),
      if (c['assigned_department'] != null) ('Assigned To', c['assigned_department']),
      ('Location', '${c['city']}, ${c['pincode']}'),
      ('Date Submitted', c['created_at'] ?? ''),
      ('Contact Person', c['contact_name'] ?? ''),
      ('Mobile', c['mobile'] ?? ''),
      ('Email', c['email'] ?? ''),
    ];
    return Column(
      children: items.map((item) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(item.$1, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF64748b))),
          const SizedBox(width: 12),
          Flexible(child: Text(item.$2, textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0f172a)))),
        ]),
      )).toList(),
    );
  }

  Widget _timeline(String status, Map<String, dynamic> c) {
    final steps = [
      _TimelineStep('Pending', Icons.circle_outlined, _isCompleted(status, 'pending'), _statusColor('pending'), c['created_at'] ?? ''),
      _TimelineStep('Confirmed', Icons.check_circle_outline, _isCompleted(status, 'confirmed'), _statusColor('confirmed'), _isCompleted(status, 'confirmed') ? (c['updated_at'] ?? 'Pending') : 'Pending'),
      _TimelineStep('In Progress', Icons.autorenew, _isCompleted(status, 'process'), _statusColor('process'), _isCompleted(status, 'process') ? (c['updated_at'] ?? 'Pending') : 'Pending'),
      _TimelineStep(status == 'reopened' ? 'Reopened' : 'Resolved', status == 'reopened' ? Icons.refresh : Icons.check_circle_outline, _isCompleted(status, 'solved'), _statusColor(status == 'reopened' ? 'reopened' : 'solved'), _isCompleted(status, 'solved') ? (c['updated_at'] ?? 'Pending') : 'Pending'),
    ];

    return Column(
      children: List.generate(steps.length, (i) {
        final s = steps[i];
        final isLast = i == steps.length - 1;
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: s.completed ? s.color : Colors.white.withOpacity(0.6),
                border: Border.all(color: s.completed ? Colors.transparent : s.color, width: 2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(s.completed ? Icons.check : s.icon, size: 14, color: s.completed ? Colors.white : const Color(0xFF94a3b8)),
            ),
            if (!isLast) Container(width: 2, height: 36, color: s.completed ? s.color.withOpacity(0.4) : const Color(0xFFCBD5E1)),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0f172a))),
              const SizedBox(height: 2),
              Text(s.date, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748b))),
            ]),
          )),
        ]);
      }),
    );
  }

  bool _isCompleted(String current, String step) {
    const order = ['pending', 'confirmed', 'process', 'solved', 'reopened'];
    final ci = order.indexOf(current);
    final si = order.indexOf(step);
    if (step == 'solved') return current == 'solved' || current == 'reopened';
    return ci >= si && si != -1;
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending': return const Color(0xFFEF4444);
      case 'confirmed': return const Color(0xFFF97316);
      case 'process': return const Color(0xFFEAB308);
      case 'solved': return const Color(0xFF22C55E);
      case 'reopened': return const Color(0xFF991B1B);
      default: return const Color(0xFF94A3B8);
    }
  }
}

class _TimelineStep {
  final String label;
  final IconData icon;
  final bool completed;
  final Color color;
  final String date;
  const _TimelineStep(this.label, this.icon, this.completed, this.color, this.date);
}
