import '../domain/location_model.dart';

/// Helpers for the locations catalog. Always treat [LocationModel.name] as the
/// Firestore / UI identity. Never use [LocationModel.code] in queries or labels.
class LocationCatalog {
  LocationCatalog._();

  static const preferredDisplayName = 'Gara';

  static List<LocationModel> active(List<LocationModel> locations) {
    return locations.where((location) => location.isActive).toList();
  }

  static List<String> names(List<LocationModel> locations) {
    return active(locations).map((location) => location.name).toList();
  }

  static String preferredName(List<LocationModel> locations) {
    final list = names(locations);
    if (list.contains(preferredDisplayName)) return preferredDisplayName;
    return list.isNotEmpty ? list.first : preferredDisplayName;
  }

  static String? otherName(List<LocationModel> locations, String name) {
    for (final candidate in names(locations)) {
      if (candidate != name) return candidate;
    }
    return null;
  }

  static LocationModel? byId(List<LocationModel> locations, String id) {
    for (final location in locations) {
      if (location.id == id) return location;
    }
    return null;
  }

  static LocationModel? byCode(List<LocationModel> locations, String code) {
    for (final location in locations) {
      if (location.code == code) return location;
    }
    return null;
  }

  static LocationModel? byName(List<LocationModel> locations, String name) {
    for (final location in locations) {
      if (location.name == name) return location;
    }
    return null;
  }
}
