import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../models/complaint.dart';
import '../../services/api_service.dart';

class AdminComplaintDetailScreen extends StatefulWidget {
  final int complaintId;

  const AdminComplaintDetailScreen({
    super.key,
    required this.complaintId,
  });

  @override
  State<AdminComplaintDetailScreen> createState() =>
      _AdminComplaintDetailScreenState();
}

class _AdminComplaintDetailScreenState
    extends State<AdminComplaintDetailScreen> {
  static const _bg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF0B1020);
  static const _text = Color(0xFF101828);
  static const _muted = Color(0xFF5B6B86);
  static const _line = Color(0xFFEEF2F6);
  static const _primary = Color(0xFF2F80ED);

  bool _loading = true;
  bool _saving = false;
  String? _error;
  Complaint? _complaint;
  Map<String, dynamic> _raw = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final response =
        await ApiService.get(ApiConfig.complaintDetail(widget.complaintId));
    if (!mounted) return;

    if (response['success'] == false) {
      setState(() {
        _error = response['message']?.toString() ?? 'Unable to load complaint.';
        _loading = false;
      });
      return;
    }

    final rawComplaint = response['complaint'] is Map
        ? Map<String, dynamic>.from(response['complaint'] as Map)
        : Map<String, dynamic>.from(response);

    setState(() {
      _raw = rawComplaint;
      _complaint = Complaint.fromJson(rawComplaint);
      _loading = false;
    });
  }

  Future<void> _updateStatus(
    String status,
    String notes, {
    String? proofPath,
  }) async {
    final complaint = _complaint;
    if (complaint == null) return;

    setState(() => _saving = true);
    final fields = {
      'work_status': status,
      'notes': notes,
    };
    final response = proofPath == null
        ? await ApiService.post(
            ApiConfig.adminComplaintStatus(complaint.id),
            fields,
          )
        : await ApiService.postMultipart(
            ApiConfig.adminComplaintStatus(complaint.id),
            fields,
            [File(proofPath)],
          );
    if (!mounted) return;
    setState(() => _saving = false);

    if (response['success'] == true) {
      final rawComplaint = response['complaint'] is Map
          ? Map<String, dynamic>.from(response['complaint'] as Map)
          : _raw;
      setState(() {
        _raw = rawComplaint;
        _complaint = Complaint.fromJson(rawComplaint);
      });
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message']?.toString() ?? 'Updated')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(response['message']?.toString() ?? 'Update failed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 18, 24, 34 + bottomInset),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _topBar(),
                    const SizedBox(height: 18),
                    if (_loading)
                      _loadingState()
                    else if (_error != null)
                      _messageBox(
                        icon: Icons.error_outline_rounded,
                        title: _error!,
                        actionLabel: 'Retry',
                        onAction: _load,
                      )
                    else if (_complaint == null)
                      _messageBox(
                        icon: Icons.search_off_rounded,
                        title: 'Complaint not found',
                        actionLabel: 'Back',
                        onAction: () => Navigator.pop(context),
                      )
                    else
                      ..._detailContent(_complaint!),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _detailContent(Complaint complaint) {
    final statusColor = _statusColor(complaint.workStatus);
    final resolutionProofs = _rawList('resolution_proofs');
    final reopenProofs = _rawList('reopen_proofs');
    return [
      _headerCard(complaint, statusColor),
      const SizedBox(height: 16),
      _statusActionCard(complaint),
      const SizedBox(height: 16),
      _sectionTitle('Complaint Details', Icons.description_outlined),
      const SizedBox(height: 10),
      _infoCard([
        _infoRow('Complaint No.', complaint.complaintNumber),
        _infoRow('Category', complaint.complaintTypeDisplay),
        if ((complaint.subcategory ?? '').isNotEmpty)
          _infoRow('Subcategory', complaint.subcategory!),
        _infoRow('Priority', complaint.priorityDisplay),
        _infoRow('Created', _formatDateTime(complaint.createdAt)),
        _infoRow('Description', complaint.description),
      ]),
      const SizedBox(height: 18),
      _sectionTitle('Citizen', Icons.person_outline_rounded),
      const SizedBox(height: 10),
      _infoCard([
        _infoRow('Name', complaint.userName),
        _infoRow('Email', _rawValue('guest_email')),
        _infoRow('Phone', _rawValue('guest_phone')),
      ]),
      const SizedBox(height: 18),
      _sectionTitle('Location', Icons.location_on_outlined),
      const SizedBox(height: 10),
      _infoCard([
        _infoRow('City', complaint.city),
        _infoRow('State', complaint.state),
        _infoRow('Pincode', complaint.pincode ?? ''),
        _infoRow('Address', complaint.address),
      ]),
      const SizedBox(height: 10),
      _wideOutlineButton(
        label: 'Open Map',
        icon: Icons.map_outlined,
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.adminLocationMap,
          arguments: {
            'type': 'complaint',
            'id': complaint.id,
          },
        ),
      ),
      if (complaint.assignedDepartment != null) ...[
        const SizedBox(height: 18),
        _sectionTitle('Assigned Department', Icons.account_balance_outlined),
        const SizedBox(height: 10),
        _infoCard([
          _infoRow('Name', complaint.assignedDepartment!.name),
          _infoRow('Type', complaint.assignedDepartment!.departmentTypeDisplay),
          _infoRow('Phone', complaint.assignedDepartment!.phone),
          _infoRow('Email', complaint.assignedDepartment!.email),
          _infoRow('SLA', '${complaint.assignedDepartment!.slaHours} hours'),
        ]),
      ],
      const SizedBox(height: 18),
      _sectionTitle('Admin Notes', Icons.sticky_note_2_outlined),
      const SizedBox(height: 10),
      _infoCard([
        _infoRow('Resolution notes', _rawValue('resolution_notes')),
        _infoRow('Resolved at', _formatRawDate(_raw['resolved_at'])),
        _infoRow('Updated', _formatDateTime(complaint.updatedAt)),
      ]),
      if (resolutionProofs.isNotEmpty) ...[
        const SizedBox(height: 18),
        _sectionTitle('Completion Proof', Icons.verified_outlined),
        const SizedBox(height: 10),
        _proofGrid(resolutionProofs),
      ],
      if (reopenProofs.isNotEmpty) ...[
        const SizedBox(height: 18),
        _sectionTitle('Reopen Proof', Icons.restart_alt_rounded),
        const SizedBox(height: 10),
        _reopenProofList(reopenProofs),
      ],
    ];
  }

  Widget _topBar() {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          _iconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          const SizedBox(width: 12),
          Image.asset(
            'assets/images/logo.png',
            width: 118,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          _iconButton(
            icon: Icons.refresh_rounded,
            onTap: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _headerCard(Complaint complaint, Color statusColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.assignment_outlined,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      complaint.complaintNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _labelStyle(
                        size: 12,
                        weight: FontWeight.w800,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      complaint.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _displayStyle(size: 22, height: 1.1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(complaint.workStatusDisplay, statusColor),
              _pill(complaint.statusDisplay, _ink),
              _pill(complaint.priorityDisplay, const Color(0xFFF97316)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusActionCard(Complaint complaint) {
    final options = _nextStatusOptions(complaint.workStatus);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(radius: 22),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Action',
                  style: _labelStyle(
                    size: 16,
                    weight: FontWeight.w900,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  options.isEmpty
                      ? 'No next action available'
                      : 'Move complaint to the next valid state.',
                  style: _labelStyle(
                    size: 12,
                    weight: FontWeight.w600,
                    color: _muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _blackButton(
            label: _saving ? 'Saving' : 'Update',
            icon: Icons.edit_outlined,
            onTap: _saving || options.isEmpty
                ? null
                : () => _openStatusSheet(complaint),
          ),
        ],
      ),
    );
  }

  void _openStatusSheet(Complaint complaint) {
    final notesController = TextEditingController(
      text: _rawValue('resolution_notes'),
    );
    final options = _nextStatusOptions(complaint.workStatus);
    String nextStatus = options.first['value']!;
    String? proofPath;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
            decoration: const BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final existingProofs = _rawList('resolution_proofs');
                final needsProof =
                    nextStatus == 'solved' && existingProofs.isEmpty;
                final hasExistingNotes =
                    _rawValue('resolution_notes').trim().isNotEmpty;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8DEE8),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Update Status', style: _displayStyle(size: 24)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: nextStatus,
                      isExpanded: true,
                      items: options.map((option) {
                        return DropdownMenuItem<String>(
                          value: option['value'],
                          child: Text(option['label'] ?? ''),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => nextStatus = value);
                        }
                      },
                      decoration: _inputDecoration('Next status'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 4,
                      style: _labelStyle(
                        size: 15,
                        weight: FontWeight.w700,
                        color: _text,
                      ),
                      decoration: _inputDecoration(
                        nextStatus == 'solved' ? 'Resolution notes *' : 'Notes',
                      ),
                    ),
                    if (nextStatus == 'solved') ...[
                      const SizedBox(height: 12),
                      _proofPicker(
                        proofPath: proofPath,
                        proofAlreadyExists: existingProofs.isNotEmpty,
                        onTap: () async {
                          final image = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 82,
                          );
                          if (image != null) {
                            setModalState(() => proofPath = image.path);
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    _wideBlackButton(
                      label: _saving ? 'Saving...' : 'Save Status',
                      icon: Icons.check_rounded,
                      onTap: _saving
                          ? null
                          : () {
                              if (nextStatus == 'solved' &&
                                  !hasExistingNotes &&
                                  notesController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Resolution notes are required.',
                                    ),
                                    backgroundColor: Color(0xFFDC2626),
                                  ),
                                );
                                return;
                              }
                              if (needsProof && proofPath == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Completion proof is required.',
                                    ),
                                    backgroundColor: Color(0xFFDC2626),
                                  ),
                                );
                                return;
                              }
                              Navigator.pop(context);
                              _updateStatus(
                                nextStatus,
                                notesController.text.trim(),
                                proofPath:
                                    nextStatus == 'solved' ? proofPath : null,
                              );
                            },
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    ).whenComplete(notesController.dispose);
  }

  List<Map<String, String>> _nextStatusOptions(String current) {
    switch (current.toLowerCase()) {
      case 'pending':
      case 'reopened':
        return const [
          {'value': 'confirmed', 'label': 'Confirm'},
          {'value': 'rejected', 'label': 'Reject'},
        ];
      case 'confirmed':
        return const [
          {'value': 'process', 'label': 'Move to Process'},
        ];
      case 'process':
        return const [
          {'value': 'solved', 'label': 'Mark Solved'},
        ];
      default:
        return const [];
    }
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: _primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: _labelStyle(
              size: 18,
              weight: FontWeight.w900,
              color: _text,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoCard(List<Widget> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(radius: 20),
      child: Column(children: rows),
    );
  }

  Widget _infoRow(String label, String value) {
    final cleanValue = value.trim().isEmpty ? 'Not available' : value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: _labelStyle(
                size: 11.5,
                weight: FontWeight.w700,
                color: _muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              cleanValue,
              style: _labelStyle(
                size: 13,
                weight: FontWeight.w800,
                color: _text,
                height: 1.32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _proofPicker({
    required String? proofPath,
    required bool proofAlreadyExists,
    required VoidCallback onTap,
  }) {
    final hasLocalProof = proofPath != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: proofAlreadyExists || hasLocalProof
                  ? const Color(0xFF16A34A).withValues(alpha: 0.45)
                  : const Color(0xFFDC2626).withValues(alpha: 0.45),
            ),
          ),
          child: hasLocalProof
              ? Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(proofPath),
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Completion proof selected',
                        style: _labelStyle(
                          size: 13,
                          weight: FontWeight.w900,
                          color: _text,
                        ),
                      ),
                    ),
                    const Icon(Icons.edit_rounded, color: _ink, size: 18),
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      proofAlreadyExists
                          ? Icons.verified_rounded
                          : Icons.add_photo_alternate_outlined,
                      color: proofAlreadyExists
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        proofAlreadyExists
                            ? 'Existing completion proof is attached. Tap to add another.'
                            : 'Attach completion photo proof',
                        style: _labelStyle(
                          size: 12.5,
                          weight: FontWeight.w800,
                          color: proofAlreadyExists ? _text : _muted,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _proofGrid(List<Map<String, dynamic>> proofs) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: proofs.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: proofs.length == 1 ? 1 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: proofs.length == 1 ? 1.8 : 1.06,
      ),
      itemBuilder: (context, index) => _proofTile(proofs[index]),
    );
  }

  Widget _proofTile(Map<String, dynamic> proof) {
    final url = _proofUrl(proof);
    final fileType = (proof['file_type'] ?? '').toString().toLowerCase();
    final isVideo = fileType == 'video' ||
        url.toLowerCase().endsWith('.mp4') ||
        url.toLowerCase().endsWith('.mov') ||
        url.toLowerCase().endsWith('.webm');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: url.isEmpty || isVideo ? null : () => _openProofViewer(url),
        child: Ink(
          decoration: _cardDecoration(radius: 18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url.isNotEmpty && !isVideo)
                  Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _proofFallback(isVideo),
                  )
                else
                  _proofFallback(isVideo),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.64),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatRawDate(proof['uploaded_at']).isEmpty
                          ? 'Completion proof'
                          : _formatRawDate(proof['uploaded_at']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _labelStyle(
                        size: 11,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reopenProofList(List<Map<String, dynamic>> proofs) {
    return Column(
      children: proofs
          .map(
            (proof) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: _cardDecoration(radius: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (proof['reason'] ?? '').toString().trim().isEmpty
                        ? 'No reason provided'
                        : proof['reason'].toString(),
                    style: _labelStyle(
                      size: 13.5,
                      weight: FontWeight.w900,
                      color: _text,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill(
                        (proof['requested_by_name'] ?? '').toString().isEmpty
                            ? 'Citizen'
                            : proof['requested_by_name'].toString(),
                        _ink,
                      ),
                      if (_formatRawDate(proof['created_at']).isNotEmpty)
                        _pill(_formatRawDate(proof['created_at']), _primary),
                    ],
                  ),
                  if (_proofUrl(proof).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _wideOutlineButton(
                      label: 'View Reopen Proof',
                      icon: Icons.image_outlined,
                      onTap: () => _openProofViewer(_proofUrl(proof)),
                    ),
                  ],
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _proofFallback(bool isVideo) {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Icon(
        isVideo ? Icons.play_circle_outline_rounded : Icons.broken_image,
        color: _muted,
        size: 34,
      ),
    );
  }

  Widget _loadingState() {
    return Column(
      children: [
        Container(height: 130, decoration: _cardDecoration(radius: 24)),
        const SizedBox(height: 14),
        Container(height: 92, decoration: _cardDecoration(radius: 22)),
        const SizedBox(height: 18),
        Container(height: 210, decoration: _cardDecoration(radius: 20)),
      ],
    );
  }

  Widget _messageBox({
    required IconData icon,
    required String title,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 22),
      child: Column(
        children: [
          Icon(icon, color: _muted, size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: _labelStyle(size: 14, weight: FontWeight.w800, color: _text),
          ),
          const SizedBox(height: 12),
          _blackButton(
            label: actionLabel,
            icon: Icons.refresh_rounded,
            onTap: onAction,
          ),
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: Icon(icon, color: _ink, size: 21),
          ),
        ),
      ),
    );
  }

  Widget _blackButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: onTap == null ? const Color(0xFFCBD5E1) : _ink,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: _labelStyle(
                  size: 12.5,
                  weight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wideBlackButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.65 : 1,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A1A), Color(0xFF050505)],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: _labelStyle(
                  size: 15,
                  weight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wideOutlineButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _ink.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _ink, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: _labelStyle(
                  size: 13.5,
                  weight: FontWeight.w900,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: _labelStyle(
          size: 11,
          weight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      labelStyle: _labelStyle(
        size: 13,
        weight: FontWeight.w700,
        color: _muted,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _ink, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    );
  }

  BoxDecoration _cardDecoration({required double radius}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _line),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'solved':
        return const Color(0xFF16A34A);
      case 'process':
      case 'confirmed':
        return const Color(0xFF7C3AED);
      case 'reopened':
      case 'rejected':
        return const Color(0xFFDC2626);
      case 'pending':
      default:
        return const Color(0xFFF97316);
    }
  }

  String _rawValue(String key) {
    final value = _raw[key];
    if (value == null) return '';
    return value.toString();
  }

  List<Map<String, dynamic>> _rawList(String key) {
    final value = _raw[key];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _proofUrl(Map<String, dynamic> proof) {
    final raw = (proof['file_url'] ??
            proof['proof_url'] ??
            proof['file'] ??
            proof['proof'] ??
            '')
        .toString()
        .trim();
    if (raw.isEmpty || raw.startsWith('http')) return raw;
    final apiRoot = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    return raw.startsWith('/') ? '$apiRoot$raw' : raw;
  }

  void _openProofViewer(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: InteractiveViewer(
            minScale: 0.7,
            maxScale: 4,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                height: 220,
                color: Colors.white,
                alignment: Alignment.center,
                child: Text(
                  'Unable to load proof',
                  style: _labelStyle(
                    size: 13,
                    weight: FontWeight.w800,
                    color: _muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatRawDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return '';
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return _formatDateTime(date);
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }

  TextStyle _displayStyle({
    required double size,
    double height = 1.08,
    Color color = _ink,
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      height: height,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
      color: color,
    );
  }

  TextStyle _labelStyle({
    required double size,
    required FontWeight weight,
    required Color color,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      height: height,
      fontWeight: weight,
      letterSpacing: 0,
      color: color,
    );
  }
}
