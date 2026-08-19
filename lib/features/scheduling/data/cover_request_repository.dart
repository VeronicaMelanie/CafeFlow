import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/cover_request_model.dart';
import '../domain/shift_model.dart';

class CoverRequestRepository {
  CoverRequestRepository({
    FirebaseFirestore? firestore,
    required AuthRepository authRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = authRepository;

  final FirebaseFirestore _firestore;
  final AuthRepository _auth;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('cover_requests');

  Stream<List<CoverRequestModel>> watchPending() {
    return _col.where('status', isEqualTo: 'pending').snapshots().map((snap) {
      final items = snap.docs.map(_fromDoc).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      return items;
    });
  }

  Stream<List<CoverRequestModel>> watchForEmployee(String uid) {
    return watchPending().map(
      (items) => items.where((item) => item.employeeUid == uid).toList(),
    );
  }

  Future<void> requestCover({
    required ShiftModel shift,
    required String employeeName,
  }) async {
    final existing = await _col
        .where('shiftId', isEqualTo: shift.id)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    await _col.add({
      'shiftId': shift.id,
      'employeeUid': shift.userId,
      'employeeName': employeeName,
      'date': Timestamp.fromDate(
        DateTime(shift.date.year, shift.date.month, shift.date.day),
      ),
      'location': shift.location,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final when = '${shift.date.day}/${shift.date.month} la ${shift.location}';
    await _auth.sendNotificationToAdmins(
      title: 'Este nevoie de înlocuire',
      body: '$employeeName nu poate lucra $when. Atribuie un înlocuitor.',
    );
    final employees = await _auth.getAllEmployees().first;
    await _auth.sendNotificationToUids(
      uids: [
        for (final employee in employees)
          if (employee.uid != shift.userId) employee.uid,
      ],
      title: 'Este nevoie de înlocuire',
      body: 'Cineva nu poate lucra $when. Spune managerului dacă poți prelua tura.',
    );
  }

  Future<void> markHandled(String id) async {
    if (id.isEmpty) return;
    await _col.doc(id).update({'status': 'handled'});
  }

  CoverRequestModel _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final dateRaw = data['date'];
    DateTime date = DateTime.now();
    if (dateRaw is Timestamp) {
      date = dateRaw.toDate();
    }
    return CoverRequestModel(
      id: doc.id,
      shiftId: data['shiftId']?.toString() ?? '',
      employeeUid: data['employeeUid']?.toString() ?? '',
      employeeName: data['employeeName']?.toString() ?? '',
      date: DateTime(date.year, date.month, date.day),
      location: data['location']?.toString() ?? '',
      status: data['status']?.toString() ?? 'pending',
    );
  }
}
