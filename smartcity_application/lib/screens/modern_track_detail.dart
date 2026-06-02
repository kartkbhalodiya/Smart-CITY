import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../l10n/app_strings.dart';

class ModernTrackDetail extends StatefulWidget {
  final Map<String, dynamic> complaint;

  const ModernTrackDetail({super.key, required this.complaint});

  @override
  State<ModernTrackDetail> createState() => _ModernTrackDetailState();
}

class _ModernTrackDetailState extends State<ModernTrackDetail> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MapController _mapController = MapController();
  bool _mapLoaded = false;
  int _selectedRating = 0;
  final _commentController = TextEditingController();
  final _reopenReasonController = TextEditingController();
  String? _selectedProofPath;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _mapLoaded = true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    _reopenReasonController.dispose();
    super.dispose();
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final complaint = widget.complaint;
    final isSolved = complaint['work_status'] == 'solved';
    final hasRating = complaint['citizen_rating'] != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildModernAppBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildTimelineTab(),
                _buildMapTab(),
              ],
            ),
          ),
          if (isSolved && !hasRating) _buildQuickRatingBar(),
        ],
      ),
    );
  }

  Widget _buildModernAppBar() {
    final status = widget.complaint['work_status'] ?? 'pending';
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_getStatusColor(status), _getStatusColor(status).withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor(status).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${widget.complaint['complaint_number'] ?? 'N/A'}',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _getStatusText(status),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
            ),
            
            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: _getStatusColor(status),
                unselectedLabelColor: Colors.white.withOpacity(0.7),
                labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Timeline'),
                  Tab(text: 'Map'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          if (widget.complaint['assigned_department'] != null)
            _buildDepartmentCard(),
          const SizedBox(height: 16),
          _buildDetailsCard(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final complaint = widget.complaint;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.report_problem, color: Color(0xFF3B82F6), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      complaint['title'] ?? 'Complaint Details',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      complaint['complaint_type_display'] ?? 'General',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow(Icons.description, 'Description', complaint['description'] ?? 'No description'),
          _buildInfoRow(Icons.location_on, 'Location', '${complaint['city']}, ${complaint['state']}'),
          _buildInfoRow(Icons.access_time, 'Submitted', _formatDate(complaint['created_at'])),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF1F2937),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentCard() {
    final dept = widget.complaint['assigned_department'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.business, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assigned Department',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    Text(
                      dept['name'] ?? 'Not assigned',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _makeCall(dept['phone'] ?? ''),
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _sendEmail(dept['email'] ?? ''),
                  icon: const Icon(Icons.email, size: 18),
                  label: const Text('Email'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    final complaint = widget.complaint;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.person, 'Name', complaint['user_name'] ?? 'Anonymous'),
          _buildInfoRow(Icons.email, 'Email', complaint['user_email'] ?? 'Not provided'),
          _buildInfoRow(Icons.phone, 'Phone', complaint['user_phone'] ?? 'Not provided'),
        ],
      ),
    );
  }

  Widget _buildTimelineTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildTimeline(),
    );
  }

  Widget _buildTimeline() {
    final status = widget.complaint['work_status'] ?? 'pending';
    final steps = _getTimelineSteps(status);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isLast = index == steps.length - 1;
          
          return _buildTimelineStep(
            icon: step['icon'] as IconData,
            title: step['title'] as String,
            subtitle: step['subtitle'] as String,
            color: step['color'] as Color,
            isCompleted: step['completed'] as bool,
            isLast: isLast,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isCompleted,
    required bool isLast,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCompleted ? color : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: isCompleted ? Colors.white : Colors.grey[400], size: 20),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: isCompleted ? color : Colors.grey[200],
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapTab() {
    final lat = _asDouble(widget.complaint['latitude']);
    final lng = _asDouble(widget.complaint['longitude']);
    final hasCoords = lat != 0.0 && lng != 0.0;
    
    return Stack(
      children: [
        if (hasCoords)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(lat, lng),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.janhelp.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(lat, lng),
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 40),
                  ),
                ],
              ),
            ],
          )
        else
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Location not available',
                  style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        
        // Map Controls
        if (hasCoords)
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  ),
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  ),
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'directions',
                  onPressed: () => _getDirections(lat, lng),
                  backgroundColor: const Color(0xFF10B981),
                  child: const Icon(Icons.directions, color: Colors.white),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQuickRatingBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rate this resolution',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedRating = index + 1),
                  child: Icon(
                    index < _selectedRating ? Icons.star : Icons.star_border,
                    color: const Color(0xFFF59E0B),
                    size: 36,
                  ),
                );
              }),
            ),
            if (_selectedRating > 0) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitRating,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Submit Rating',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(
        _getStatusText(status),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return const Color(0xFFF59E0B);
      case 'confirmed': return const Color(0xFF3B82F6);
      case 'process': return const Color(0xFF8B5CF6);
      case 'solved': return const Color(0xFF10B981);
      case 'reopened': return const Color(0xFFEF4444);
      default: return const Color(0xFF6B7280);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'Pending';
      case 'confirmed': return 'Confirmed';
      case 'process': return 'In Progress';
      case 'solved': return 'Solved';
      case 'reopened': return 'Reopened';
      default: return status;
    }
  }

  List<Map<String, dynamic>> _getTimelineSteps(String currentStatus) {
    final steps = [
      {
        'icon': Icons.assignment_turned_in,
        'title': 'Submitted',
        'subtitle': 'Complaint received',
        'color': const Color(0xFFF59E0B),
        'completed': true,
      },
      {
        'icon': Icons.verified,
        'title': 'Confirmed',
        'subtitle': 'Under review',
        'color': const Color(0xFF3B82F6),
        'completed': _isStepCompleted('confirmed', currentStatus),
      },
      {
        'icon': Icons.engineering,
        'title': 'In Progress',
        'subtitle': 'Being resolved',
        'color': const Color(0xFF8B5CF6),
        'completed': _isStepCompleted('process', currentStatus),
      },
      {
        'icon': Icons.check_circle,
        'title': 'Resolved',
        'subtitle': 'Complaint solved',
        'color': const Color(0xFF10B981),
        'completed': _isStepCompleted('solved', currentStatus),
      },
    ];
    
    return steps;
  }

  bool _isStepCompleted(String step, String currentStatus) {
    const order = ['pending', 'confirmed', 'process', 'solved'];
    final currentIndex = order.indexOf(currentStatus);
    final stepIndex = order.indexOf(step);
    return currentIndex >= stepIndex && stepIndex != -1;
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat('MMM dd, yyyy').format(dt);
    } catch (e) {
      return date.toString();
    }
  }

  void _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _getDirections(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _submitRating() async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rating submitted successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }
}
