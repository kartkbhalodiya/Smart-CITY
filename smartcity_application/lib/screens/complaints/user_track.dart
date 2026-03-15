import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/complaint.dart';

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
    {'key': 'pending', 'label': 'Pending', 'icon': Icons.pending, 'color': Color(0xFFEF4444)},
    {'key': 'confirmed', 'label': 'Confirmed', 'icon': Icons.check_circle, 'color': Color(0xFFF97316)},
    {'key': 'process', 'label': 'In Progress', 'icon': Icons.autorenew, 'color': Color(0xFFEAB308)},
    {'key': 'solved', 'label': 'Solved', 'icon': Icons.verified, 'color': Color(0xFF22C55E)},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filterTabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ComplaintProvider>().loadComplaints();
    });
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
            'Track Complaints',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0f172a),
            ),
          ),
          Text(
            'Monitor your complaint status',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748b),
            ),
          ),
        ],
      ),
      actions: [
        // User avatar
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
                hintText: 'Search by complaint ID, type, or location...',
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
          'total': complaints.length,
          'pending': complaints.where((c) => c.workStatus == 'pending').length,
          'process': complaints.where((c) => c.workStatus == 'process').length,
          'solved': complaints.where((c) => c.workStatus == 'solved').length,
        };

        return Row(
          children: [
            _buildStatChip('Total', stats['total']!, const Color(0xFF1E66F5)),
            const SizedBox(width: 8),
            _buildStatChip('Pending', stats['pending']!, const Color(0xFFEF4444)),
            const SizedBox(width: 8),
            _buildStatChip('Progress', stats['process']!, const Color(0xFFEAB308)),
            const SizedBox(width: 8),
            _buildStatChip('Solved', stats['solved']!, const Color(0xFF22C55E)),
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
              Text(tab['label'] as String),
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

        final filteredComplaints = _getFilteredComplaints(provider.complaints);

        if (filteredComplaints.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          color: const Color(0xFF1E66F5),
          onRefresh: () => provider.loadComplaints(),
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
    final statusText = _getStatusText(complaint.workStatus);
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
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.complaintDetail,
            arguments: {'complaintId': complaint.id},
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        complaint.priority.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: priorityColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '#${complaint.complaintNumber}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748b),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Title and category
                Row(
                  children: [
                    Text(
                      _getCategoryEmoji(complaint.complaintType),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            complaint.complaintType,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0f172a),
                            ),
                          ),
                          if (complaint.subcategory != null)
                            Text(
                              complaint.subcategory!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF64748b),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 12),
                // Location and time
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: const Color(0xFF64748b)),
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
                    const SizedBox(width: 8),
                    Icon(Icons.access_time, size: 16, color: const Color(0xFF64748b)),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(complaint.createdAt.toIso8601String()),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748b),
                      ),
                    ),
                  ],
                ),
                // Department info if assigned
                if (complaint.assignedDepartment != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.business, size: 16, color: const Color(0xFF1E66F5)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Assigned to ${complaint.assignedDepartment!.name}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E66F5),
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 12, color: const Color(0xFF64748b)),
                      ],
                    ),
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
            _selectedFilter == 'all' ? 'No complaints found' : 'No ${_selectedFilter} complaints',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0f172a),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search terms'
                : 'Submit your first complaint to get started',
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
                'Submit Complaint',
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
    context.read<ComplaintProvider>().loadComplaints(
      workStatus: _selectedFilter == 'all' ? null : _selectedFilter,
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );
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
      case 'pending': return const Color(0xFFEF4444);
      case 'confirmed': return const Color(0xFFF97316);
      case 'process': return const Color(0xFFEAB308);
      case 'solved': return const Color(0xFF22C55E);
      case 'reopened': return const Color(0xFF991B1B);
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
}