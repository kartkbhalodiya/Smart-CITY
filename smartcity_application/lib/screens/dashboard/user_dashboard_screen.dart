import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/complaint_provider.dart';
import '../../models/complaint.dart';
import '../../l10n/app_strings.dart';
import '../ai_assistant/ai_call_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});
  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  int _tab = 0;
  int _navIndex = 0;
  int _notificationCount = 3; // Mock notification count
  List<Map<String, dynamic>> _notifications = [
    {
      'id': 1,
      'title': 'Complaint Status Updated',
      'message': 'Your complaint #COMP123 has been confirmed and assigned to Traffic Department.',
      'type': 'status_change',
      'time': '2 hours ago',
      'icon': Icons.check_circle,
      'color': Color(0xFF22C55E),
      'isRead': false,
    },
    {
      'id': 2,
      'title': 'Complaint In Progress',
      'message': 'Work has started on your road repair complaint #COMP124.',
      'type': 'status_change', 
      'time': '1 day ago',
      'icon': Icons.construction,
      'color': Color(0xFFEAB308),
      'isRead': false,
    },
    {
      'id': 3,
      'title': 'Complaint Resolved',
      'message': 'Your garbage collection complaint #COMP122 has been marked as solved.',
      'type': 'status_change',
      'time': '3 days ago', 
      'icon': Icons.verified,
      'color': Color(0xFF1E66F5),
      'isRead': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ComplaintProvider>().loadDashboardStats();
      context.read<ComplaintProvider>().loadComplaints();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(children: [
        _topNav(),
        Expanded(child: RefreshIndicator(
          color: const Color(0xFF1E66F5),
          onRefresh: () => context.read<ComplaintProvider>().refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(children: [
              _tabNav(),
              if (_tab == 0) _homeTab(),
              if (_tab == 1) _submitTab(),
            ]),
          ),
        )),
      ]),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _topNav() {
    final user = context.watch<AuthProvider>().user;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top, left: 16, right: 16, bottom: 12),
      child: Row(children: [
        Image.asset('assets/images/logo.png', height: 36),
        const SizedBox(width: 10),
        Text(AppStrings.t(context, 'Smart City'),
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
        const Spacer(),
        GestureDetector(
          onTap: _showNotifications,
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.notifications_outlined, size: 20, color: Color(0xFF64748b)),
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _notificationCount > 99 ? '99+' : _notificationCount.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // User avatar in top nav
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1E66F5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getUserInitials(user),
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _tabNav() {
    final tabs = [AppStrings.t(context, 'Home'), AppStrings.t(context, 'Submit')];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Row(
          children: List.generate(
              2,
              (i) => Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _tab = i;
                        _navIndex = i;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                            color: _tab == i ? const Color(0xFF1E66F5) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(tabs[i],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _tab == i ? Colors.white : const Color(0xFF64748b))),
                      ),
                    ),
                  ))),
    );
  }

  Widget _homeTab() {
    final stats = context.watch<ComplaintProvider>().stats;
    final isLoading = context.watch<ComplaintProvider>().isLoading;
    final user = context.watch<AuthProvider>().user;
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Welcome banner with user name
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1E66F5), Color(0xFF154ec7)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          // User avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getUserInitials(user),
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppStrings.t(context, 'Welcome back! 👋'),
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9))),
            const SizedBox(height: 2),
            Text(user?.fullName ?? AppStrings.t(context, 'User'),
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 2),
            Text(AppStrings.t(context, 'Track your complaints and view city statistics.'),
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white.withOpacity(0.85))),
          ])),
        ]),
      ),
      const SizedBox(height: 24),

      // Live Stats — real data without blur
      Row(children: [
        Text(AppStrings.t(context, 'Live Stats'),
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
        const SizedBox(width: 8),
        if (isLoading)
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E66F5))),
      ]),
      const SizedBox(height: 12),
      _statsGrid(stats, isLoading),
      const SizedBox(height: 24),

      // Departments
      Text(AppStrings.t(context, 'Departments'),
          style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
      const SizedBox(height: 12),
      _departmentsGrid(),
    ]);
  }

  String _getUserInitials(user) {
    if (user == null) return 'U';
    
    final firstName = user.firstName?.trim() ?? '';
    final lastName = user.lastName?.trim() ?? '';
    
    String initials = '';
    
    if (firstName.isNotEmpty) {
      initials += firstName[0].toUpperCase();
    }
    
    if (lastName.isNotEmpty) {
      initials += lastName[0].toUpperCase();
    }
    
    return initials.isEmpty ? 'U' : initials;
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications, color: Color(0xFF1E66F5), size: 24),
                  const SizedBox(width: 12),
                  Text(
                    AppStrings.t(context, 'Notifications'),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0f172a),
                    ),
                  ),
                  const Spacer(),
                  if (_notificationCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _notificationCount.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Color(0xFF64748b)),
                  ),
                ],
              ),
            ),
            // Notifications list
            Expanded(
              child: _notifications.isEmpty
                  ? _emptyNotifications()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return _notificationItem(notification, index);
                      },
                    ),
            ),
            // Clear all button
            if (_notifications.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _clearAllNotifications,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Text(
                      AppStrings.t(context, 'Clear All Notifications'),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748b),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _notificationItem(Map<String, dynamic> notification, int index) {
    final isRead = notification['isRead'] as bool;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRead ? const Color(0xFFE2E8F0) : const Color(0xFF1E66F5).withOpacity(0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _markAsRead(index),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (notification['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    notification['icon'] as IconData,
                    size: 20,
                    color: notification['color'] as Color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              AppStrings.t(context, notification['title'] as String),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0f172a),
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E66F5),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.t(context, notification['message'] as String),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF64748b),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.t(context, notification['time'] as String),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyNotifications() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.notifications_none,
            size: 64,
            color: Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.t(context, 'No notifications yet'),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0f172a),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.t(context, 'We\'ll notify you about complaint updates'),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF64748b),
            ),
          ),
        ],
      ),
    );
  }

  void _markAsRead(int index) {
    setState(() {
      _notifications[index]['isRead'] = true;
      _notificationCount = _notifications.where((n) => !n['isRead']).length;
    });
  }

  void _clearAllNotifications() {
    setState(() {
      _notifications.clear();
      _notificationCount = 0;
    });
    Navigator.pop(context);
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays > 0) return '${diff.inDays}${AppStrings.t(context, 'd ago')}';
      if (diff.inHours > 0) return '${diff.inHours}${AppStrings.t(context, 'h ago')}';
      if (diff.inMinutes > 0) return '${diff.inMinutes}${AppStrings.t(context, 'm ago')}';
      return AppStrings.t(context, 'Just now');
    } catch (e) {
      return dateStr;
    }
  }

  Widget _statsGrid(dynamic stats, bool isLoading) {
    final items = [
      {'emoji': '📊', 'label': AppStrings.t(context, 'Total Complaints'), 'count': stats?.totalComplaints ?? 0, 'color': const Color(0xFFEEF2FF)},
      {'emoji': '⏳', 'label': AppStrings.t(context, 'Pending'), 'count': stats?.pendingComplaints ?? 0, 'color': const Color(0xFFFFF1F2)},
      {'emoji': '✅', 'label': AppStrings.t(context, 'Solved'), 'count': stats?.resolvedComplaints ?? 0, 'color': const Color(0xFFF0FDF4)},
      {'emoji': '🔄', 'label': AppStrings.t(context, 'In Progress'), 'count': stats?.inProgressComplaints ?? 0, 'color': const Color(0xFFEFF6FF)},
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: items.map((item) => _statCard(item, isLoading)).toList(),
    );
  }

  Widget _statCard(Map item, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item['emoji'] as String, style: const TextStyle(fontSize: 36)),
        const Spacer(),
        if (isLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E66F5)),
          )
        else
          Text('${item['count']}',
              style: GoogleFonts.poppins(
                  fontSize: 26, fontWeight: FontWeight.w800, color: const Color(0xFF0f172a))),
        Text(item['label'] as String,
            style: GoogleFonts.inter(
                fontSize: 11, color: const Color(0xFF64748b), fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _departmentsGrid() {
    final depts = [
      {'emoji': '🚓', 'name': AppStrings.t(context, 'Police'), 'bg': const Color(0xFFEEF2FF)},
      {'emoji': '🚦', 'name': AppStrings.t(context, 'Traffic'), 'bg': const Color(0xFFFFF7ED)},
      {'emoji': '🏗️', 'name': AppStrings.t(context, 'Construction'), 'bg': const Color(0xFFF0F9FF)},
    ];
    return Column(children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: depts.map((d) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.departmentsList),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: d['bg'] as Color,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(d['emoji'] as String, style: const TextStyle(fontSize: 34)),
                const SizedBox(height: 6),
                Text(d['name'] as String,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: const Color(0xFF0f172a))),
              ]),
            ),
          ),
        ))).toList(),
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => Navigator.pushNamed(context, AppRoutes.departmentsList),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFF1E66F5).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E66F5).withOpacity(0.25)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(AppStrings.t(context, 'View All Departments'),
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E66F5))),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF1E66F5)),
          ]),
        ),
      ),
    ]);
  }

  Widget _submitTab() {
    final categories = [
      {'emoji': '🚓', 'name': AppStrings.t(context, 'Police'),          'key': 'police',         'bg': const Color(0xFFEEF2FF)},
      {'emoji': '🚦', 'name': AppStrings.t(context, 'Traffic'),         'key': 'traffic',        'bg': const Color(0xFFFFF7ED)},
      {'emoji': '🏗️', 'name': AppStrings.t(context, 'Construction'),    'key': 'construction',   'bg': const Color(0xFFF0F9FF)},
      {'emoji': '🚰', 'name': AppStrings.t(context, 'Water Supply'),    'key': 'water',          'bg': const Color(0xFFF0FDF4)},
      {'emoji': '💡', 'name': AppStrings.t(context, 'Electricity'),     'key': 'electricity',    'bg': const Color(0xFFFFFBEB)},
      {'emoji': '🗑️', 'name': AppStrings.t(context, 'Garbage'),         'key': 'garbage',        'bg': const Color(0xFFECFDF5)},
      {'emoji': '🛣️', 'name': AppStrings.t(context, 'Road / Pothole'),  'key': 'road',           'bg': const Color(0xFFFAF5FF)},
      {'emoji': '🌊', 'name': AppStrings.t(context, 'Drainage'),        'key': 'drainage',       'bg': const Color(0xFFEFF6FF)},
      {'emoji': '⚠️', 'name': AppStrings.t(context, 'Illegal Activity'),'key': 'illegal',        'bg': const Color(0xFFFFF1F2)},
      {'emoji': '🚌', 'name': AppStrings.t(context, 'Transportation'),  'key': 'transportation', 'bg': const Color(0xFFF0F9FF)},
      {'emoji': '🛡️', 'name': AppStrings.t(context, 'Cyber Crime'),     'key': 'cyber',          'bg': const Color(0xFFF5F3FF)},
      {'emoji': '📋', 'name': AppStrings.t(context, 'Other'),           'key': 'other',          'bg': const Color(0xFFF8FAFC)},
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(AppStrings.t(context, 'Submit a Complaint'),
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a))),
      const SizedBox(height: 4),
      Text(AppStrings.t(context, 'Choose a category to report an issue'),
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748b))),
      const SizedBox(height: 20),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.95,
        children: categories.map((c) {
          final bg = c['bg'] as Color;
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.submitComplaint,
                arguments: {'categoryKey': c['key'], 'categoryName': c['name']}),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(c['emoji'] as String, style: const TextStyle(fontSize: 48)),
                      const SizedBox(height: 6),
                      Container(
                        width: 36, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ]),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Center(
                      child: Text(c['name'] as String,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: const Color(0xFF0f172a))),
                    ),
                  ),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  Widget _bottomNav() {
    final items = [
      {'emoji': '🏠', 'label': AppStrings.t(context, 'Home')},
      {'emoji': '📝', 'label': AppStrings.t(context, 'Submit')},
      {'emoji': '📞', 'label': AppStrings.t(context, 'Call')},
      {'emoji': '🔍', 'label': AppStrings.t(context, 'Track')},
      {'emoji': '👤', 'label': AppStrings.t(context, 'Profile')},
    ];
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, -2))]),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom, top: 8, left: 8, right: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, items[0]),
          _navItem(1, items[1]),
          _navItem(2, items[2]),
          _navItem(3, items[3]),
          _navItem(4, items[4]),
        ],
      ),
    );
  }

  Widget _navItem(int index, Map item) {
    final active = _navIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 0) setState(() { _navIndex = 0; _tab = 0; });
        else if (index == 1) setState(() { _navIndex = 1; _tab = 1; });
        else if (index == 2) Navigator.push(context, MaterialPageRoute(builder: (_) => AICallScreen()));
        else if (index == 3) Navigator.pushNamed(context, AppRoutes.userTrack);
        else Navigator.pushNamed(context, AppRoutes.profile);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0x1A1E66F5) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(item['emoji'] as String, style: TextStyle(fontSize: active ? 24 : 22)),
          const SizedBox(height: 3),
          Text(item['label'] as String,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? const Color(0xFF1E66F5) : const Color(0xFF64748b))),
        ]),
      ),
    );
  }
}