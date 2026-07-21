// lib/providers/ride_requests_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class RideRequestsService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Future<bool> isRideCompleted(String driverId, String requestId) async {
    try {
      final snapshot = await _dbRef.child('rideRequests/$driverId/$requestId').get();

      if (snapshot.exists && snapshot.value is Map) {
        final rideRequest = Map<String, dynamic>.from(snapshot.value as Map);
        if(rideRequest['status'] == 'completed') {
          print('Ride request is completed for requestId: $requestId');
        } else {
          print('Ride request is not completed for requestId: $requestId');
        }
        return rideRequest['status'] == 'completed';
      }
      print('Ride request not found or not a map for requestId: $requestId');
      return false;
    } catch (e) {
      print('Error checking ride status: $e');
      return false;
    }
  }

  // Fetch all ride requests for a specific driver
  Future<Map<String, Map<String, dynamic>>> fetchDriverRideRequests(String driverId) async {
    try {
      print('Fetching ride requests for driverId: $driverId');
      final snapshot = await _dbRef.child('rideRequests/$driverId').get();

      if (snapshot.exists && snapshot.value is Map) {
        Map<dynamic, dynamic> rawData = snapshot.value as Map;
        Map<String, Map<String, dynamic>> result = {};

        rawData.forEach((key, value) {
          result[key.toString()] = Map<String, dynamic>.from(value as Map);
        });

        return result;
      } else {
        print('No ride requests found for driverId: $driverId');
        return {};
      }
    } catch (e) {
      print('Error fetching ride requests: $e');
      return {};
    }
  }

  // Method to accept a specific ride request
  Future<bool> acceptRideRequest(String driverId, String requestId) async {
    try {
      await _dbRef.child('rideRequests/$driverId/$requestId').update({
        'status': 'accepted',
        'acceptedAt': ServerValue.timestamp,
      });
      print('Ride request accepted: $requestId by driver: $driverId');
      return true;
    } catch (e) {
      print('Error accepting ride request: $e');
      return false;
    }
  }

  // Method to reject/remove a specific ride request
  Future<bool> rejectRideRequest(String driverId, String requestId) async {
    try {
      await _dbRef.child('rideRequests/$driverId/$requestId').remove();
      print('Ride request rejected: $requestId');
      return true;
    } catch (e) {
      print('Error rejecting ride request: $e');
      return false;
    }
  }

  // Get an accepted ride request for a specific user
  Future<Map<String, dynamic>?> getAcceptedRideRequest(String userId) async {
    try {
      // We need to search all drivers since we can't query by userId directly
      final snapshot = await _dbRef.child('rideRequests').get();

      if (snapshot.exists && snapshot.value is Map) {
        final driversMap = snapshot.value as Map;

        for (var driverId in driversMap.keys) {
          final driverRequests = driversMap[driverId] as Map?;
          if (driverRequests != null) {
            for (var requestId in driverRequests.keys) {
              final request = Map<String, dynamic>.from(driverRequests[requestId]);
              if (request['userId'] == userId && request['status'] == 'accepted') {
                request['requestId'] = requestId;
                request['driverId'] = driverId;
                return request;
              }
            }
          }
        }
      }
      print('No accepted ride found for userId: $userId');
      return null;
    } catch (e) {
      print('Error fetching accepted ride: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchCompletedRides(String userId) async {
    try {
      // With the new structure, we need to query all driver nodes
      final snapshot = await _dbRef.child('rideRequests').get();
      List<Map<String, dynamic>> completedRides = [];

      if (snapshot.exists && snapshot.value is Map) {
        Map<dynamic, dynamic> allDrivers = snapshot.value as Map;

        // Iterate through all drivers
        allDrivers.forEach((driverId, driverRequests) {
          if (driverRequests is Map) {
            // Iterate through all requests for this driver
            driverRequests.forEach((requestId, requestData) {
              if (requestData is Map) {
                Map<String, dynamic> request = Map<String, dynamic>.from(requestData);

                // Check if this is a completed ride for our user
                if (request['userId'] == userId && request['status'] == 'completed') {
                  request['requestId'] = requestId;
                  request['driverId'] = driverId;
                  completedRides.add(request);
                }
              }
            });
          }
        });

        // Sort by completion time if available (newest first)
        completedRides.sort((a, b) {
          int? timeA = a['completedAt'] as int?;
          int? timeB = b['completedAt'] as int?;
          if (timeA == null || timeB == null) return 0;
          return timeB.compareTo(timeA); // Descending order
        });
      }
      return completedRides;
    } catch (e) {
      print('Error fetching completed rides: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getStartedRideRequest(String userId) async {
    try {
      final snapshot = await _dbRef.child('rideRequests').get();

      if (snapshot.exists && snapshot.value is Map) {
        final driversMap = snapshot.value as Map;

        for (var driverId in driversMap.keys) {
          final driverRequests = driversMap[driverId] as Map?;
          if (driverRequests != null) {
            for (var requestId in driverRequests.keys) {
              final request = Map<String, dynamic>.from(driverRequests[requestId]);
              if (request['userId'] == userId && request['status'] == 'active') {
                request['requestId'] = requestId;
                request['driverId'] = driverId;
                return request;
              }
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('Error fetching started ride: $e');
      return null;
    }
  }

  Future<bool> updateRideStatus(String driverId, String requestId, String newStatus) async {
    try {
      await _dbRef.child('rideRequests/$driverId/$requestId').update({
        'status': newStatus,
        'updatedAt': ServerValue.timestamp,
      });
      print('Ride status updated to $newStatus for requestId: $requestId');
      return true;
    } catch (e) {
      print('Error updating ride status: $e');
      return false;
    }
  }

  Future<bool> updateAcceptedRideToStarted(String userId) async {
    try {
      // First find the accepted ride
      final acceptedRide = await getAcceptedRideRequest(userId);

      if (acceptedRide != null) {
        final driverId = acceptedRide['driverId'];
        final requestId = acceptedRide['requestId'];

        // Now update its status
        await _dbRef.child('rideRequests/$driverId/$requestId').update({
          'status': 'active'
        });
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating ride status: $e');
      return false;
    }
  }

  // Updated to work with requestId instead of userId
  Future<void> completeRideRequest(String driverId, String requestId, {double? additionalFare, double? totalFare}) async {
    try {
      Map<String, dynamic> updateData = {
        'status': 'completed',
        'completedAt': ServerValue.timestamp,
      };

      // Update the fare to the total fare value
      if (totalFare != null) {
        updateData['fare'] = totalFare.toString(); // Convert to string to match your DB structure
      }

      // Add additional charges if any
      if (additionalFare != null && additionalFare > 0) {
        updateData['waitingCharge'] = additionalFare;
      }

      await _dbRef.child('rideRequests/$driverId/$requestId').update(updateData);
      print('Ride completed successfully with ID: $requestId');

      if (additionalFare != null && additionalFare > 0) {
        print('Added waiting charge: Rs${additionalFare.toStringAsFixed(1)}');
        print('Updated total fare: Rs${totalFare?.toStringAsFixed(1)}');
      }
    } catch (e) {
      print('Error completing ride: $e');
      throw e;
    }
  }

  // Add this method to RideRequestsService to maintain backward compatibility
  Future<Map<String, dynamic>?> findUserActiveRide(String userId) async {
    try {
      // Get all drivers
      final snapshot = await _dbRef.child('rideRequests').get();

      if (snapshot.exists && snapshot.value is Map) {
        Map<dynamic, dynamic> allDrivers = snapshot.value as Map;

        // Iterate through each driver's ride requests
        for (var driverId in allDrivers.keys) {
          final driverRequests = allDrivers[driverId] as Map?;

          if (driverRequests != null) {
            // Iterate through all requests for this driver
            for (var requestId in driverRequests.keys) {
              final request = Map<String, dynamic>.from(driverRequests[requestId]);

              // Check if this is an active ride for our user
              if (request['userId'] == userId && request['status'] == 'active') {
                request['requestId'] = requestId;
                request['driverId'] = driverId;
                return request;
              }
            }
          }
        }
      }

      print('No active ride found for userId: $userId');
      return null;
    } catch (e) {
      print('Error finding active ride: $e');
      return null;
    }
  }

  // Get a specific ride request by ID
  Future<Map<String, dynamic>?> getRideRequestById(String driverId, String requestId) async {
    try {
      final snapshot = await _dbRef.child('rideRequests/$driverId/$requestId').get();

      if (snapshot.exists && snapshot.value is Map) {
        Map<String, dynamic> request = Map<String, dynamic>.from(snapshot.value as Map);
        request['requestId'] = requestId;
        request['driverId'] = driverId;
        return request;
      }
      return null;
    } catch (e) {
      print('Error fetching ride by ID: $e');
      return null;
    }
  }

  // Add to RideRequestsService class
  Future<Map<String, dynamic>?> fetchRideRequests(String driverId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      print('Fetching ride request for driverId: $driverId and userId: $userId');

      final snapshot = await _dbRef.child('rideRequests/$driverId').get();

      if (snapshot.exists && snapshot.value is Map) {
        Map<dynamic, dynamic> requests = snapshot.value as Map;

        // Filter for the current user's ride
        for (var requestId in requests.keys) {
          Map<String, dynamic> request = Map<String, dynamic>.from(requests[requestId]);
          if (request['userId'] == userId &&
              (request['status'] == 'active' || request['status'] == 'accepted')) {
            // Add the requestId to the data
            request['requestId'] = requestId;
            request['driverId'] = driverId;
            return request;
          }
        }
      }
      print('No matching ride request found for driverId: $driverId and userId: $userId');
      return null;
    } catch (e) {
      print('Error fetching ride request: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchDriverAcceptedOrActiveRide(String driverId) async {
    try {
      final snapshot = await _dbRef.child('rideRequests/$driverId').get();

      if (snapshot.exists && snapshot.value is Map) {
        Map<dynamic, dynamic> requests = snapshot.value as Map;

        // Look for any accepted or active rides
        for (var requestId in requests.keys) {
          Map<String, dynamic> request = Map<String, dynamic>.from(requests[requestId]);
          if (request['status'] == 'accepted' || request['status'] == 'active') {
            request['requestId'] = requestId;
            request['driverId'] = driverId;
            return request;
          }
        }
      }
      print('No accepted or active ride request found for driverId: $driverId');
      return null;
    } catch (e) {
      print('Error fetching ride request: $e');
      return null;
    }
  }

  // Add this method to the RideRequestsService class
  Future<List<Map<String, dynamic>>> fetchCompletedRidesForDriver(String driverId) async {
    try {
      final snapshot = await _dbRef.child('rideRequests/$driverId').get();

      if (snapshot.exists && snapshot.value is Map) {
        Map<dynamic, dynamic> requests = snapshot.value as Map;
        List<Map<String, dynamic>> completedRides = [];

        requests.forEach((requestId, data) {
          Map<String, dynamic> request = Map<String, dynamic>.from(data);
          if (request['status'] == 'completed') {
            request['requestId'] = requestId;
            request['driverId'] = driverId;
            completedRides.add(request);
          }
        });

        return completedRides;
      }
      return [];
    } catch (e) {
      print('Error fetching completed rides for driver: $e');
      return [];
    }
  }
  // Add to lib/providers/ride_requests_service.dart

// Create a new ride request with a unique ID
  Future<String?> createRideRequest(
      String driverId, String userId, Map<String, dynamic> rideDetails) async {
    try {
      // Always create a properly nested structure using push() to generate a unique request ID
      DatabaseReference newRequestRef = _dbRef.child('rideRequests/$driverId').push();
      String requestId = newRequestRef.key!;

      // Create the new ride request data
      Map<String, dynamic> requestData = {
        'requestId': requestId,  // Store the ID within the data for easier reference
        'userId': userId,
        'driverId': driverId,
        'pickupLocation': rideDetails['pickup'],
        'destination': rideDetails['destination'],
        'fare': rideDetails['fare'],
        'ride_type': rideDetails['ride_type'],
        'status': 'pending',
        'timestamp': ServerValue.timestamp,
      };

      // Store the request at the specific path with the generated ID
      await newRequestRef.set(requestData);

      print("Ride request created successfully with ID: $requestId");
      return requestId;
    } catch (e) {
      print("Error creating ride request: $e");
      return null;
    }
  }

// Cancel a ride request
  Future<bool> cancelRideRequest(String driverId, String requestId) async {
    try {
      await _dbRef.child('rideRequests/$driverId/$requestId').remove();
      print("Ride request canceled successfully: $requestId");
      return true;
    } catch (e) {
      print("Error canceling ride request: $e");
      return false;
    }
  }

// Get pending ride requests for a driver
  Stream<DatabaseEvent> listenToRideRequest(String driverId, String requestId) {
    return _dbRef.child('rideRequests/$driverId/$requestId').onValue;
  }

  // Add to RideRequestsService class
  DatabaseReference getRideRequestsRef(String driverId) {
    return _dbRef.child('rideRequests/$driverId');
  }

  // Add to RideRequestsService class
  DatabaseReference getRideRequestRefRider(String requestId, String driverId) {
    return _dbRef.child('rideRequests/$driverId/$requestId');
  }

  // Add to RideRequestsService class
  DatabaseReference getWaitingTimeRef(String requestId) {
    return _dbRef.child('rideRequests/$requestId/waitingTime');
  }

  // Add to RideRequestsService class
  Stream<String?> getRideStatusStream(String driverId, String requestId) {
    return _dbRef.child('rideRequests/$driverId/$requestId/status').onValue.map(
            (event) => event.snapshot.exists ? event.snapshot.value as String? : null
    );
  }

  Future<String?> fetchFcmTokenByDriverId(String driverId) async {
    DatabaseReference usersRef = FirebaseDatabase.instance.ref().child('users');
    DatabaseEvent event = await usersRef.once();
    if (event.snapshot.exists) {
      Map<String, dynamic> users = Map<String, dynamic>.from(event.snapshot.value as Map);
      for (var userId in users.keys) {
        Map<String, dynamic> user = Map<String, dynamic>.from(users[userId]);
        if (user['driverId'] == driverId) {
          return user['fcmToken'];
        }
      }
    }
    return null;
  }

  // Add this to your RideRequestsService class (ride_requests_service.dart)
  Future<void> updateRideRequestDestination(String driverId, String requestId, String newDestination, double newFare) async {
    try {
      await _dbRef.child('rideRequests/$driverId/$requestId').update({
        'destination': newDestination,
        'fare': newFare,
      });
    } catch (e) {
      throw Exception('Failed to update destination');
    }
  }
}