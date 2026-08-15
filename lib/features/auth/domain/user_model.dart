import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  /// Firebase UID — the authentication identity. Never replace this with the
  /// PostgreSQL UUID.
  final String uid;
  /// PostgreSQL `users.id`. Mapping only; not used for Firebase Auth.
  final String? postgresId;
  final String email;
  final String name;
  final String role; // 'employee' or 'admin'
  final String workType; // legacy display field: 'Full-time' or 'Part-time'
  final int monthlyTargetHours;
  final String primaryLocation;
  final String secondaryLocation;
  final DateTime? employmentDate;
  final String? fcmToken;
  final List<String>? availability; // Store dates in ISO format
  final String? contractType; // 'full_time' | 'part_time'
  final bool needsContractType;
  final String? authProvider; // 'google' | 'email'

  UserModel({
    required this.uid,
    this.postgresId,
    required this.email,
    required this.name,
    required this.role,
    required this.workType,
    required this.monthlyTargetHours,
    required this.primaryLocation,
    required this.secondaryLocation,
    this.employmentDate,
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
        employmentDate: map['employmentDate'] is Timestamp
            ? (map['employmentDate'] as Timestamp).toDate()
            : null,
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

  /// Maps GET /api/users JSON. [uid] is `firebase_uid`, [postgresId] is `id`.
  factory UserModel.fromApiJson(
    Map<String, dynamic> json, {
    required String primaryLocation,
    required String secondaryLocation,
  }) {
    final firebaseUid = json['firebase_uid']?.toString() ?? '';
    if (firebaseUid.isEmpty) {
      throw FormatException('API user missing firebase_uid: $json');
    }
    final contractType = json['contract_type']?.toString();
    final employment = json['employment_started_on']?.toString();
    return UserModel(
      uid: firebaseUid,
      postgresId: json['id']?.toString(),
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'employee',
      workType: _workTypeFromContract(contractType),
      monthlyTargetHours:
          (json['monthly_target_hours'] as num?)?.toInt() ?? 160,
      primaryLocation: primaryLocation,
      secondaryLocation: secondaryLocation,
      employmentDate: _parseDateOnly(employment),
      contractType: contractType,
      needsContractType: json['needs_contract_type'] == true,
      authProvider: json['auth_provider']?.toString(),
    );
  }

  static String _workTypeFromContract(String? contractType) {
    if (contractType == 'part_time') return 'Part-time';
    if (contractType == 'full_time') return 'Full-time';
    return 'Full-time';
  }

  static DateTime? _parseDateOnly(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
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
      if (employmentDate != null)
        'employmentDate': Timestamp.fromDate(employmentDate!),
      'fcmToken': fcmToken,
      'availability': availability,
      'contractType': contractType,
      'needsContractType': needsContractType,
      'authProvider': authProvider,
    };
  }

  bool get isAdmin => role == 'admin';
}
