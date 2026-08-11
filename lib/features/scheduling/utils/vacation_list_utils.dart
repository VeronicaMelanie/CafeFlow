import '../domain/vacation_model.dart';

/// Sorting and filtering helpers for vacation request lists.
class VacationListUtils {
  VacationListUtils._();

  static int compareByRequestDate(VacationModel a, VacationModel b) {
    final byRequestedAt = b.requestedAt.compareTo(a.requestedAt);
    if (byRequestedAt != 0) return byRequestedAt;
    return b.id.compareTo(a.id);
  }

  static List<VacationModel> sortByRequestDateNewestFirst(
    List<VacationModel> vacations,
  ) {
    final sorted = List<VacationModel>.from(vacations);
    sorted.sort(compareByRequestDate);
    return sorted;
  }

  static List<VacationModel> filterByStatus(
    List<VacationModel> vacations,
    String status,
  ) {
    return sortByRequestDateNewestFirst(
      vacations.where((vacation) => vacation.status == status).toList(),
    );
  }
}
