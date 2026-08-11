class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'employee' or 'admin'
  final String workType; // legacy display field: 'Full-time' or 'Part-time'
  final int monthlyTargetHours;
  final String primaryLocation;
  final String secondaryLocation;
  final String? fcmToken;
  final List<String>? availability; // Store dates in ISO format
  final String? contractType; // 'full_time' | 'part_time'
  final bool needsContractType;
  final String? authProvider; // 'google' | 'email'

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
    this.contractType,
    this.needsContractType = false,
    this.authProvider,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    try {
      return UserModel(
        uid: id,
        email: map['email']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        role: map['role']?.toString() ?? 'employee',
        workType: map['workType']?.toString() ?? 'Full-time',
        monthlyTargetHours: (map['monthlyTargetHours'] as num?)?.toInt() ?? 160,
        primaryLocation: map['primaryLocation']?.toString() ?? 'Gara',
        secondaryLocation: map['secondaryLocation']?.toString() ?? 'Avantgarden',
        fcmToken: map['fcmToken']?.toString(),
        availability: map['availability'] is List 
            ? List<String>.from(map['availability']) 
            : null,
        contractType: map['contractType']?.toString(),
        needsContractType: map['needsContractType'] == true,
        authProvider: map['authProvider']?.toString(),
      );
    } catch (e) {
      throw FormatException('Eroare la parsarea UserModel (id: $id). Detalii: $e');
    }
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
      'contractType': contractType,
      'needsContractType': needsContractType,
      'authProvider': authProvider,
    };
  }

  bool get isAdmin => role == 'admin';
}
