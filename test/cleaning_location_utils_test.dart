import 'package:fivetogo_scheduler/features/auth/domain/user_model.dart';
import 'package:fivetogo_scheduler/features/cleaning/utils/cleaning_location_utils.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel _user({
  String primary = 'Gara',
  String secondary = 'Avantgarden',
}) {
  return UserModel(
    uid: 'employee-1',
    email: 'test@example.com',
    name: 'Test User',
    role: 'employee',
    workType: 'Full-time',
    monthlyTargetHours: 160,
    primaryLocation: primary,
    secondaryLocation: secondary,
  );
}

void main() {
  test('employeeHasLocation accepts primary and secondary locations', () {
    final user = _user();
    expect(employeeHasLocation(user, 'Gara'), isTrue);
    expect(employeeHasLocation(user, 'Avantgarden'), isTrue);
    expect(employeeHasLocation(user, 'Other'), isFalse);
  });

  test('effectiveLocationForEmployee keeps valid selection', () {
    final user = _user(primary: 'Avantgarden', secondary: 'Gara');
    expect(
      effectiveLocationForEmployee(user, 'Gara'),
      'Gara',
    );
  });

  test('effectiveLocationForEmployee falls back to primary location', () {
    final user = _user(primary: 'Avantgarden', secondary: 'Avantgarden');
    expect(
      effectiveLocationForEmployee(user, 'Gara'),
      'Avantgarden',
    );
  });
}
