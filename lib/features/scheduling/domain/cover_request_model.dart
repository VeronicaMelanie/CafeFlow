class CoverRequestModel {
  final String id;
  final String shiftId;
  final String employeeUid;
  final String employeeName;
  final DateTime date;
  final String location;
  final String status;

  const CoverRequestModel({
    required this.id,
    required this.shiftId,
    required this.employeeUid,
    required this.employeeName,
    required this.date,
    required this.location,
    required this.status,
  });

  bool get isPending => status == 'pending';
}
