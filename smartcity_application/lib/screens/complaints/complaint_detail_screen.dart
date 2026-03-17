import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../providers/complaint_provider.dart';
import '../../models/complaint.dart';
import '../../services/api_service.dart';
import '../departments/department_detail_screen.dart';
import '../../l10n/app_strings.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final int complaintId;
  const ComplaintDetailScreen({super.key, required this.complaintId});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  bool _showDeptPopup = false;
  final MapController _mapController = MapController();
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
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ComplaintProvider>(context, listen: false)
          .loadComplaintDetail(widget.complaintId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t(context, 'Complaint Details'))),
      body: Consumer<ComplaintProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final complaint = provider.selectedComplaint;
          if (complaint == null) {
            return Center(child: Text(AppStrings.t(context, 'Complaint not found')));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(complaint),
                const Divider(height: 40),
                _buildInfoSection(AppStrings.t(context, 'Description'), complaint.description),
                _buildInfoSection(AppStrings.t(context, 'Location'), complaint.address),
                if (complaint.latitude != 0.0 && complaint.longitude != 0.0)
                  _buildMapSection(complaint),
                _buildInfoSection(
                  AppStrings.t(context, 'Department'),
                  complaint.assignedDepartment?.name ?? AppStrings.t(context, 'Not assigned'),
                ),
                if (complaint.media != null && complaint.media!.isNotEmpty)
                  _buildMediaSection(AppStrings.t(context, 'Evidence Photos'), complaint.media!),
                // Dept work proof
                if (complaint.workProof != null && complaint.workProof!.isNotEmpty)
                  _buildMediaSection(AppStrings.t(context, 'Department Proof'), complaint.workProof!),
                // Rating: show existing or form
                if (complaint.citizenRating != null)
                  _buildExistingRating(complaint)
                else if (complaint.workStatus == 'solved' || complaint.workStatus == 'resolved')
                  _buildRatingForm(complaint),
                // Reopen button — show if solved/resolved (before or after rating)
                if (complaint.workStatus == 'solved' || complaint.workStatus == 'resolved' ||
                    complaint.canReopen == true)
                  _buildReopenButton(complaint),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(Complaint complaint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '#${complaint.complaintNumber}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            _StatusChip(
                status: complaint.workStatus,
                statusText: complaint.workStatusDisplay),
          ],
        ),
        const SizedBox(height: 12),
        Text(complaint.title,
            style:
                const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          '${AppStrings.t(context, 'Submitted on')} ${complaint.createdAt.toString().split(' ')[0]}',
          style:
              const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildMapSection(Complaint complaint) {
    final complaintPos =
        LatLng(complaint.latitude, complaint.longitude);
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
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B6CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.map,
                      color: Color(0xFF2B6CF6), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.t(context, 'Interactive Map'),
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F2937))),
                      Text(
                        hasDept
                            ? AppStrings.t(context, 'Complaint → Department location')
                            : AppStrings.t(context, 'Complaint location'),
                        style: GoogleFonts.inter(
                            fontSize: 12, color: const Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _openMap(
                      complaint.latitude, complaint.longitude),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: const Color(0xFF2B6CF6),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.open_in_new,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Real map
          Container(
            height: 300,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCameraFit: fit,
                      onMapReady: () {
                        Future.microtask(() {
                          if (mounted) _mapController.fitCamera(fit);
                        });
                      },
                      onTap: (_, __) {
                        if (_showDeptPopup) {
                          setState(() => _showDeptPopup = false);
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.janhelp.app',
                      ),

                      // Dotted line: complaint → department
                      if (deptPos != null)
                        PolylineLayer(polylines: [
                          Polyline(
                            points: [complaintPos, deptPos],
                            color: const Color(0xFF1E66F5),
                            strokeWidth: 2.5,
                            isDotted: true,
                          ),
                        ]),

                      // Markers
                      MarkerLayer(markers: [
                        // Complaint marker (red)
                        Marker(
                          point: complaintPos,
                          width: 44,
                          height: 52,
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _showDeptPopup = false),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black
                                              .withOpacity(0.2),
                                          blurRadius: 4)
                                    ],
                                  ),
                                  child: const Icon(Icons.report,
                                      color: Colors.white, size: 14),
                                ),
                                const Icon(Icons.location_on,
                                    color: Color(0xFFEF4444), size: 28),
                              ],
                            ),
                          ),
                        ),

                        // Department marker (blue) — tap to show popup
                        if (deptPos != null)
                          Marker(
                            point: deptPos,
                            width: 44,
                            height: 52,
                            child: GestureDetector(
                              onTap: () => setState(
                                  () => _showDeptPopup = true),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E66F5),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black
                                                .withOpacity(0.2),
                                            blurRadius: 4)
                                      ],
                                    ),
                                    child: const Icon(Icons.business,
                                        color: Colors.white, size: 14),
                                  ),
                                  const Icon(Icons.location_on,
                                      color: Color(0xFF1E66F5),
                                      size: 28),
                                ],
                              ),
                            ),
                          ),
                      ]),
                    ],
                  ),

                  // Department popup on tap
                  if (_showDeptPopup && deptPos != null && dept != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: _DeptPopup(
                        dept: dept,
                        onClose: () =>
                            setState(() => _showDeptPopup = false),
                        onViewDetails: () {
                          setState(() => _showDeptPopup = false);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DepartmentDetailScreen(
                                department: {
                                  'id': dept.id,
                                  'name': dept.name,
                                  'department_type': dept.departmentType,
                                  'department_type_display':
                                      dept.departmentTypeDisplay,
                                  'latitude': dept.latitude,
                                  'longitude': dept.longitude,
                                  'address': dept.address,
                                  'phone': dept.phone,
                                  'email': dept.email,
                                  'city': dept.city,
                                  'state': dept.state,
                                  'sla_hours': dept.slaHours,
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // Legend
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6)
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _legendDot(
                              const Color(0xFFEF4444), AppStrings.t(context, 'Complaint')),
                          if (hasDept) ...[
                            const SizedBox(height: 4),
                            _legendDot(
                                const Color(0xFF1E66F5), AppStrings.t(context, 'Department')),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Coordinates overlay
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6)
                        ],
                      ),
                      child: Text(
                        '${complaint.latitude.toStringAsFixed(4)}, ${complaint.longitude.toStringAsFixed(4)}',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF6B7280)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style: GoogleFonts.inter(
              fontSize: 10, color: const Color(0xFF6B7280))),
    ]);
  }

  Widget _buildInfoSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primaryBlue)),
          const SizedBox(height: 8),
          Text(content,
              style: const TextStyle(fontSize: 15, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildMediaSection(String title, List<ComplaintMedia> media) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.primaryBlue)),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: media.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => _openUrl(media[index].fileUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(media[index].fileUrl,
                        width: 120, height: 120, fit: BoxFit.cover),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
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
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
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

  void _showReopenDialog(Complaint complaint) {
    _reopenReasonCtrl.clear();
    _reopenProofPath = null;
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
                    color: const Color(0xFFEF4444).withOpacity(0.1),
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
                    height: 100,
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
                              const Icon(Icons.add_photo_alternate, size: 32, color: Color(0xFF9CA3AF)),
                              const SizedBox(height: 6),
                              Text(AppStrings.t(context, 'Tap to add photo'), style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(AppStrings.t(context, 'Cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _reopenReasonCtrl.text.trim().isEmpty || _isSubmittingReopen
                          ? null
                          : () => _submitReopen(complaint, ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSubmittingReopen
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(AppStrings.t(context, 'Submit'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
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

  Future<void> _submitReopen(Complaint complaint, BuildContext ctx) async {
    setState(() => _isSubmittingReopen = true);
    final res = await ApiService.post(
      ApiConfig.reopenComplaint(complaint.id),
      {'reason': _reopenReasonCtrl.text.trim()},
    );
    setState(() => _isSubmittingReopen = false);
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.pop(ctx);
      Provider.of<ComplaintProvider>(context, listen: false).loadComplaintDetail(complaint.id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t(context, 'Reopen request submitted successfully!')), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? AppStrings.t(context, 'Failed')), backgroundColor: Colors.red));
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
              color: Colors.black.withOpacity(0.15),
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
              color: const Color(0xFF1E66F5).withOpacity(0.1),
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
                      color: const Color(0xFF1E66F5).withOpacity(0.3),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(AppStrings.t(context, statusText),
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
    );
  }
}
