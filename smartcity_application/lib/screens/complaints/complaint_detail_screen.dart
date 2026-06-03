import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
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
  static const _accent = Color(0xFF2F80ED);
  static const _dark = Color(0xFF0B1020);
  static const _bg = Color(0xFFF7F8FA);
  static const _text = Color(0xFF101828);
  static const _muted = Color(0xFF5B6B86);
  static const _line = Color(0xFFEEF2F6);

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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: _topBar(),
            ),
            Expanded(
              child: Consumer<ComplaintProvider>(
                builder: (context, provider, child) {
                  final complaint = provider.selectedComplaint;
                  final isInitialLoad = complaint == null &&
                      !provider.isLoading &&
                      provider.error == null;

                  if (provider.isLoading || isInitialLoad) {
                    return _stateView(
                      icon: Icons.hourglass_top_rounded,
                      title:
                          AppStrings.t(context, 'Loading complaint details...'),
                      showLoader: true,
                    );
                  }

                  if (provider.error != null) {
                    return _stateView(
                      icon: Icons.error_outline_rounded,
                      title: AppStrings.t(context, 'Error loading complaint'),
                      subtitle: provider.error!,
                      actionLabel: AppStrings.t(context, 'Retry'),
                      actionIcon: Icons.refresh_rounded,
                      onAction: () =>
                          provider.loadComplaintDetail(widget.complaintId),
                    );
                  }

                  if (complaint == null) {
                    return _stateView(
                      icon: Icons.search_off_rounded,
                      title: AppStrings.t(context, 'Complaint not found'),
                      subtitle: AppStrings.t(
                        context,
                        'The complaint you are looking for does not exist',
                      ),
                      actionLabel: AppStrings.t(context, 'Go Back'),
                      actionIcon: Icons.arrow_back_rounded,
                      onAction: () => Navigator.pop(context),
                    );
                  }

                  return SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(complaint),
                        const SizedBox(height: 14),
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
                        if ((complaint.media != null &&
                                complaint.media!.isNotEmpty) ||
                            complaint.mediaCount > 0)
                          _accordionSection(
                            title: AppStrings.t(context, 'Uploaded Images'),
                            icon: Icons.photo_library_outlined,
                            child: _buildUploadedImagesSection(complaint),
                          ),
                        if (complaint.fieldResponses != null &&
                            complaint.fieldResponses!.isNotEmpty)
                          _accordionSection(
                            title:
                                AppStrings.t(context, 'Additional Information'),
                            icon: Icons.info_outline,
                            child: _buildAdditionalFieldsCard(
                              complaint.fieldResponses!,
                            ),
                          ),
                        if (complaint.assignedDepartment != null)
                          _accordionSection(
                            title: AppStrings.t(context, 'Assigned Department'),
                            icon: Icons.business_outlined,
                            child: _buildDepartmentCard(
                              complaint.assignedDepartment!,
                            ),
                          ),
                        if (complaint.latitude != 0.0 &&
                            complaint.longitude != 0.0)
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
                        if (complaint.reopenProofs != null &&
                            complaint.reopenProofs!.isNotEmpty)
                          _accordionSection(
                            title: AppStrings.t(context, 'Reopen Proof'),
                            icon: Icons.restart_alt_rounded,
                            child: _buildReopenProofSection(
                              complaint.reopenProofs!,
                            ),
                          ),
                        if (complaint.citizenRating != null)
                          _accordionSection(
                            title: AppStrings.t(context, 'Your Rating'),
                            icon: Icons.star_outline_rounded,
                            child: _buildExistingRating(complaint),
                          )
                        else if (complaint.workStatus == 'solved' ||
                            complaint.workStatus == 'resolved')
                          _accordionSection(
                            title:
                                AppStrings.t(context, 'Rate This Resolution'),
                            icon: Icons.rate_review_outlined,
                            child: _buildRatingForm(complaint),
                            initiallyExpanded: true,
                          ),
                        if (complaint.canReopen == true)
                          _accordionSection(
                            title: AppStrings.t(context, 'Need Reopen?'),
                            icon: Icons.refresh_rounded,
                            child: _buildReopenButton(complaint),
                          ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          _topIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          Image.asset(
            'assets/images/logo.png',
            width: 126,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          _topIconButton(
            icon: Icons.refresh_rounded,
            onTap: () => context
                .read<ComplaintProvider>()
                .loadComplaintDetail(widget.complaintId),
          ),
        ],
      ),
    );
  }

  Widget _topIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _line),
          ),
          child: Center(child: Icon(icon, color: _dark, size: 21)),
        ),
      ),
    );
  }

  Widget _stateView({
    required IconData icon,
    required String title,
    String? subtitle,
    bool showLoader = false,
    String? actionLabel,
    IconData? actionIcon,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _line),
            ),
            child: showLoader
                ? const Center(
                    child: CircularProgressIndicator(
                      color: _accent,
                      strokeWidth: 3,
                    ),
                  )
                : Icon(icon, size: 34, color: _accent),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: _titleStyle(size: 18),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: _labelStyle(
                size: 14,
                weight: FontWeight.w500,
                color: _muted,
                height: 1.35,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.arrow_forward_rounded, size: 18),
                label: Text(actionLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _dark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  textStyle: _labelStyle(
                    size: 13,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration({double radius = 22}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _line),
    );
  }

  TextStyle _displayStyle({
    required double size,
    double height = 0.98,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      height: height,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
      color: _text,
    );
  }

  TextStyle _titleStyle({required double size}) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
      color: _text,
    );
  }

  static TextStyle _labelStyle({
    required double size,
    required FontWeight weight,
    required Color color,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: 0,
      height: height,
      color: color,
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
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
      decoration: _cardDecoration(radius: 20),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _overviewItem(Icons.schedule_rounded,
              AppStrings.t(context, 'Created'), createdDate),
          _overviewItem(Icons.location_on_outlined,
              AppStrings.t(context, 'Area'), locationText),
          _overviewItem(Icons.flag_outlined, AppStrings.t(context, 'Priority'),
              complaint.priorityDisplay),
          _overviewItem(Icons.confirmation_number_outlined,
              AppStrings.t(context, 'ID'), '#${complaint.complaintNumber}'),
        ],
      ),
    );
  }

  Widget _overviewItem(IconData icon, String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
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
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: _text,
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
      {
        'icon': Icons.description_outlined,
        'label': AppStrings.t(context, 'Details')
      },
      if ((complaint.media != null && complaint.media!.isNotEmpty) ||
          complaint.mediaCount > 0)
        {
          'icon': Icons.photo_library_outlined,
          'label': AppStrings.t(context, 'Media')
        },
      if (complaint.assignedDepartment != null)
        {
          'icon': Icons.business_outlined,
          'label': AppStrings.t(context, 'Department')
        },
      if (complaint.latitude != 0.0 && complaint.longitude != 0.0)
        {'icon': Icons.map_outlined, 'label': AppStrings.t(context, 'Map')},
      {
        'icon': Icons.timeline_outlined,
        'label': AppStrings.t(context, 'Timeline')
      },
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
              border: Border.all(color: _line),
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
                    fontWeight: FontWeight.w800,
                    color: _text,
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
      decoration: _cardDecoration(radius: 22),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('detail-$title'),
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          collapsedIconColor: _muted,
          iconColor: _accent,
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 17, color: _accent),
          ),
          title: Text(
            title,
            style: _titleStyle(size: 14),
          ),
          children: [child],
        ),
      ),
    );
  }

  String _categoryAssetFor(String category) {
    switch (category.toLowerCase()) {
      case 'police':
        return 'assets/images/cat_police.png';
      case 'traffic':
        return 'assets/images/cat_traffic.png';
      case 'construction':
        return 'assets/images/cat_construction.png';
      case 'water':
      case 'water supply':
        return 'assets/images/cat_waste_overflow.png';
      case 'electricity':
        return 'assets/images/cat_electric.png';
      case 'garbage':
        return 'assets/images/cat_garbage.png';
      case 'road':
      case 'pothole':
        return 'assets/images/cat_roads.png';
      case 'drainage':
        return 'assets/images/cat_drainage.png';
      case 'illegal':
      case 'illegal activity':
        return 'assets/images/cat_illegal.png';
      case 'transportation':
        return 'assets/images/cat_transportation.png';
      case 'cyber':
      case 'cyber crime':
        return 'assets/images/cat_cyber.png';
      default:
        return 'assets/images/cat_other.png';
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
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  _categoryAssetFor(complaint.complaintType),
                  width: 58,
                  height: 58,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Container(
                    width: 58,
                    height: 58,
                    color: const Color(0xFFEFF7FF),
                    child: const Icon(Icons.category_rounded, color: _accent),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      complaint.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _displayStyle(size: 21, height: 1.12),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _localizedComplaintType(complaint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _labelStyle(
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusChip(
                status: complaint.workStatus,
                statusText: complaint.workStatusDisplay,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaPill(
                icon: Icons.confirmation_number_outlined,
                label: '#${complaint.complaintNumber}',
              ),
              _metaPill(
                icon: Icons.calendar_today_rounded,
                label:
                    '${AppStrings.t(context, 'Submitted')} ${complaint.createdAt.toString().split(' ')[0]}',
              ),
              _metaPill(
                icon: Icons.flag_outlined,
                label: complaint.priorityDisplay,
                color: _priorityColor(complaint.priority),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaPill({
    required IconData icon,
    required String label,
    Color color = _accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: _labelStyle(
              size: 11.5,
              weight: FontWeight.w800,
              color: color == _accent ? _text : color,
            ),
          ),
        ],
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'urgent':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFEAB308);
      case 'low':
        return const Color(0xFF22C55E);
      default:
        return _accent;
    }
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
        } else if (label == 'Contact Number' ||
            label == 'Mobile Number' ||
            label == 'Phone Number' ||
            label == 'Mobile') {
          contactMobile = value;
        } else if (label == 'Email Address' ||
            label == 'Email' ||
            label == 'Your Email') {
          contactEmail = value;
        }
      }
    }

    final fallbackName = complaint.userName.trim();
    if ((contactName == null || contactName.isEmpty) &&
        fallbackName.isNotEmpty) {
      contactName = fallbackName;
    }

    // Don't show the card if no information is available
    if ((contactName?.isEmpty ?? true) &&
        (contactMobile?.isEmpty ?? true) &&
        (contactEmail?.isEmpty ?? true)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (contactName?.isNotEmpty ?? false) ...[
            _buildInfoRow(Icons.person_outline, AppStrings.t(context, 'Name'),
                contactName!),
            const SizedBox(height: 12),
          ],
          if (contactMobile != null && contactMobile.isNotEmpty) ...[
            _buildInfoRow(Icons.phone_outlined, AppStrings.t(context, 'Mobile'),
                contactMobile),
            const SizedBox(height: 12),
          ],
          if (contactEmail != null && contactEmail.isNotEmpty)
            _buildInfoRow(Icons.email_outlined, AppStrings.t(context, 'Email'),
                contactEmail),
        ],
      ),
    );
  }

  Widget _buildComplaintDetailsCard(Complaint complaint) {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
              Icons.category_outlined,
              AppStrings.t(context, 'Category'),
              complaint.complaintTypeDisplay),
          if (complaint.subcategory != null &&
              complaint.subcategory!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.subdirectory_arrow_right,
                AppStrings.t(context, 'Subcategory'), complaint.subcategory!),
          ],
          const SizedBox(height: 12),
          _buildInfoRow(Icons.flag_outlined, AppStrings.t(context, 'Priority'),
              complaint.priorityDisplay),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.location_on_outlined,
              AppStrings.t(context, 'Location'), complaint.address),
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
            style: _labelStyle(
              size: 13,
              weight: FontWeight.w800,
              color: _muted,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: Text(
              complaint.description,
              style: _labelStyle(
                size: 13,
                weight: FontWeight.w500,
                color: _text,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadedImagesSection(Complaint complaint) {
    final hasMedia = complaint.media != null && complaint.media!.isNotEmpty;
    final hasThumbnail =
        complaint.thumbnail != null && complaint.thumbnail!.isNotEmpty;
    final mediaCount = complaint.mediaCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.photo_library,
                    color: Colors.purple.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppStrings.t(context, 'Uploaded Images'),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
              ),
              if (mediaCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(14),
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
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _line, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFFF7F8FA),
                            child: const Icon(Icons.broken_image,
                                color: _muted, size: 32),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: const Color(0xFFF7F8FA),
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
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
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
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
                                        const Icon(Icons.error_outline,
                                            color: Colors.white, size: 48),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Failed to load image',
                                          style: GoogleFonts.inter(
                                              color: Colors.white),
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
                              icon: const Icon(Icons.close,
                                  color: Colors.white, size: 28),
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
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _line, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        complaint.thumbnail!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: const Color(0xFFF7F8FA),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    color: Colors.purple.shade700,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Loading image...',
                                    style: GoogleFonts.inter(
                                      color: _muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint(
                              'Error loading thumbnail: ${complaint.thumbnail}');
                          debugPrint('Error: $error');
                          return Container(
                            color: const Color(0xFFF7F8FA),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.broken_image,
                                      color: _muted, size: 48),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Failed to load image',
                                    style: GoogleFonts.inter(
                                      color: _muted,
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.zoom_in,
                                  color: Colors.white, size: 16),
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
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.amber.shade300, width: 2),
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload,
                      size: 56, color: Colors.amber.shade700),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder,
                            size: 16, color: Colors.amber.shade900),
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

  Widget _buildAdditionalFieldsCard(
      List<ComplaintFieldResponse> fieldResponses) {
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
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...additionalFields.asMap().entries.map((entry) {
            final index = entry.key;
            final field = entry.value;
            return Column(
              children: [
                if (index > 0) const SizedBox(height: 12),
                _buildInfoRow(Icons.arrow_right, field.fieldLabel, field.value),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: _accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: _labelStyle(
                    size: 11,
                    weight: FontWeight.w700,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: _labelStyle(
                    size: 13,
                    weight: FontWeight.w700,
                    color: _text,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(Complaint complaint) {
    final complaintPos = LatLng(complaint.latitude, complaint.longitude);
    final dept = complaint.assignedDepartment;
    final hasDept =
        dept != null && dept.latitude != 0.0 && dept.longitude != 0.0;
    final deptPos = hasDept ? LatLng(dept.latitude, dept.longitude) : null;

    final points = [complaintPos, if (deptPos != null) deptPos];
    final bounds = LatLngBounds.fromPoints(points);
    final fit = CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.all(80),
      maxZoom: 15,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
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
                    borderRadius: BorderRadius.circular(14),
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
                          color: _text,
                        ),
                      ),
                      Text(
                        hasDept
                            ? AppStrings.t(
                                context, 'Route: Complaint Site → Department')
                            : AppStrings.t(context, 'Complaint location'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _muted,
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
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _line),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
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
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                          child: const Icon(Icons.location_on,
                              color: Colors.white, size: 24),
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
                            child: const Icon(Icons.business,
                                color: Colors.white, size: 24),
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
                _buildLegendItem(const Color(0xFFEF4444),
                    AppStrings.t(context, 'Complaint Site')),
                if (hasDept) ...[
                  const SizedBox(width: 20),
                  const Icon(Icons.arrow_forward, size: 16, color: _accent),
                  const SizedBox(width: 20),
                  _buildLegendItem(
                      _accent, AppStrings.t(context, 'Department')),
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
            color: _muted,
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentCard(Department dept) {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.business, color: _accent, size: 20),
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
                        color: _muted,
                      ),
                    ),
                    Text(
                      dept.name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _text,
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
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: Column(
              children: [
                if (dept.phone.isNotEmpty) ...[
                  _buildDeptInfoRow(Icons.phone, dept.phone, _text),
                  const SizedBox(height: 8),
                ],
                if (dept.email.isNotEmpty) ...[
                  _buildDeptInfoRow(Icons.email, dept.email, _text),
                  const SizedBox(height: 8),
                ],
                if (dept.address.isNotEmpty)
                  _buildDeptInfoRow(Icons.location_on, dept.address, _text),
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
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            isCompleted: status == 'confirmed' ||
                status == 'process' ||
                status == 'solved' ||
                status == 'resolved' ||
                status == 'reopened',
          ),
          _buildTimelineStep(
            'In Progress',
            '',
            Icons.engineering,
            const Color(0xFF2F80ED),
            isCompleted: status == 'process' ||
                status == 'solved' ||
                status == 'resolved' ||
                status == 'reopened',
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
    Color color, {
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
                color: isCompleted ? color : const Color(0xFFE4E7EC),
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
                color: isCompleted ? color : const Color(0xFFE4E7EC),
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
                    color: isCompleted ? _text : _muted,
                  ),
                ),
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _muted,
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
    if (complaint.resolutionProofs != null &&
        complaint.resolutionProofs!.isNotEmpty) {
      return complaint.resolutionProofs!;
    }
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

  String _resolveReopenProofUrl(ComplaintReopenProof proof) {
    final proofUrl = proof.proofUrl.trim();
    if (proofUrl.isNotEmpty) return proofUrl;

    final file = proof.proof.trim();
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

  Widget _buildReopenProofSection(List<ComplaintReopenProof> proofs) {
    return Column(
      children: [
        for (int i = 0; i < proofs.length; i++) ...[
          _reopenProofCard(proofs[i]),
          if (i != proofs.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _reopenProofCard(ComplaintReopenProof proof) {
    final proofUrl = _resolveReopenProofUrl(proof);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restart_alt_rounded,
                  color: Color(0xFFB45309), size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  proof.requestedByName.isEmpty
                      ? AppStrings.t(context, 'Reopen Request')
                      : proof.requestedByName,
                  style: _labelStyle(
                    size: 13.5,
                    weight: FontWeight.w900,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ),
              if (proof.createdAt != null)
                Text(
                  proof.createdAt!.toString().split(' ')[0],
                  style: _labelStyle(
                    size: 11,
                    weight: FontWeight.w700,
                    color: const Color(0xFFB45309),
                  ),
                ),
            ],
          ),
          if (proof.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              proof.reason.trim(),
              style: _labelStyle(
                size: 13,
                weight: FontWeight.w600,
                color: const Color(0xFF78350F),
                height: 1.35,
              ),
            ),
          ],
          if (proofUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _viewReopenProof(proof),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    proofUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFFF7F8FA),
                        child: const Icon(Icons.broken_image,
                            color: _muted, size: 34),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaSection(String title, List<ComplaintMedia> media) {
    if (media.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.verified,
                    color: Colors.green.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(14),
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
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.green.shade200, width: 1.2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFFF7F8FA),
                              child: const Icon(Icons.broken_image,
                                  color: _muted, size: 32),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: const Color(0xFFF7F8FA),
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
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
                            child: const Icon(Icons.verified,
                                color: Colors.white, size: 12),
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
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
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
                            const Icon(Icons.error_outline,
                                color: Colors.white, size: 48),
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

  void _viewReopenProof(ComplaintReopenProof proof) {
    final proofUrl = _resolveReopenProofUrl(proof);
    if (proofUrl.isEmpty) return;

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
                    proofUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          AppStrings.t(context, 'Failed to load image'),
                          style: GoogleFonts.inter(color: Colors.white),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.t(context, 'Your Rating'),
              style: _labelStyle(
                  size: 14,
                  weight: FontWeight.w800,
                  color: const Color(0xFF92400E))),
          const SizedBox(height: 8),
          Row(
              children: List.generate(
                  5,
                  (i) => Icon(
                        i < r ? Icons.star : Icons.star_border,
                        color: const Color(0xFFF59E0B),
                        size: 26,
                      ))),
          if (complaint.citizenFeedback != null &&
              complaint.citizenFeedback!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(complaint.citizenFeedback!,
                style: _labelStyle(
                    size: 13,
                    weight: FontWeight.w500,
                    color: const Color(0xFF78350F),
                    height: 1.35)),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingForm(Complaint complaint) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.t(context, 'Rate This Resolution'),
              style: _titleStyle(size: 15)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                5,
                (i) => GestureDetector(
                      onTap: () => setState(() => _selectedRating = i + 1),
                      child: Icon(
                        i < _selectedRating ? Icons.star : Icons.star_border,
                        size: 34,
                        color: const Color(0xFF2F80ED),
                      ),
                    )),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: AppStrings.t(context, 'Comment (optional)'),
              filled: true,
              fillColor: Colors.white,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _accent),
              ),
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
                backgroundColor: const Color(0xFF2F80ED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: _isSubmittingRating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(AppStrings.t(context, 'Submit Rating'),
                      style: _labelStyle(
                          size: 14,
                          weight: FontWeight.w800,
                          color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReopenButton(Complaint complaint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _showReopenDialog(complaint),
          icon: const Icon(Icons.refresh),
          label: Text(AppStrings.t(context, 'Reopen Complaint'),
              style: _labelStyle(
                  size: 14, weight: FontWeight.w800, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
    );
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppStrings.t(context, 'Reopen Complaint'),
                        style: _titleStyle(size: 19)),
                    IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: _dark)),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('#${complaint.complaintNumber}',
                      style: _labelStyle(
                          size: 13,
                          weight: FontWeight.w800,
                          color: const Color(0xFFEF4444))),
                ),
                const SizedBox(height: 16),
                Text('${AppStrings.t(context, 'Reason for reopening:')} *',
                    style: _labelStyle(
                        size: 13, weight: FontWeight.w800, color: _text)),
                const SizedBox(height: 8),
                TextField(
                  controller: _reopenReasonCtrl,
                  maxLines: 4,
                  onChanged: (_) => setDlg(() {}),
                  decoration: InputDecoration(
                    hintText: AppStrings.t(
                        context, 'Describe why you want to reopen...'),
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _accent),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),
                Text('${AppStrings.t(context, 'Attach Photo Proof')} *',
                    style: _labelStyle(
                        size: 13, weight: FontWeight.w800, color: _text)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final img = await ImagePicker()
                        .pickImage(source: ImageSource.gallery);
                    if (img != null) setDlg(() => _reopenProofPath = img.path);
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: _line, width: 1.4),
                      borderRadius: BorderRadius.circular(18),
                      color: const Color(0xFFF7F8FA),
                    ),
                    child: _reopenProofPath != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.file(File(_reopenProofPath!),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: GestureDetector(
                                  onTap: () =>
                                      setDlg(() => _reopenProofPath = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate_rounded,
                                  size: 36, color: _muted),
                              const SizedBox(height: 6),
                              Text(AppStrings.t(context, 'Tap to add photo'),
                                  style: _labelStyle(
                                      size: 12,
                                      weight: FontWeight.w600,
                                      color: _muted)),
                            ],
                          ),
                  ),
                ),

                // Preview Section
                if (_reopenReasonCtrl.text.trim().isNotEmpty ||
                    _reopenProofPath != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.preview,
                                color: Color(0xFF92400E), size: 18),
                            const SizedBox(width: 8),
                            Text(AppStrings.t(context, 'Preview'),
                                style: _labelStyle(
                                    size: 13,
                                    weight: FontWeight.w800,
                                    color: const Color(0xFF92400E))),
                          ],
                        ),
                        if (_reopenReasonCtrl.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(AppStrings.t(context, 'Reason:'),
                              style: _labelStyle(
                                  size: 11,
                                  weight: FontWeight.w800,
                                  color: const Color(0xFF78350F))),
                          const SizedBox(height: 4),
                          Text(_reopenReasonCtrl.text.trim(),
                              style: _labelStyle(
                                  size: 13,
                                  weight: FontWeight.w500,
                                  color: const Color(0xFF92400E),
                                  height: 1.35)),
                        ],
                        if (_reopenProofPath != null) ...[
                          const SizedBox(height: 12),
                          Text(AppStrings.t(context, 'Proof Image:'),
                              style: _labelStyle(
                                  size: 11,
                                  weight: FontWeight.w800,
                                  color: const Color(0xFF78350F))),
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
                    onPressed: _reopenReasonCtrl.text.trim().isNotEmpty &&
                            _reopenProofPath != null &&
                            !_isSubmittingReopen
                        ? () => _submitReopen(ctx, complaint)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    child: _isSubmittingReopen
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(AppStrings.t(context, 'Submit Reopen Request'),
                            style: _labelStyle(
                                size: 14,
                                weight: FontWeight.w800,
                                color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitReopen(
      BuildContext dialogCtx, Complaint complaint) async {
    if (_isSubmittingReopen) return;
    if (_reopenProofPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.t(context, 'Photo proof is required')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingCtx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: _accent),
                const SizedBox(height: 16),
                Text(
                  _reopenProofPath != null
                      ? AppStrings.t(context, 'Uploading proof...')
                      : AppStrings.t(context, 'Submitting request...'),
                  style: _labelStyle(
                      size: 14, weight: FontWeight.w600, color: _text),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    setState(() => _isSubmittingReopen = true);
    try {
      final provider = Provider.of<ComplaintProvider>(context, listen: false);
      final ok = await provider.reopenComplaint(
        complaint.id,
        _reopenReasonCtrl.text.trim(),
        File(_reopenProofPath!),
      );

      setState(() => _isSubmittingReopen = false);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (!mounted) return;

      if (ok) {
        // Close reopen dialog
        if (dialogCtx.mounted) {
          Navigator.pop(dialogCtx);
        }

        // Clear form
        _reopenReasonCtrl.clear();
        setState(() => _reopenProofPath = null);

        // Reload complaint details
        await provider.loadComplaintDetail(complaint.id);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppStrings.t(context, 'Complaint reopened successfully!')),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Show error message
        final errorMsg = provider.error ??
            AppStrings.t(context, 'Failed to submit reopen request');
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
      {
        'rating': _selectedRating.toString(),
        'feedback': _commentCtrl.text.trim()
      },
    );
    setState(() => _isSubmittingRating = false);
    if (!mounted) return;
    if (res['success'] == true) {
      Provider.of<ComplaintProvider>(context, listen: false)
          .loadComplaintDetail(complaint.id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(AppStrings.t(context, 'Rating submitted successfully!')),
          backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message'] ?? AppStrings.t(context, 'Failed')),
          backgroundColor: Colors.red));
    }
  }
}

// ── Department tap popup ────────────────────────────────────────────────────
// ── Status chip ─────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  final String statusText;
  const _StatusChip({required this.status, required this.statusText});

  @override
  Widget build(BuildContext context) {
    Color color = const Color(0xFF5B6B86);
    switch (status.toLowerCase()) {
      case 'submitted':
      case 'pending':
        color = const Color(0xFF2F80ED);
        break;
      case 'assigned':
      case 'confirmed':
        color = const Color(0xFF3478F6);
        break;
      case 'in-progress':
      case 'in_progress':
      case 'process':
        color = Colors.indigo;
        break;
      case 'resolved':
      case 'solved':
        color = const Color(0xFF22C55E);
        break;
      case 'reopened':
      case 'rejected':
        color = const Color(0xFFEF4444);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(AppStrings.t(context, statusText),
          style: GoogleFonts.inter(
              color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}
