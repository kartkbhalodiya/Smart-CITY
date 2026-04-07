import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/routes.dart';
import '../../l10n/app_strings.dart';

class ComplaintSuccessScreen extends StatelessWidget {
  final String complaintId;
  final String title;
  final String description;

  const ComplaintSuccessScreen({
    super.key,
    required this.complaintId,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1E66F5);
    const textDark = Color(0xFF0F172A);
    const textMuted = Color(0xFF64748B);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final nextRoute = auth.isAuthenticated ? AppRoutes.userDashboard : AppRoutes.guestDashboard;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Animation/Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF22C55E),
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              Text(
                AppStrings.t(context, 'Complaint Submitted Successfully!'),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 12),
              
              Text(
                AppStrings.t(context, 'Thank you for your report. Your issue has been registered and assigned to the relevant department.'),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              
              // Complaint Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow(AppStrings.t(context, 'Complaint ID'), complaintId, isHighlight: true),
                    const Divider(height: 24, color: Color(0xFFE2E8F0)),
                    _detailRow(AppStrings.t(context, 'Title'), title),
                    const SizedBox(height: 16),
                    _detailRow(AppStrings.t(context, 'Description'), description, maxLines: 3),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primary.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppStrings.t(context, 'Please keep the Complaint ID safe. Use it to track your complaint status in the "Track Complaint" section.'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              
              // OK Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate back to dashboard and clear stack
                    Navigator.pushNamedAndRemoveUntil(
                      context, 
                      nextRoute, 
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    AppStrings.t(context, 'OK'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isHighlight = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: isHighlight ? 18 : 14,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: isHighlight ? const Color(0xFF1E66F5) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
