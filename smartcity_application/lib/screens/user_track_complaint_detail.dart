import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UserTrackComplaintDetail extends StatefulWidget {
  final Map<String, dynamic> complaint;

  const UserTrackComplaintDetail({Key? key, required this.complaint}) : super(key: key);

  @override
  State<UserTrackComplaintDetail> createState() => _UserTrackComplaintDetailState();
}

class _UserTrackComplaintDetailState extends State<UserTrackComplaintDetail> {
  bool _showReopenDialog = false;
  final _reopenReasonController = TextEditingController();
  String? _selectedProofPath;

  @override
  Widget build(BuildContext context) {
    final complaint = widget.complaint;
    final department = complaint['assigned_department'];
    final isSolved = complaint['work_status'] == 'solved';
    final canReopen = complaint['can_reopen'] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('Complaint #${complaint['complaint_number']}'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map Section
            _buildMapSection(complaint),
            
            // Status & Department Info
            _buildStatusCard(complaint, department),
            
            // Complaint Details
            _buildDetailsCard(complaint),
            
            // Department Contact (if assigned)
            if (department != null) _buildDepartmentContact(department),
            
            // Rating Section (if solved)
            if (isSolved && complaint['citizen_rating'] != null)
              _buildRatingDisplay(complaint),
            
            // Reopen Button (if can reopen)
            if (canReopen) _buildReopenButton(),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection(Map<String, dynamic> complaint) {
    return Container(
      height: 250,
      width: double.infinity,
      color: Colors.grey[300],
      child: Stack(
        children: [
          // Map placeholder - integrate with actual map
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, size: 64, color: Colors.grey[600]),
                const SizedBox(height: 8),
                Text(
                  '${complaint['city']}, ${complaint['state']}',
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: () => _openMap(complaint['latitude'], complaint['longitude']),
              child: const Icon(Icons.directions),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> complaint, Map<String, dynamic>? department) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                complaint['title'],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              _buildStatusBadge(complaint['work_status']),
            ],
          ),
          const SizedBox(height: 16),
          if (department != null) ...[
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.business, color: Colors.blue[700]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assigned Department',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        department['name'],
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsCard(Map<String, dynamic> complaint) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Complaint Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(Icons.description, 'Description', complaint['description']),
          _buildDetailRow(Icons.category, 'Category', complaint['complaint_type']),
          _buildDetailRow(Icons.calendar_today, 'Submitted', complaint['created_at']),
          _buildDetailRow(Icons.location_on, 'Location', complaint['address']),
        ],
      ),
    );
  }

  Widget _buildDepartmentContact(Map<String, dynamic> department) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contact Department',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _makeCall(department['phone']),
                  icon: const Icon(Icons.phone),
                  label: const Text('Call'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _sendEmail(department['email']),
                  icon: const Icon(Icons.email),
                  label: const Text('Email'),
                  style: OutlinedButton.styleFrom(
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

  Widget _buildRatingDisplay(Map<String, dynamic> complaint) {
    final rating = complaint['citizen_rating'] ?? 0;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Rating',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 28,
              );
            }),
          ),
          if (complaint['citizen_feedback'] != null) ...[
            const SizedBox(height: 12),
            Text(
              complaint['citizen_feedback'],
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReopenButton() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: () => setState(() => _showReopenDialog = true),
        icon: const Icon(Icons.refresh),
        label: const Text('Reopen Complaint'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    
    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'Pending';
        break;
      case 'confirmed':
        color = Colors.blue;
        text = 'Confirmed';
        break;
      case 'process':
        color = Colors.purple;
        text = 'In Progress';
        break;
      case 'solved':
        color = Colors.green;
        text = 'Solved';
        break;
      case 'reopened':
        color = Colors.red;
        text = 'Reopened';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _openMap(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  void _makeCall(String phone) async {
    final url = 'tel:$phone';
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  void _sendEmail(String email) async {
    final url = 'mailto:$email';
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  @override
  void dispose() {
    _reopenReasonController.dispose();
    super.dispose();
  }
}
