import '../../auth/domain/user_model.dart';

bool employeeHasLocation(UserModel user, String location) {
  return user.primaryLocation == location ||
      user.secondaryLocation == location;
}

String effectiveLocationForEmployee(UserModel user, String selectedLocation) {
  if (employeeHasLocation(user, selectedLocation)) {
    return selectedLocation;
  }
  return user.primaryLocation;
}
