import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/complaint_provider.dart';
import '../../models/complaint.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final int complaintId;
  const ComplaintDetailScreen({super.key, required this.complaintId});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ComplaintProvider>(context, listen: false).loadComplaintDetail(widget.complaintId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complaint Details')),
      body: Consumer<ComplaintProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final complaint = provider.selectedComplaint;
          if (complaint == null) {
            return const Center(child: Text('Complaint not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(complaint),
                const Divider(height: 40),
                _buildInfoSection('Description', complaint.description),
                _buildInfoSection('Location', complaint.address),
                _buildInfoSection('Department', complaint.assignedDepartment?.name ?? 'Not Assigned'),
                if (complaint.media != null && complaint.media!.isNotEmpty)
                  _buildMediaSection(complaint.media!),
                if (complaint.workStatus == 'resolved' && complaint.citizenRating == null)
                  _buildRatingSection(complaint),
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
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            _StatusChip(status: complaint.workStatus, statusText: complaint.workStatusDisplay),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          complaint.title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Submitted on ${complaint.createdAt.toString().split(' ')[0]}',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryBlue)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 15, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildMediaSection(List<ComplaintMedia> media) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Evidence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryBlue)),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: media.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(media[index].fileUrl, width: 120, height: 120, fit: BoxFit.cover),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRatingSection(Complaint complaint) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Text('Rate this Resolution', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_border, size: 32, color: Colors.orange),
              Icon(Icons.star_border, size: 32, color: Colors.orange),
              Icon(Icons.star_border, size: 32, color: Colors.orange),
              Icon(Icons.star_border, size: 32, color: Colors.orange),
              Icon(Icons.star_border, size: 32, color: Colors.orange),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () {}, child: const Text('Submit Rating')),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final String statusText;
  const _StatusChip({required this.status, required this.statusText});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    switch (status) {
      case 'submitted': color = Colors.orange; break;
      case 'assigned': color = Colors.blue; break;
      case 'in-progress': color = Colors.indigo; break;
      case 'resolved': color = Colors.green; break;
      case 'reopened': color = Colors.red; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        statusText,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
