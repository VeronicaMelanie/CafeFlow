import '../../../core/api/api_datetime.dart';

class ConsumptionModel {
  final String id;
  final String userId;
  final String productName;
  final int quantity;
  final DateTime date;
  final DateTime? loggedAt;
  final String? notes;

  ConsumptionModel({
    required this.id,
    required this.userId,
    required this.productName,
    required this.quantity,
    required this.date,
    this.loggedAt,
    this.notes,
  });

  /// Date shown in the log: calendar day from `consumed_on`, clock from `logged_at`.
  DateTime get displayDateTime {
    final logged = loggedAt;
    if (logged == null) return date;
    return DateTime(
      date.year,
      date.month,
      date.day,
      logged.hour,
      logged.minute,
    );
  }

  /// Maps GET /api/consumptions JSON.
  /// [firebaseUid] is the Firebase UID for API `user_id`.
  /// [productName] is ProductModel.name for API `product_id`.
  factory ConsumptionModel.fromApiJson(
    Map<String, dynamic> json, {
    required String firebaseUid,
    required String productName,
  }) {
    final loggedAtRaw = json['logged_at']?.toString();
    return ConsumptionModel(
      id: json['id']?.toString() ?? '',
      userId: firebaseUid,
      productName: productName,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      date: ApiDateTime.parseDateOnly(json['consumed_on']?.toString() ?? ''),
      loggedAt: loggedAtRaw == null || loggedAtRaw.isEmpty
          ? null
          : ApiDateTime.parseTimestamptz(loggedAtRaw),
      notes: json['notes']?.toString(),
    );
  }
}
