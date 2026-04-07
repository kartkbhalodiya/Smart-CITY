import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/complaint.dart';
import '../../l10n/app_strings.dart';
import 'complaint_detail_screen.dart';
import '../../widgets/app_bottom_nav.dart';

class UserTrackScreen extends StatefulWidget {
  const UserTrackScreen({super.key});
  @override
  State<UserTrackScreen> createState() => _UserTrackScreenState();
}

class _UserTrackScreenState extends State<UserTrackScreen> with TickerProviderStateMixin {
  static const _accent = Color(0xFFFF6B35);
  static const _dark = Color(0xFF1A1A1A);
  static const _bg = Color(0xFFF8F9FA);

  String _selectedFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _filterTabs = [
    {'key': 'all', 'label': 'All', 'icon': Icons.list_alt, 'color': _accent},
    {'key': 'pending', 'label': 'Pending', 'icon': Icons.pending, 'color': Color(0xFFEAB308)},
    {'key': 'solved', 'label': 'Solved', 'icon': Icons.verified, 'color': Color(0xFF22C55E)},
    {'key': 'reopened', 'label': 'Reopened', 'icon': Icons.refresh, 'color': Color(0xFFEF4444)},
    {'key': 'rejected', 'label': 'Rejected', 'icon': Icons.cancel, 'color': Color(0xFF991B1B)},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Force load complaints when screen opens
      _loadUserComplaints();
    });
  }

  Future<void> _loadUserComplaints() async {
    final provider = context.read<ComplaintProvider>();
    // Set loading state immediately
    if (provider.complaints.isEmpty && !provider.isLoading) {
      await provider.loadComplaints();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildHeaderCard(user),
            ),
            const SizedBox(height: 10),
            _buildSearchAndFilters(),
            Expanded(child: _buildComplaintsList()),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  Widget _buildHeaderCard(dynamic user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3E3E3E), Color(0xFF5A5A5A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.track_changes_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.t(context, 'Track Complaints'),
                  style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                Text(
                  AppStrings.t(context, 'Monitor your complaint status'),
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.82)),
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 17,
            backgroundColor: _accent,
            child: Text(
              _getUserInitials(user),
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final provider = context.watch<ComplaintProvider>();
    final complaints = provider.complaints;
    final filterCounts = <String, int>{
      'all': complaints.length,
      'pending': complaints.where((c) => c.workStatus == 'pending').length,
      'solved': complaints.where((c) => c.workStatus == 'solved').length,
      'reopened': complaints.where((c) => c.workStatus == 'reopened').length,
      'rejected': complaints.where((c) => c.workStatus == 'rejected').length,
    };

    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEEEEEE)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _filterComplaints();
              },
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0f172a)),
              decoration: InputDecoration(
                hintText: AppStrings.t(context, 'Search by complaint ID, type, or location...'),
                hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748b)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748b), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF64748b), size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _filterComplaints();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Modern quick stats row
          _buildQuickStats(),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filterTabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tab = _filterTabs[index];
                final key = tab['key'] as String;
                final selected = _selectedFilter == key;
                final count = filterCounts[key] ?? 0;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedFilter = key);
                    _filterComplaints();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? _dark : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? _dark : const Color(0xFFEAEAEA),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab['icon'] as IconData,
                          size: 15,
                          color: selected ? Colors.white : const Color(0xFF555555),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppStrings.t(context, tab['label'] as String),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : const Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: selected ? _accent : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : const Color(0xFF5B5B5B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Consumer<ComplaintProvider>(
      builder: (context, provider, _) {
        final complaints = provider.complaints;
        final stats = <Map<String, dynamic>>[
          {
            'label': AppStrings.t(context, 'Total'),
            'count': complaints.length,
            'icon': Icons.summarize_rounded,
            'color': _accent,
          },
          {
            'label': AppStrings.t(context, 'Solved'),
            'count': complaints.where((c) => c.workStatus == 'solved').length,
            'icon': Icons.verified_rounded,
            'color': const Color(0xFF22C55E),
          },
          {
            'label': AppStrings.t(context, 'Pending'),
            'count': complaints.where((c) => c.workStatus == 'pending').length,
            'icon': Icons.schedule_rounded,
            'color': const Color(0xFFEAB308),
          },
        ];

        return SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: stats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = stats[index];
              return _buildStatCard(
                label: item['label'] as String,
                count: item['count'] as int,
                icon: item['icon'] as IconData,
                color: item['color'] as Color,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$count',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintsList() {
    return Consumer<ComplaintProvider>(
      builder: (context, provider, _) {
        final allComplaints = provider.complaints;
        final isInitialLoad = allComplaints.isEmpty && !provider.isLoading && provider.error == null;
        
        // Show loading indicator while fetching data OR on initial load
        if (provider.isLoading || isInitialLoad) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: _accent,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.t(context, 'Loading your complaints...'),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748b),
                  ),
                ),
              ],
            ),
          );
        }

        // Show error if there's one
        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Color(0xFFEF4444)),
                const SizedBox(height: 16),
                Text(
                  AppStrings.t(context, 'Error loading complaints'),
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0f172a),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  provider.error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748b),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadUserComplaints,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dark,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    AppStrings.t(context, 'Retry'),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final filteredComplaints = _getFilteredComplaints(allComplaints);

        // Only show empty state if not loading and no complaints
        if (filteredComplaints.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          color: _accent,
          onRefresh: _loadUserComplaints,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredComplaints.length,
            itemBuilder: (context, index) {
              return _buildComplaintCard(filteredComplaints[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildComplaintCard(Complaint complaint) {
    final statusColor = _getStatusColor(complaint.workStatus);
    final statusText = AppStrings.t(context, _getStatusText(complaint.workStatus));
    final priorityColor = _getPriorityColor(complaint.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            // Show loading dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext dialogContext) {
                return WillPopScope(
                  onWillPop: () async => false,
                  child: Dialog(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            AppStrings.t(context, 'Loading complaint details...'),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF374151),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );

            // Small delay to ensure dialog is shown
            await Future.delayed(const Duration(milliseconds: 100));

            // Navigate to detail screen
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ComplaintDetailScreen(
                  complaintId: complaint.id,
                ),
              ),
            );

            // Close loading dialog when returning from detail screen
            if (mounted) {
              Navigator.of(context).pop();
              
              // Refresh complaints list when returning
              await _loadUserComplaints();
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top line: ID + status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: const Color(0xFFE7E7E7)),
                      ),
                      child: Text(
                        '#${complaint.complaintNumber}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        statusText,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: priorityColor.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        complaint.priority.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: priorityColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Main title block
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFECECEC)),
                      ),
                      child: Center(
                        child: Text(
                          _getCategoryEmoji(complaint.complaintType),
                          style: const TextStyle(fontSize: 21),
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
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0f172a),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _localizedComplaintType(complaint),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748b),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Subcategory if available
                if (complaint.subcategory != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _accent.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.category, size: 14, color: _accent),
                            const SizedBox(width: 6),
                            Text(
                              _localizedSubcategory(complaint.subcategory),
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 10),
                
                // Description
                Text(
                  complaint.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: const Color(0xFF64748b),
                    height: 1.4,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Location and Time info strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEDEDED)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Color(0xFF64748b)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${complaint.city}, ${complaint.pincode ?? complaint.state}',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF64748b),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF64748b)),
                      const SizedBox(width: 4),
                      Text(
                        AppStrings.t(context, _formatDate(complaint.createdAt.toIso8601String())),
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF64748b),
                        ),
                      ),
                    ],
                  ),
                ),

                // Department Assignment Info
                if (complaint.assignedDepartment != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCFCFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.business, size: 18, color: _accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.t(context, 'Assigned Department'),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF64748b),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                complaint.assignedDepartment!.name,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.location_on, size: 14, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Rating and Reopen Section
                if (complaint.workStatus == 'solved' || complaint.workStatus == 'resolved') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Rating Display
                      if (complaint.citizenRating != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 12, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 4),
                              Text(
                                '${complaint.citizenRating}/5',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Reopen Button
                      if (complaint.workStatus == 'solved' || complaint.workStatus == 'resolved') ...[
                        GestureDetector(
                          onTap: () => _showReopenDialog(context, complaint),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFEF4444)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.refresh, size: 12, color: Color(0xFFEF4444)),
                                const SizedBox(width: 4),
                                Text(
                                  AppStrings.t(context, 'Reopen'),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 64,
            color: Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'all'
                ? AppStrings.t(context, 'No complaints found')
                : '${AppStrings.t(context, 'No')} ${AppStrings.t(context, _getStatusText(_selectedFilter))} ${AppStrings.t(context, 'complaints')}',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0f172a),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? AppStrings.t(context, 'Try adjusting your search terms')
                : _selectedFilter == 'all'
                    ? AppStrings.t(context, "You haven't submitted any complaints yet")
                    : '${AppStrings.t(context, 'No complaints with status')} ${AppStrings.t(context, _getStatusText(_selectedFilter))}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF64748b),
            ),
          ),
          if (_selectedFilter == 'all' && _searchQuery.isEmpty) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _dark,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                AppStrings.t(context, 'Submit Your First Complaint'),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Complaint> _getFilteredComplaints(List<Complaint> complaints) {
    var filtered = complaints;

    // Filter by status
    if (_selectedFilter != 'all') {
      filtered = filtered.where((c) => c.workStatus == _selectedFilter).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((c) =>
          c.complaintNumber.toLowerCase().contains(query) ||
          c.complaintType.toLowerCase().contains(query) ||
          c.description.toLowerCase().contains(query) ||
          c.city.toLowerCase().contains(query) ||
          (c.subcategory?.toLowerCase().contains(query) ?? false)).toList();
    }

    // Sort by creation date (newest first)
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return filtered;
  }

  void _filterComplaints() {
    // Don't call API again, just trigger UI update
    // The filtering is done in _getFilteredComplaints method
    setState(() {});
  }

  String _getUserInitials(user) {
    if (user == null) return 'U';
    final firstName = user.firstName?.trim() ?? '';
    final lastName = user.lastName?.trim() ?? '';
    String initials = '';
    if (firstName.isNotEmpty) initials += firstName[0].toUpperCase();
    if (lastName.isNotEmpty) initials += lastName[0].toUpperCase();
    return initials.isEmpty ? 'U' : initials;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return const Color(0xFFEAB308);
      case 'confirmed': return const Color(0xFFF97316);
      case 'process': return _accent;
      case 'in_progress': return _accent;
      case 'solved': return const Color(0xFF22C55E);
      case 'reopened': return const Color(0xFFEF4444);
      case 'rejected': return const Color(0xFF991B1B);
      default: return const Color(0xFF94A3B8);
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return 'Pending';
      case 'confirmed': return 'Confirmed';
      case 'process': return 'In Progress';
      case 'in_progress': return 'In Progress';
      case 'solved': return 'Solved';
      case 'reopened': return 'Reopened';
      case 'rejected': return 'Rejected';
      default: return 'Unknown';
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high': return const Color(0xFFEF4444);
      case 'medium': return const Color(0xFFEAB308);
      case 'low': return const Color(0xFF22C55E);
      default: return const Color(0xFF64748b);
    }
  }

  String _localizedComplaintType(Complaint complaint) {
    final display = complaint.complaintTypeDisplay.trim();
    if (display.isNotEmpty) {
      return AppStrings.t(context, display);
    }

    return AppStrings.t(context, _categoryKeyToText(complaint.complaintType));
  }

  String _localizedSubcategory(String? subcategory) {
    final value = (subcategory ?? '').trim();
    if (value.isEmpty) {
      return AppStrings.t(context, 'Other');
    }
    return AppStrings.t(context, value);
  }

  String _categoryKeyToText(String categoryKey) {
    switch (categoryKey.toLowerCase()) {
      case 'police':
        return 'Police';
      case 'traffic':
        return 'Traffic';
      case 'construction':
        return 'Construction';
      case 'water':
      case 'water supply':
        return 'Water Supply';
      case 'electricity':
        return 'Electricity';
      case 'garbage':
        return 'Garbage';
      case 'road':
      case 'pothole':
        return 'Road / Pothole';
      case 'drainage':
        return 'Drainage';
      case 'illegal':
      case 'illegal activity':
        return 'Illegal Activity';
      case 'transportation':
        return 'Transportation';
      case 'cyber':
      case 'cyber crime':
        return 'Cyber Crime';
      default:
        return categoryKey;
    }
  }

  String _getCategoryEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'police': return '🚓';
      case 'traffic': return '🚦';
      case 'construction': return '🏗️';
      case 'water': case 'water supply': return '🚰';
      case 'electricity': return '💡';
      case 'garbage': return '🗑️';
      case 'road': case 'pothole': return '🛣️';
      case 'drainage': return '🌊';
      case 'illegal': case 'illegal activity': return '⚠️';
      case 'transportation': return '🚌';
      case 'cyber': case 'cyber crime': return '🛡️';
      default: return '📋';
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return dateStr;
    }
  }

  void _showReopenDialog(BuildContext context, Complaint complaint) {
    final reasonController = TextEditingController();
    String? proofPath;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (ctx, setDlg) => Container(
          height: MediaQuery.of(ctx).size.height * 0.78,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.t(context, 'Reopen Complaint'),
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(bottomSheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${AppStrings.t(context, 'Complaint ID')} #${complaint.complaintNumber}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '${AppStrings.t(context, 'Reason for reopening:')} *',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 4,
                  onChanged: (_) => setDlg(() {}),
                  decoration: InputDecoration(
                    hintText: AppStrings.t(context, 'Please explain why you want to reopen this complaint...'),
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF9CA3AF),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2B6CF6)),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${AppStrings.t(context, 'Upload Proof Image')} *',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (img != null) setDlg(() => proofPath = img.path);
                  },
                  child: Container(
                    height: 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFF9FAFB),
                    ),
                    child: proofPath != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(proofPath!),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => setDlg(() => proofPath = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
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
                              Text(
                                AppStrings.t(context, 'Tap to add proof image'),
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(bottomSheetContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B7280),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          AppStrings.t(context, 'Cancel'),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: reasonController.text.trim().isNotEmpty && proofPath != null
                            ? () => _submitReopenRequest(bottomSheetContext, complaint, reasonController.text.trim(), proofPath!)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          AppStrings.t(context, 'Submit'),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitReopenRequest(
    BuildContext bottomSheetContext,
    Complaint complaint,
    String reason,
    String proofPath,
  ) async {
    Navigator.pop(bottomSheetContext); // Close dialog
    
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              AppStrings.t(context, 'Submitting reopen request...'),
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2B6CF6),
        duration: const Duration(seconds: 2),
      ),
    );
    
    try {
      final ok = await Provider.of<ComplaintProvider>(context, listen: false).reopenComplaint(
        complaint.id,
        reason,
        File(proofPath),
      );
      
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.t(context, 'Reopen request submitted successfully!'),
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        await _loadUserComplaints();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.t(context, 'Failed to submit reopen request. Please try again.'),
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.t(context, 'Failed to submit reopen request. Please try again.'),
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }
}
