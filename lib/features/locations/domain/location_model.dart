/// Location as returned by GET /api/locations.
///
/// [id] is the PostgreSQL UUID. [code] and [name] are not interchangeable:
/// Firestore and current UI use [name] (e.g. `Gara`), never [code] (`gara`).
class LocationModel {
  const LocationModel({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
    this.openedOn,
    this.closedOn,
  });

  final String id;
  final String code;
  final String name;
  final bool isActive;
  final String? openedOn;
  final String? closedOn;

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final code = json['code']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    if (id.isEmpty || code.isEmpty || name.isEmpty) {
      throw FormatException('Invalid location JSON: $json');
    }
    return LocationModel(
      id: id,
      code: code,
      name: name,
      isActive: json['is_active'] == true,
      openedOn: json['opened_on']?.toString(),
      closedOn: json['closed_on']?.toString(),
    );
  }
}
