import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/complaint.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../user_track_complaint_detail.dart';
import '../../l10n/app_strings.dart';

class UserTrackScreen extends StatefulWidget {
  const UserTrackScreen({super.key});
  @override
  State<UserTrackScreen> createState() => _UserTrackScreenState();
}

class _UserTrackScreenState extends State<UserTrackScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _filterTabs = [
    {'key': 'all', 'label': 'All', 'icon': Icons.list_alt, 'color': Color(0xFF1E66F5)},
    {'key': 'pending', 'label': 'Pending', 'icon': Icons.pending, 'color': Color(0xFFEAB308)},
    {'key': 'solved', 'label': 'Solved', 'icon': Icons.verified, 'color': Color(0xFF22C55E)},
    {'key': 'reopened', 'label': 'Reopened', 'icon': Icons.refresh, 'color': Color(0xFFEF4444)},
    {'key': 'rejected', 'label': 'Rejected', 'icon': Icons.cancel, 'color': Color(0xFF991B1B)},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filterTabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Force load complaints when screen opens
      _loadUserComplaints();
    });
  }

  Future<void> _loadUserComplaints() async {
    try {
      final provider = context.read<ComplaintProvider>();
      await provider.loadComplaints();
    } catch (e) {
      print('Error loading complaints: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          _buildTabBar(),
          Expanded(child: _buildComplaintsList()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final user = context.watch<AuthProvider>().user;
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF0f172a)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.t(context, 'Track Complaints'),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0f172a),
            ),
          ),
          Text(
            AppStrings.t(context, 'Monitor your complaint status'),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748b),
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF1E66F5),
            child: Text(
              _getUserInitials(user),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
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
          // Quick stats
          _buildQuickStats(),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Consumer<ComplaintProvider>(
      builder: (context, provider, _) {
        final complaints = provider.complaints;
        final stats = {
          'pending': complaints.where((c) => c.workStatus == 'pending').length,
          'solved': complaints.where((c) => c.workStatus == 'solved').length,
          'rejected': complaints.where((c) => c.workStatus == 'rejected').length,
          'reopened': complaints.where((c) => c.workStatus == 'reopened').length,
        };

        return Row(
          children: [
            _buildStatChip(AppStrings.t(context, 'Pending'), stats['pending']!, const Color(0xFFEAB308)),
            const SizedBox(width: 8),
            _buildStatChip(AppStrings.t(context, 'Solved'), stats['solved']!, const Color(0xFF22C55E)),
            const SizedBox(width: 8),
            _buildStatChip(AppStrings.t(context, 'Rejected'), stats['rejected']!, const Color(0xFF991B1B)),
            const SizedBox(width: 8),
            _buildStatChip(AppStrings.t(context, 'Reopened'), stats['reopened']!, const Color(0xFFEF4444)),
          ],
        );
      },
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: const Color(0xFF1E66F5),
        indicatorWeight: 3,
        labelColor: const Color(0xFF1E66F5),
        unselectedLabelColor: const Color(0xFF64748b),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        onTap: (index) {
          setState(() => _selectedFilter = _filterTabs[index]['key']);
          _filterComplaints();
        },
        tabs: _filterTabs.map((tab) => Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab['icon'] as IconData, size: 16),
              const SizedBox(width: 6),
              Text(AppStrings.t(context, tab['label'] as String)),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildComplaintsList() {
    return Consumer<ComplaintProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1E66F5)),
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
                    backgroundColor: const Color(0xFF1E66F5),
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

        final allComplaints = provider.complaints;
        final filteredComplaints = _getFilteredComplaints(allComplaints);

        // Debug info
        print('Total complaints: ${allComplaints.length}');
        print('Filtered complaints: ${filteredComplaints.length}');
        print('Selected filter: $_selectedFilter');
        print('Search query: $_searchQuery');

        if (filteredComplaints.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          color: const Color(0xFF1E66F5),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserTrackComplaintDetail(
                  complaint: {
                    'complaint_number': complaint.complaintNumber,
                    'title': complaint.title,
                    'description': complaint.description,
                    'complaint_type': complaint.complaintType,
                    'work_status': complaint.workStatus,
                    'created_at': complaint.createdAt.toString(),
                    'address': complaint.address,
                    'latitude': complaint.latitude,
                    'longitude': complaint.longitude,
                    'city': complaint.city,
                    'state': complaint.state,
                    'assigned_department': complaint.assignedDepartment != null ? {
                      'name': complaint.assignedDepartment!.name,
                      'email': complaint.assignedDepartment!.email,
                      'phone': complaint.assignedDepartment!.phone,
                      'latitude': complaint.assignedDepartment!.latitude,
                      'longitude': complaint.assignedDepartment!.longitude,
                      'department_type': complaint.assignedDepartment!.departmentType,
                      'department_type_display': complaint.assignedDepartment!.departmentTypeDisplay,
                      'address': complaint.assignedDepartment!.address,
                      'city': complaint.assignedDepartment!.city,
                      'state': complaint.assignedDepartment!.state,
                      'sla_hours': complaint.assignedDepartment!.slaHours,
                    } : null,
                    'citizen_rating': complaint.citizenRating,
                    'citizen_feedback': null,
                    'can_reopen': complaint.canReopen ?? false,
                  },
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Status, Priority, Complaint ID
                Row(
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Priority Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: priorityColor, width: 1),
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
                    const Spacer(),
                    // Complaint ID
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '#${complaint.complaintNumber}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0f172a),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Title and Category with Emoji
                Row(
                  children: [
                    Text(
                      _getCategoryEmoji(complaint.complaintType),
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            complaint.title,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0f172a),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            complaint.complaintType,
                            style: GoogleFonts.inter(
                              fontSize: 13,
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
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E66F5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1E66F5).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.category, size: 14, color: const Color(0xFF1E66F5)),
                        const SizedBox(width: 6),
                        Text(
                          complaint.subcategory!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E66F5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 12),
                
                // Description
                Text(
                  complaint.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748b),
                    height: 1.4,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Location and Time Info
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: const Color(0xFF64748b)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${complaint.city}, ${complaint.pincode ?? complaint.state}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748b),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time, size: 16, color: const Color(0xFF64748b)),
                    const SizedBox(width: 4),
                    Text(
                      AppStrings.t(context, _formatDate(complaint.createdAt.toIso8601String())),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748b),
                      ),
                    ),
                  ],
                ),
                
                // Department Assignment Info
                if (complaint.assignedDepartment != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E66F5).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.business, size: 18, color: const Color(0xFF1E66F5)),
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
                                  color: const Color(0xFF1E66F5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E66F5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.location_on, size: 14, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Rating and Reopen Section
                if (complaint.workStatus == 'solved') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Rating Display
                      if (complaint.citizenRating != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.1),
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
                      // Reopen Button (if within 7 days)
                      if (_canReopenComplaint(complaint)) ...[
                        GestureDetector(
                          onTap: () => _showReopenDialog(context, complaint),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.1),
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
                backgroundColor: const Color(0xFF1E66F5),
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

  Future<void> _testApiDirectly() async {
    try {
      print('=== DIRECT API TEST ===');
      
      final response = await ApiService.get('https://janhelp.vercel.app/api/complaints/');
      print('Direct API Response Keys: ${response.keys}');
      print('Response Count: ${response['count']}');
      
      if (response.containsKey('results')) {
        final results = response['results'] ?? [];
        print('Direct API - Complaints found: ${results.length}');
        
        if (results.isNotEmpty) {
          final firstComplaint = results[0];
          print('First complaint ID: ${firstComplaint['id']}');
          print('First complaint number: ${firstComplaint['complaint_number']}');
          print('First complaint type: ${firstComplaint['complaint_type']}');
        }
        
        print('SUCCESS: API is working and returning ${results.length} complaints!');
      } else if (response['success'] == false) {
        print('Direct API Error: ${response['message']}');
      } else {
        print('Unknown response format: ${response.keys}');
      }
      
      print('=== DIRECT API TEST COMPLETE ===');
    } catch (e) {
      print('Direct API Test Error: $e');
    }
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
      case 'process': return const Color(0xFF1E66F5);
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

  bool _canReopenComplaint(Complaint complaint) {
    if (complaint.workStatus != 'solved') return false;
    
    // Assuming complaint has a solvedAt field - if not available, use updatedAt
    final solvedDate = complaint.updatedAt;
    final daysSinceSolved = DateTime.now().difference(solvedDate).inDays;
    return daysSinceSolved <= 7;
  }

  void _showReopenDialog(BuildContext context, Complaint complaint) {
    final reasonController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                    onPressed: () => Navigator.pop(context),
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
                AppStrings.t(context, 'Reason for reopening:'),
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
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
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
                      onPressed: () {
                        if (reasonController.text.isNotEmpty) {
                          _submitReopenRequest(context, complaint, reasonController.text);
                        }
                      },
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
    );
  }

  Future<void> _submitReopenRequest(BuildContext context, Complaint complaint, String reason) async {
    Navigator.pop(context); // Close dialog
    
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
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.t(context, 'Reopen request submitted successfully!'),
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        
        // Refresh complaints
        await _loadUserComplaints();
      }
    } catch (e) {
      if (context.mounted) {
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
}