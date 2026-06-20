class User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? department;
  final String? designation;
  final String? vehicleType;
  final String role;
  final List<String> permissions;
  final String? avatar;

  User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.department,
    this.designation,
    this.vehicleType,
    required this.role,
    required this.permissions,
    this.avatar,
  });

  String get fullName => '$firstName $lastName';
  bool get isAdmin => role == 'super_admin';
  bool get isHod => role == 'hod';
  bool get isEmployee => role == 'employee';
  bool get isAdminOrHod => isAdmin || isHod;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      department: json['department'],
      designation: json['designation'],
      vehicleType: json['vehicleType'],
      role: json['role'] ?? 'employee',
      permissions: List<String>.from(json['permissions'] ?? []),
      avatar: json['avatar'],
    );
  }
}
