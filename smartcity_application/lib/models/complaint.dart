class Complaint {
  final int id;
  final String complaintNumber;
  final String complaintType;
  final String complaintTypeDisplay;
  final String? subcategory;
  final String priority;
  final String priorityDisplay;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String city;
  final String state;
  final String? pincode;
  final String address;
  final String status;
  final String statusDisplay;
  final String workStatus;
  final String workStatusDisplay;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userName;
  final int mediaCount;
  final String? thumbnail;
  final int? citizenRating;
  final List<ComplaintMedia>? media;
  final Department? assignedDepartment;
  final bool? canReopen;
  final DateTime? reopenDeadline;

  Complaint({
    required this.id,
    required this.complaintNumber,
    required this.complaintType,
    required this.complaintTypeDisplay,
    this.subcategory,
    required this.priority,
    required this.priorityDisplay,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.state,
    this.pincode,
    required this.address,
    required this.status,
    required this.statusDisplay,
    required this.workStatus,
    required this.workStatusDisplay,
    required this.createdAt,
    required this.updatedAt,
    required this.userName,
    required this.mediaCount,
    this.thumbnail,
    this.citizenRating,
    this.media,
    this.assignedDepartment,
    this.canReopen,
    this.reopenDeadline,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'] ?? 0,
      complaintNumber: json['complaint_number'] ?? '',
      complaintType: json['complaint_type'] ?? '',
      complaintTypeDisplay: json['complaint_type_display'] ?? '',
      subcategory: json['subcategory'],
      priority: json['priority'] ?? 'normal',
      priorityDisplay: json['priority_display'] ?? 'Normal',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      pincode: json['pincode'],
      address: json['address'] ?? '',
      status: json['status'] ?? 'pending',
      statusDisplay: json['status_display'] ?? 'Pending',
      workStatus: json['work_status'] ?? 'pending',
      workStatusDisplay: json['work_status_display'] ?? 'Pending',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      userName: json['user_name'] ?? 'Anonymous',
      mediaCount: json['media_count'] ?? 0,
      thumbnail: json['thumbnail'],
      citizenRating: json['citizen_rating'],
      media: json['media'] != null
          ? (json['media'] as List).map((m) => ComplaintMedia.fromJson(m)).toList()
          : null,
      assignedDepartment: json['assigned_department'] != null
          ? Department.fromJson(json['assigned_department'])
          : null,
      canReopen: json['can_reopen'],
      reopenDeadline: json['reopen_deadline'] != null
          ? DateTime.parse(json['reopen_deadline'])
          : null,
    );
  }
}

class ComplaintMedia {
  final int id;
  final String file;
  final String fileUrl;
  final String fileType;

  ComplaintMedia({
    required this.id,
    required this.file,
    required this.fileUrl,
    required this.fileType,
  });

  factory ComplaintMedia.fromJson(Map<String, dynamic> json) {
    return ComplaintMedia(
      id: json['id'] ?? 0,
      file: json['file'] ?? '',
      fileUrl: json['file_url'] ?? '',
      fileType: json['file_type'] ?? 'image',
    );
  }
}

class Department {
  final int id;
  final String name;
  final String departmentType;
  final String departmentTypeDisplay;
  final String? state;
  final String? city;
  final String locationName;
  final double latitude;
  final double longitude;
  final String email;
  final String phone;
  final String address;
  final String formattedAddress;
  final int slaHours;
  final String? logoUrl;

  Department({
    required this.id,
    required this.name,
    required this.departmentType,
    required this.departmentTypeDisplay,
    this.state,
    this.city,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.email,
    required this.phone,
    required this.address,
    required this.formattedAddress,
    required this.slaHours,
    this.logoUrl,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      departmentType: json['department_type'] ?? '',
      departmentTypeDisplay: json['department_type_display'] ?? '',
      state: json['state'],
      city: json['city'],
      locationName: json['location_name'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      formattedAddress: json['formatted_address'] ?? '',
      slaHours: json['sla_hours'] ?? 72,
      logoUrl: json['logo_url'],
    );
  }
}

class DashboardStats {
  final int totalComplaints;
  final int pendingComplaints;
  final int resolvedComplaints;
  final int reopenedComplaints;
  final int inProgressComplaints;

  DashboardStats({
    required this.totalComplaints,
    required this.pendingComplaints,
    required this.resolvedComplaints,
    required this.reopenedComplaints,
    required this.inProgressComplaints,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalComplaints: json['total_complaints'] ?? 0,
      pendingComplaints: json['pending_complaints'] ?? 0,
      resolvedComplaints: json['resolved_complaints'] ?? 0,
      reopenedComplaints: json['reopened_complaints'] ?? 0,
      inProgressComplaints: json['in_progress_complaints'] ?? 0,
    );
  }
}
