import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../providers/complaint_provider.dart';
import '../../models/complaint.dart';
import '../../services/api_service.dart';
import '../../l10n/app_strings.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final int complaintId;
  const ComplaintDetailScreen({super.key, required this.complaintId});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  static const _accent = Color(0xFFFF6B35);
  static const _dark = Color(0xFF1A1A1A);
  static const _bg = Color(0xFFF8F9FA);

  bool _showDeptPopup = false;
  final MapController _mapController = MapController();
  final ScrollController _scrollController = ScrollController();
  int _selectedRating = 0;
  bool _isSubmittingRating = false;
  bool _isSubmittingReopen = false;
  final _commentCtrl = TextEditingController();
  final _reopenReasonCtrl = TextEditingController();
  String? _reopenProofPath;

  @override
  void dispose() {
    _commentCtrl.dispose();
    _reopenReasonCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ComplaintProvider>(context, listen: false);
      // Load the complaint details
      provider.loadComplaintDetail(widget.complaintId).then((_) {
        if (provider.error != null) {
          debugPrint('Error loading complaint: ${provider.error}');
        }
        // Ensure scroll starts at top after content loads
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: _dark),
        title: Text(
          AppStrings.t(context, 'Complaint Details'),
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
      ),
      body: Consumer<ComplaintProvider>(
        builder: (context, provider, child) {
          final complaint = provider.selectedComplaint;
          final isInitialLoad = complaint == null && !provider.isLoading && provider.error == null;
          
          // Show loading if actively loading OR if initial state with no data
          if (provider.isLoading || isInitialLoad) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.t(context, 'Loading complaint details...'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            );
          }
          
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.t(context, 'Error loading complaint'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.error!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      provider.loadComplaintDetail(widget.complaintId);
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(AppStrings.t(context, 'Retry')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          }
          
          if (complaint == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.t(context, 'Complaint not found'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.t(context, 'The complaint you are looking for does not exist'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(AppStrings.t(context, 'Go Back')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          }
          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(complaint),
                const SizedBox(height: 16),
                _buildOverviewStrip(complaint),
                const SizedBox(height: 12),
                _buildSectionShortcuts(complaint),
                const SizedBox(height: 16),

                _accordionSection(
                  title: AppStrings.t(context, 'User Information'),
                  icon: Icons.person_outline,
                  initiallyExpanded: true,
                  child: _buildUserDetailsCard(complaint),
                ),

                _accordionSection(
                  title: AppStrings.t(context, 'Complaint Details'),
                  icon: Icons.description_outlined,
                  initiallyExpanded: true,
                  child: _buildComplaintDetailsCard(complaint),
                ),

                if ((complaint.media != null && complaint.media!.isNotEmpty) || complaint.mediaCount > 0)
                  _accordionSection(
                    title: AppStrings.t(context, 'Uploaded Images'),
                    icon: Icons.photo_library_outlined,
                    child: _buildUploadedImagesSection(complaint),
                  ),

                if (complaint.fieldResponses != null && complaint.fieldResponses!.isNotEmpty)
                  _accordionSection(
                    title: AppStrings.t(context, 'Additional Information'),
                    icon: Icons.info_outline,
                    child: _buildAdditionalFieldsCard(complaint.fieldResponses!),
                  ),

                if (complaint.assignedDepartment != null)
                  _accordionSection(
                    title: AppStrings.t(context, 'Assigned Department'),
                    icon: Icons.business_outlined,
                    child: _buildDepartmentCard(complaint.assignedDepartment!),
                  ),

                if (complaint.latitude != 0.0 && complaint.longitude != 0.0)
                  _accordionSection(
                    title: AppStrings.t(context, 'Location Map'),
                    icon: Icons.map_outlined,
                    child: _buildMapSection(complaint),
                  ),

                _accordionSection(
                  title: AppStrings.t(context, 'Status Timeline'),
                  icon: Icons.timeline_outlined,
                  child: _buildStatusTimeline(complaint),
                ),

                if (_departmentProofMedia(complaint).isNotEmpty)
                  _accordionSection(
                    title: AppStrings.t(context, 'Department Proof'),
                    icon: Icons.verified_outlined,
                    child: _buildMediaSection(
                      AppStrings.t(context, 'Department Proof'),
                      _departmentProofMedia(complaint),
                    ),
                  ),

                if (complaint.citizenRating != null)
                  _accordionSection(
                    title: AppStrings.t(context, 'Your Rating'),
                    icon: Icons.star_outline_rounded,
                    child: _buildExistingRating(complaint),
                  )
                else if (complaint.workStatus == 'solved' || complaint.workStatus == 'resolved')
                  _accordionSection(
                    title: AppStrings.t(context, 'Rate This Resolution'),
                    icon: Icons.rate_review_outlined,
                    child: _buildRatingForm(complaint),
                    initiallyExpanded: true,
                  ),

                if (_canReopenComplaint(complaint) || complaint.canReopen == true)
                  _accordionSection(
                    title: AppStrings.t(context, 'Need Reopen?'),
                    icon: Icons.refresh_rounded,
                    child: _buildReopenButton(complaint),
                  ),
                 
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildOverviewStrip(Complaint complaint) {
    final createdDate = complaint.createdAt.toString().split(' ')[0];
    final locationText = complaint.city.isNotEmpty
        ? '${complaint.city}${complaint.state.isNotEmpty ? ', ${complaint.state}' : ''}'
        : complaint.address;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEFEFEF)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _overviewItem(Icons.schedule_rounded, AppStrings.t(context, 'Created'), createdDate),
          _overviewItem(Icons.location_on_outlined, AppStrings.t(context, 'Area'), locationText),
          _overviewItem(Icons.flag_outlined, AppStrings.t(context, 'Priority'), complaint.priorityDisplay),
          _overviewItem(Icons.confirmation_number_outlined, AppStrings.t(context, 'ID'), '#${complaint.complaintNumber}'),
        ],
      ),
    );
  }

  Widget _overviewItem(IconData icon, String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _accent),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: _dark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionShortcuts(Complaint complaint) {
    final chips = <Map<String, dynamic>>[
      {'icon': Icons.person_outline, 'label': AppStrings.t(context, 'User')},
      {'icon': Icons.description_outlined, 'label': AppStrings.t(context, 'Details')},
      if ((complaint.media != null && complaint.media!.isNotEmpty) || complaint.mediaCount > 0)
        {'icon': Icons.photo_library_outlined, 'label': AppStrings.t(context, 'Media')},
      if (complaint.assignedDepartment != null)
        {'icon': Icons.business_outlined, 'label': AppStrings.t(context, 'Department')},
      if (complaint.latitude != 0.0 && complaint.longitude != 0.0)
        {'icon': Icons.map_outlined, 'label': AppStrings.t(context, 'Map')},
      {'icon': Icons.timeline_outlined, 'label': AppStrings.t(context, 'Timeline')},
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEDEDED)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(chip['icon'] as IconData, size: 13, color: _accent),
                const SizedBox(width: 5),
                Text(
                  chip['label'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3D3D3D),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _accordionSection({
    required String title,
    required IconData icon,
    required Widget child,
    bool initiallyExpanded = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('detail-$title'),
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          collapsedIconColor: const Color(0xFF727272),
          iconColor: _accent,
          leading: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: _accent),
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          children: [child],
        ),
      ),
    );
  }

  String _getCategoryEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'police':
        return '🚓';
      case 'traffic':
        return '🚦';
      case 'construction':
        return '🏗️';
      case 'water':
      case 'water supply':
        return '🚰';
      case 'electricity':
        return '💡';
      case 'garbage':
        return '🗑️';
      case 'road':
      case 'pothole':
        return '🛣️';
      case 'drainage':
        return '🌊';
      case 'illegal':
      case 'illegal activity':
        return '⚠️';
      case 'transportation':
        return '🚌';
      case 'cyber':
      case 'cyber crime':
        return '🛡️';
      default:
        return '📋';
    }
  }

  String _localizedComplaintType(Complaint complaint) {
    final display = complaint.complaintTypeDisplay.trim();
    if (display.isNotEmpty) {
      return AppStrings.t(context, display);
    }
    return AppStrings.t(context, complaint.complaintType);
  }

  Widget _buildHeader(Complaint complaint) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
                ),
                child: Text(
                  '#${complaint.complaintNumber}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
              _StatusChip(
                status: complaint.workStatus,
                statusText: complaint.workStatusDisplay,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _accent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_getCategoryEmoji(complaint.complaintType), style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      _localizedComplaintType(complaint),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            complaint.title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 6),
              Text(
                '${AppStrings.t(context, 'Submitted on')} ${complaint.createdAt.toString().split(' ')[0]}',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetailsCard(Complaint complaint) {
    String? contactName;
    String? contactMobile;
    String? contactEmail;
    
    // Extract from field responses
    if (complaint.fieldResponses != null) {
      for (var response in complaint.fieldResponses!) {
        final label = response.fieldLabel.trim();
        final value = response.value.trim();
        
        if (value.isEmpty) continue;
        
        // Match exact field names from your API
        if (label == 'Full Name' || label == 'Name' || label == 'Your Name') {
          contactName = value;
        } else if (label == 'Contact Number' || label == 'Mobile Number' || label == 'Phone Number' || label == 'Mobile') {
          contactMobile = value;
        } else if (label == 'Email Address' || label == 'Email' || label == 'Your Email') {
          contactEmail = value;
        }
      }
    }
    
    // Fallback to userName if name not found
    contactName ??= complaint.userName;
    
    // Don't show the card if no information is available
    if ((contactName == null || contactName.isEmpty) && 
        (contactMobile == null || contactMobile.isEmpty) && 
        (contactEmail == null || contactEmail.isEmpty)) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEFEFEF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person, color: _accent, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                AppStrings.t(context, 'User Information'),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0f172a),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (contactName != null && contactName.isNotEmpty) ...[
            _buildInfoRow(Icons.person_outline, AppStrings.t(context, 'Name'), contactName),
            const SizedBox(height: 12),
          ],
          if (contactMobile != null && contactMobile.isNotEmpty) ...[
            _buildInfoRow(Icons.phone_outlined, AppStrings.t(context, 'Mobile'), contactMobile),
            const SizedBox(height: 12),
          ],
          if (contactEmail != null && contactEmail.isNotEmpty)
            _buildInfoRow(Icons.email_outlined, AppStrings.t(context, 'Email'), contactEmail),
        ],
      ),
    );
  }

  Widget _buildComplaintDetailsCard(Complaint complaint) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEFEFEF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description, color: _accent, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                AppStrings.t(context, 'Complaint Details'),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0f172a),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow(Icons.category_outlined, AppStrings.t(context, 'Category'), complaint.complaintTypeDisplay),
          if (complaint.subcategory != null && complaint.subcategory!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.subdirectory_arrow_right, AppStrings.t(context, 'Subcategory'), complaint.subcategory!),
          ],
          const SizedBox(height: 12),
          _buildInfoRow(Icons.flag_outlined, AppStrings.t(context, 'Priority'), complaint.priorityDisplay),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.location_on_outlined, AppStrings.t(context, 'Location'), complaint.address),
          if (complaint.dateOfOccurrence != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.event_outlined,
              AppStrings.t(context, 'Date of Occurrence'),
              "${complaint.dateOfOccurrence!.day.toString().padLeft(2, '0')} ${_getMonthName(complaint.dateOfOccurrence!.month)} ${complaint.dateOfOccurrence!.year}",
            ),
          ],
          const SizedBox(height: 16),
          Text(
            AppStrings.t(context, 'Description'),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            complaint.description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF374151),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadedImagesSection(Complaint complaint) {
    final hasMedia = complaint.media != null && complaint.media!.isNotEmpty;
    final hasThumbnail = complaint.thumbnail != null && complaint.thumbnail!.isNotEmpty;
    final mediaCount = complaint.mediaCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.photo_library, color: Colors.purple.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppStrings.t(context, 'Uploaded Images'),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0f172a),
                  ),
                ),
              ),
              if (mediaCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$mediaCount',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Show media if available
          if (hasMedia)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: complaint.media!.length,
              itemBuilder: (context, index) {
                final item = complaint.media![index];
                final imageUrl = _resolveMediaUrl(item);
                
                return GestureDetector(
                  onTap: () => _viewMedia(item),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: Icon(Icons.broken_image, color: Colors.grey.shade400, size: 32),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey.shade100,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            )
          // Show thumbnail if no media array but thumbnail exists
          else if (hasThumbnail)
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  barrierColor: Colors.black87,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(10),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height * 0.8,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Center(
                              child: Image.network(
                                complaint.thumbnail!,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.error_outline, color: Colors.white, size: 48),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Failed to load image',
                                          style: GoogleFonts.inter(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, color: Colors.white, size: 28),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        complaint.thumbnail!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey.shade100,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                    color: Colors.purple.shade700,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Loading image...',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Error loading thumbnail: ${complaint.thumbnail}');
                          debugPrint('Error: $error');
                          return Container(
                            color: Colors.grey.shade200,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, color: Colors.grey.shade400, size: 48),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Failed to load image',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Tap to zoom indicator
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.zoom_in, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Tap to zoom',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          // Show informative message if images uploaded but not available
          else if (mediaCount > 0)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300, width: 2),
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload, size: 56, color: Colors.amber.shade700),
                  const SizedBox(height: 12),
                  Text(
                    '$mediaCount ${mediaCount == 1 ? 'Image' : 'Images'} Uploaded',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Images are stored in Cloudinary',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.amber.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder, size: 16, color: Colors.amber.shade900),
                        const SizedBox(width: 6),
                        Text(
                          'smartcity_complaints',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w600,
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

  Widget _buildAdditionalFieldsCard(List<ComplaintFieldResponse> fieldResponses) {
    // Filter out name, email, mobile fields that are shown in user details
    final additionalFields = fieldResponses.where((field) {
      final label = field.fieldLabel.trim();
      // Exclude these specific fields
      return label != 'Full Name' && 
             label != 'Name' && 
             label != 'Your Name' &&
             label != 'Contact Number' && 
             label != 'Mobile Number' && 
             label != 'Phone Number' && 
             label != 'Mobile' &&
             label != 'Email Address' && 
             label != 'Email' && 
             label != 'Your Email' &&
             field.value.trim().isNotEmpty;
    }).toList();

    if (additionalFields.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.info_outline, color: Colors.green.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                AppStrings.t(context, 'Additional Information'),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0f172a),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...additionalFields.asMap().entries.map((entry) {
            final index = entry.key;
            final field = entry.value;
            return Column(
              children: [
                if (index > 0) const SizedBox(height: 12),
                _buildInfoRow(Icons.arrow_right, field.fieldLabel, field.value),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapSection(Complaint complaint) {
    final complaintPos = LatLng(complaint.latitude, complaint.longitude);
    final dept = complaint.assignedDepartment;
    final hasDept = dept != null && dept.latitude != 0.0 && dept.longitude != 0.0;
    final deptPos = hasDept ? LatLng(dept.latitude, dept.longitude) : null;

    final points = [complaintPos, if (deptPos != null) deptPos];
    final bounds = LatLngBounds.fromPoints(points);
    final fit = CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.all(80),
      maxZoom: 15,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFEFEF)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.map, color: _accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t(context, 'Location Map'),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        hasDept
                            ? AppStrings.t(context, 'Route: Complaint Site → Department')
                            : AppStrings.t(context, 'Complaint location'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Map
          Container(
            height: 300,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCameraFit: fit,
                  onMapReady: () {
                    Future.microtask(() {
                      if (mounted) _mapController.fitCamera(fit);
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.janhelp.app',
                  ),
                  // Blue line connecting complaint to department
                  if (deptPos != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [complaintPos, deptPos],
                          color: _accent,
                          strokeWidth: 3.0,
                        ),
                      ],
                    ),
                  // Markers
                  MarkerLayer(
                    markers: [
                      // Complaint marker (red)
                      Marker(
                        point: complaintPos,
                        width: 50,
                        height: 50,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                        ),
                      ),
                      // Department marker (blue)
                      if (deptPos != null)
                        Marker(
                          point: deptPos,
                          width: 50,
                          height: 50,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _accent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.business, color: Colors.white, size: 24),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Legend at bottom
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(const Color(0xFFEF4444), AppStrings.t(context, 'Complaint Site')),
                if (hasDept) ...[
                  const SizedBox(width: 20),
                  const Icon(Icons.arrow_forward, size: 16, color: _accent),
                  const SizedBox(width: 20),
                  _buildLegendItem(_accent, AppStrings.t(context, 'Department')),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentCard(Department dept) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B2B2B), Color(0xFF3C3C3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.business, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.t(context, 'Assigned Department'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    Text(
                      dept.name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
              if (dept.phone.isNotEmpty) ...[
                _buildDeptInfoRow(Icons.phone, dept.phone, Colors.white),
                const SizedBox(height: 8),
              ],
                if (dept.email.isNotEmpty) ...[
                  _buildDeptInfoRow(Icons.email, dept.email, Colors.white),
                  const SizedBox(height: 8),
                ],
                if (dept.address.isNotEmpty)
                  _buildDeptInfoRow(Icons.location_on, dept.address, Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeptInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTimeline(Complaint complaint) {
    final status = complaint.workStatus;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEFEFEF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: _accent, size: 20),
              const SizedBox(width: 8),
              Text(
                AppStrings.t(context, 'Status Timeline'),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0f172a),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTimelineStep(
            'Submitted',
            complaint.createdAt.toString().split(' ')[0],
            Icons.assignment_turned_in,
            _accent,
            isCompleted: true,
          ),
          _buildTimelineStep(
            'Confirmed',
            '',
            Icons.verified,
            Colors.green,
            isCompleted: status == 'confirmed' || status == 'process' || status == 'solved' || status == 'resolved' || status == 'reopened',
          ),
          _buildTimelineStep(
            'In Progress',
            '',
            Icons.engineering,
            Colors.orange,
            isCompleted: status == 'process' || status == 'solved' || status == 'resolved' || status == 'reopened',
          ),
          if (status == 'reopened') ...[
            _buildTimelineStep(
              'Reopened',
              complaint.reopenedAt?.toString().split(' ')[0] ?? '',
              Icons.refresh,
              Colors.red,
              isCompleted: true,
            ),
          ],
          _buildTimelineStep(
            'Resolved',
            '',
            Icons.check_circle,
            Colors.green,
            isCompleted: status == 'solved' || status == 'resolved',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(
    String title,
    String time,
    IconData icon,
    Color color,
    {
    required bool isCompleted,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted ? color : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 16,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: isCompleted ? color : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.t(context, title),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? const Color(0xFF0f172a) : Colors.grey.shade500,
                  ),
                ),
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _resolveMediaUrl(ComplaintMedia media) {
    final fileUrl = media.fileUrl.trim();
    if (fileUrl.isNotEmpty) return fileUrl;

    final file = media.file.trim();
    if (file.isEmpty) return file;

    if (file.startsWith('http://') || file.startsWith('https://')) {
      return file;
    }

    if (file.startsWith('/')) {
      final base = ApiConfig.baseUrl.replaceAll('/api', '');
      return '$base$file';
    }

    return file;
  }

  List<ComplaintMedia> _departmentProofMedia(Complaint complaint) {
    if (complaint.workProof != null && complaint.workProof!.isNotEmpty) {
      return complaint.workProof!;
    }
    final media = complaint.media;
    if (media == null || media.isEmpty) return const [];
    return media.where((m) {
      final type = m.fileType.toLowerCase();
      return type.contains('work') ||
          type.contains('proof') ||
          type.contains('completion') ||
          type.contains('resolved');
    }).toList();
  }

  Widget _buildMediaSection(String title, List<ComplaintMedia> media) {
    if (media.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.verified, color: Colors.green.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0f172a),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${media.length}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: media.length,
            itemBuilder: (context, index) {
              final item = media[index];
              final imageUrl = _resolveMediaUrl(item);
              
              return GestureDetector(
                onTap: () => _viewMedia(item),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: Icon(Icons.broken_image, color: Colors.grey.shade400, size: 32),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey.shade100,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            );
                          },
                        ),
                        // Verified badge overlay
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade700,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified, color: Colors.white, size: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _viewMedia(ComplaintMedia media) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    _resolveMediaUrl(media),
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.white, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load image',
                              style: GoogleFonts.inter(color: Colors.white),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExistingRating(Complaint complaint) {
    final r = complaint.citizenRating!;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.t(context, 'Your Rating'), style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF92400E))),
          const SizedBox(height: 8),
          Row(children: List.generate(5, (i) => Icon(
            i < r ? Icons.star : Icons.star_border,
            color: const Color(0xFFF59E0B), size: 26,
          ))),
          if (complaint.citizenFeedback != null && complaint.citizenFeedback!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(complaint.citizenFeedback!, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF78350F))),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingForm(Complaint complaint) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.t(context, 'Rate This Resolution'), style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => GestureDetector(
              onTap: () => setState(() => _selectedRating = i + 1),
              child: Icon(
                i < _selectedRating ? Icons.star : Icons.star_border,
                size: 34, color: Colors.orange,
              ),
            )),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: AppStrings.t(context, 'Comment (optional)'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedRating > 0 && !_isSubmittingRating
                  ? () => _submitRating(complaint)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSubmittingRating
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(AppStrings.t(context, 'Submit Rating'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReopenButton(Complaint complaint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _showReopenDialog(complaint),
          icon: const Icon(Icons.refresh),
          label: Text(AppStrings.t(context, 'Reopen Complaint'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  bool _canReopenComplaint(Complaint complaint) {
    if (!(complaint.workStatus == 'solved' || complaint.workStatus == 'resolved')) {
      return false;
    }
    if (complaint.canReopen == true) return true;
    final daysSinceSolved = DateTime.now().difference(complaint.updatedAt).inDays;
    return daysSinceSolved <= 7;
  }

  void _showReopenDialog(Complaint complaint) {
    // Clear form before showing dialog
    _reopenReasonCtrl.clear();
    setState(() {
      _reopenProofPath = null;
      _isSubmittingReopen = false;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppStrings.t(context, 'Reopen Complaint'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937))),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('#${complaint.complaintNumber}',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444))),
                ),
                const SizedBox(height: 16),
                Text('${AppStrings.t(context, 'Reason for reopening:')} *', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _reopenReasonCtrl,
                  maxLines: 4,
                  onChanged: (_) => setDlg(() {}),
                  decoration: InputDecoration(
                    hintText: AppStrings.t(context, 'Describe why you want to reopen...'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),
                Text(AppStrings.t(context, 'Attach Photo Proof (Optional):'), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (img != null) setDlg(() => _reopenProofPath = img.path);
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFFF9FAFB),
                    ),
                    child: _reopenProofPath != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(File(_reopenProofPath!), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                              ),
                              Positioned(
                                top: 6, right: 6,
                                child: GestureDetector(
                                  onTap: () => setDlg(() => _reopenProofPath = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate, size: 36, color: Color(0xFF9CA3AF)),
                              const SizedBox(height: 6),
                              Text(AppStrings.t(context, 'Tap to add photo'), style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280))),
                            ],
                          ),
                  ),
                ),
                
                // Preview Section
                if (_reopenReasonCtrl.text.trim().isNotEmpty || _reopenProofPath != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.preview, color: Color(0xFF92400E), size: 18),
                            const SizedBox(width: 8),
                            Text(AppStrings.t(context, 'Preview'), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF92400E))),
                          ],
                        ),
                        if (_reopenReasonCtrl.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(AppStrings.t(context, 'Reason:'), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF78350F))),
                          const SizedBox(height: 4),
                          Text(_reopenReasonCtrl.text.trim(), style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF92400E))),
                        ],
                        if (_reopenProofPath != null) ...[
                          const SizedBox(height: 12),
                          Text(AppStrings.t(context, 'Proof Image:'), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF78350F))),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_reopenProofPath!),
                              height: 100,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _reopenReasonCtrl.text.trim().isNotEmpty && !_isSubmittingReopen
                        ? () => _submitReopen(ctx, complaint)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSubmittingReopen
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(AppStrings.t(context, 'Submit Reopen Request'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitReopen(BuildContext dialogCtx, Complaint complaint) async {
    if (_isSubmittingReopen) return;
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingCtx) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  _reopenProofPath != null 
                    ? AppStrings.t(context, 'Uploading proof...')
                    : AppStrings.t(context, 'Submitting request...'),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    setState(() => _isSubmittingReopen = true);
    try {
      final uri = Uri.parse(ApiConfig.reopenComplaint(complaint.id));
      final request = http.MultipartRequest('POST', uri);
      
      // Add authorization header
      final token = await ApiService.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      // Add reason field
      request.fields['reason'] = _reopenReasonCtrl.text.trim();
      
      // Add proof image file if provided
      if (_reopenProofPath != null) {
        final file = File(_reopenProofPath!);
        request.files.add(
          await http.MultipartFile.fromPath(
            'proof',
            file.path,
            filename: 'reopen_proof.jpg',
          ),
        );
      }
      
      debugPrint('Submitting reopen request with reason: ${request.fields['reason']}');
      debugPrint('Has proof file: ${_reopenProofPath != null}');
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final res = json.decode(response.body);
      
      debugPrint('Reopen response: $res');
      
      setState(() => _isSubmittingReopen = false);
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      if (!mounted) return;
      
      if (res['success'] == true) {
        // Close reopen dialog
        Navigator.pop(dialogCtx);
        
        // Clear form
        _reopenReasonCtrl.clear();
        setState(() => _reopenProofPath = null);
        
        // Reload complaint details
        await Provider.of<ComplaintProvider>(context, listen: false).loadComplaintDetail(complaint.id);
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.t(context, 'Complaint reopened successfully!')),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Show error message
        String errorMsg = res['message'] ?? AppStrings.t(context, 'Failed to submit reopen request');
        if (res['errors'] != null) {
          errorMsg += '\n${res['errors']}';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSubmittingReopen = false);
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        debugPrint('Error submitting reopen: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.t(context, 'Error')}: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _submitRating(Complaint complaint) async {
    setState(() => _isSubmittingRating = true);
    final res = await ApiService.post(
      ApiConfig.rateComplaint(complaint.id),
      {'rating': _selectedRating.toString(), 'feedback': _commentCtrl.text.trim()},
    );
    setState(() => _isSubmittingRating = false);
    if (!mounted) return;
    if (res['success'] == true) {
      Provider.of<ComplaintProvider>(context, listen: false).loadComplaintDetail(complaint.id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'Rating submitted successfully!')), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? AppStrings.t(context, 'Failed')), backgroundColor: Colors.red));
    }
  }

  Future<String?> _uploadProofToCloudinary(File imageFile) async {
    try {
      const cloudName = 'dk1q50evg';
      const uploadPreset = 'smartcity_complaints';
      
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', url);
      
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'complaints/reopen_proof';
      
      final multipartFile = await http.MultipartFile.fromPath('file', imageFile.path);
      request.files.add(multipartFile);
      
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['secure_url'] as String;
      }
      return null;
    } catch (e) {
      debugPrint('Error uploading proof to Cloudinary: $e');
      return null;
    }
  }

  void _openUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) launchUrl(Uri.parse(url));
  }

  void _openMap(double lat, double lng) async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }
}

// ── Department tap popup ────────────────────────────────────────────────────
class _DeptPopup extends StatelessWidget {
  final Department dept;
  final VoidCallback onClose;
  final VoidCallback onViewDetails;

  const _DeptPopup({
    required this.dept,
    required this.onClose,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1E66F5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.business,
                color: Color(0xFF1E66F5), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dept.name,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0f172a)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  AppStrings.t(context, dept.departmentTypeDisplay),
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF64748b)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onViewDetails,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E66F5),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF1E66F5).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: Text(
                AppStrings.t(context, 'View Details'),
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close,
                size: 18, color: Color(0xFF94a3b8)),
          ),
        ],
      ),
    );
  }
}

// ── Status chip ─────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  final String statusText;
  const _StatusChip({required this.status, required this.statusText});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    switch (status) {
      case 'submitted':
        color = Colors.orange;
        break;
      case 'assigned':
        color = Colors.blue;
        break;
      case 'in-progress':
        color = Colors.indigo;
        break;
      case 'resolved':
        color = Colors.green;
        break;
      case 'reopened':
        color = Colors.red;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(AppStrings.t(context, statusText),
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
    );
  }
}
