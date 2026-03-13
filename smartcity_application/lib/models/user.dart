class User {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String? token;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      token: json['token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'token': token,
    };
  }

  String get fullName => '$firstName $lastName'.trim();
}

class UserProfile {
  final int id;
  final User user;
  final String surname;
  final String state;
  final String district;
  final String taluka;
  final String city;
  final String address;
  final String mobileNo;
  final String? aadhaarNumber;
  final double latitude;
  final double longitude;

  UserProfile({
    required this.id,
    required this.user,
    required this.surname,
    required this.state,
    required this.district,
    required this.taluka,
    required this.city,
    required this.address,
    required this.mobileNo,
    this.aadhaarNumber,
    required this.latitude,
    required this.longitude,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? 0,
      user: User.fromJson(json['user'] ?? {}),
      surname: json['surname'] ?? '',
      state: json['state'] ?? '',
      district: json['district'] ?? '',
      taluka: json['taluka'] ?? '',
      city: json['city'] ?? '',
      address: json['address'] ?? '',
      mobileNo: json['mobile_no'] ?? '',
      aadhaarNumber: json['aadhaar_number'],
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user.toJson(),
      'surname': surname,
      'state': state,
      'district': district,
      'taluka': taluka,
      'city': city,
      'address': address,
      'mobile_no': mobileNo,
      'aadhaar_number': aadhaarNumber,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
