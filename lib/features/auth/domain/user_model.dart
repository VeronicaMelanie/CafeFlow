class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'employee' or 'admin'
  final String workType; // 'Full-time' or 'Part-time'
  final int monthlyTargetHours;
  final String primaryLocation;
  final String secondaryLocation;
  final String? fcmToken;
  final List<String>? availability; // Store dates in ISO format

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.workType,
    required this.monthlyTargetHours,
    required this.primaryLocation,
    required this.secondaryLocation,
    this.fcmToken,
    this.availability,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'employee',
      workType: map['workType'] ?? 'Full-time',
      monthlyTargetHours: map['monthlyTargetHours'] ?? 160,
      primaryLocation: map['primaryLocation'] ?? 'Gara',
      secondaryLocation: map['secondaryLocation'] ?? 'Avantgarden',
      fcmToken: map['fcmToken'],
      availability: map['availability'] != null ? List<String>.from(map['availability']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'workType': workType,
      'monthlyTargetHours': monthlyTargetHours,
      'primaryLocation': primaryLocation,
      'secondaryLocation': secondaryLocation,
      'fcmToken': fcmToken,
      'availability': availability,
    };
  }

  bool get isAdmin => role == 'admin';
}
