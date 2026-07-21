import 'package:ride_sharing_app/screens/home/active_nearby_available_drivers.dart';

class GeoFireAssistant{
  static List<ActiveNearByAvailableDrivers> activeNearByAvailableDriversList = [];
  static void deleteOfflineDriverFromList(String driverId) {
    int indexNumber = activeNearByAvailableDriversList.indexWhere((element) => element.driverId == driverId);
    if (indexNumber != -1) { // Check if driver exists
      activeNearByAvailableDriversList.removeAt(indexNumber);
    }
  }

  static void updateActiveNearByAvailableDriverLocation(ActiveNearByAvailableDrivers driverWhoMove) {
    int indexNumber = activeNearByAvailableDriversList.indexWhere((element) => element.driverId == driverWhoMove.driverId);
    if (indexNumber != -1) { // Check if driver exists
      activeNearByAvailableDriversList[indexNumber].locationLatitude = driverWhoMove.locationLatitude;
      activeNearByAvailableDriversList[indexNumber].locationLongitude = driverWhoMove.locationLongitude;
    }
  }

}