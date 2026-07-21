// lib/screens/driver/home/ACControlWidget.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ride_sharing_app/utils/app_colors.dart';

class ACControlWidget extends StatefulWidget {
  final String requestId;

  const ACControlWidget({
    Key? key,
    required this.requestId,
  }) : super(key: key);

  @override
  _ACControlWidgetState createState() => _ACControlWidgetState();
}

class _ACControlWidgetState extends State<ACControlWidget> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  bool _isACOn = true; // Default is ON for AC rides
  double _discountAmount = 0.0; // Discount for turning AC OFF
  int _acOffStartTime = 0; // Timestamp when AC was turned off
  double _totalDistanceKm = 0.0; // Total ride distance in km
  late Stream<DatabaseEvent> _acStatusStream;
  late Stream<DatabaseEvent> _rideDetailsStream;

  // Constants for AC pricing model
  static const double PER_KM_RIDE_AC = 60.0;
  static const double PER_KM_RIDE = 50.0;
  static const double AC_EXTRA_COST_PER_KM = PER_KM_RIDE_AC - PER_KM_RIDE; // 10 per km

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupStreams();
  }

  void _setupStreams() {
    _acStatusStream = _dbRef.child('rideRequests/${widget.requestId}/acStatus').onValue;
    _rideDetailsStream = _dbRef.child('rideRequests/${widget.requestId}').onValue;
  }

  Future<void> _loadData() async {
    await _loadRideDetails();
    await _loadACStatus();
  }

  Future<void> _loadRideDetails() async {
    try {
      DatabaseEvent event = await _dbRef
          .child('rideRequests/${widget.requestId}')
          .once();

      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          // Calculate total distance in km
          _totalDistanceKm = data['distance'] != null
              ? double.parse(data['distance'].toString()) / 1000
              : 0.0;
        });
        print('Loaded ride distance: $_totalDistanceKm km');
      }
    } catch (e) {
      print('Error loading ride details: $e');
    }
  }

  Future<void> _loadACStatus() async {
    try {
      DatabaseEvent event = await _dbRef
          .child('rideRequests/${widget.requestId}/acStatus')
          .once();

      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _isACOn = data['isOn'] ?? true;
          _discountAmount = (data['discountAmount'] ?? 0.0).toDouble();
          _acOffStartTime = data['acOffStartTime'] ?? 0;
        });
      } else {
        // Initialize AC status as ON by default for AC rides
        _saveToFirebase();
      }
    } catch (e) {
      print('Error loading AC status: $e');
    }
  }

  Future<void> _saveToFirebase() async {
    try {
      await _dbRef.child('rideRequests/${widget.requestId}/acStatus').update({
        'isOn': _isACOn,
        'discountAmount': _discountAmount,
        'acOffStartTime': _acOffStartTime,
        'lastUpdated': ServerValue.timestamp,
      });

      // Also update the main ride request to apply the discount
      await _dbRef.child('rideRequests/${widget.requestId}').update({
        'acDiscountAmount': _discountAmount,
      });
    } catch (e) {
      print('Error saving AC status: $e');
    }
  }

  void _toggleAC(BuildContext context) {
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    if (_isACOn) {
      // Turning AC OFF - start tracking time
      setState(() {
        _isACOn = false;
        _acOffStartTime = currentTime;
      });
    } else {
      // Turning AC ON - calculate discount
      // Get ride start time to calculate total ride duration
      _dbRef.child('rideRequests/${widget.requestId}').get().then((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          int? rideStartTime = data['pickupTime'] is int ? data['pickupTime'] : null;

          if (rideStartTime != null) {
            // Calculate how long the AC was off
            final acOffDurationMin = (currentTime - _acOffStartTime) / 60000; // ms to minutes

            // Calculate total ride time so far
            final totalRideTimeMin = (currentTime - rideStartTime) / 60000;

            // Calculate maximum extra AC charge based on distance
            final maxACCharge = _totalDistanceKm * AC_EXTRA_COST_PER_KM;

            // Calculate discount as proportion of off time to total time
            final newDiscount = (acOffDurationMin / totalRideTimeMin) * maxACCharge;

            // Cap the discount to 50% of maximum AC charge
            final cappedDiscount = newDiscount.clamp(0.0, 0.5 * maxACCharge);

            // Add to existing discount
            final totalDiscount = _discountAmount + cappedDiscount;

            setState(() {
              _isACOn = true;
              _discountAmount = double.parse(totalDiscount.toStringAsFixed(2));
              _acOffStartTime = 0;
            });

            _saveToFirebase();

            // Show detailed info in console for debugging
            print('AC off for: $acOffDurationMin minutes');
            print('Total ride time: $totalRideTimeMin minutes');
            print('Max AC charge: $maxACCharge');
            print('New discount: $cappedDiscount');
            print('Total discount: $_discountAmount');
          } else {
            // Fallback if we can't get the start time
            setState(() {
              _isACOn = true;
              _acOffStartTime = 0;
            });
            _saveToFirebase();
          }
        }
      });
    }

    _saveToFirebase();

    // Show toast/snackbar about AC status change
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isACOn
            ? 'AC turned ON - Total discount: Rs${_discountAmount.toStringAsFixed(1)}'
            : 'AC turned OFF - Discount will be calculated when turned on'),
        duration: Duration(seconds: 2),
        backgroundColor: _isACOn ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Empty spacer for balance
              SizedBox(width: 24),
              // Centered heading
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.ac_unit, color: AppColors.primary, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Air Conditioning',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              // Close button at extreme right
              IconButton(
                icon: Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                splashRadius: 20,
              ),
            ],
          ),
          SizedBox(height: 16.0),

          // AC Status display
          StreamBuilder<DatabaseEvent>(
            stream: _acStatusStream,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.snapshot.exists) {
                final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                _isACOn = data['isOn'] ?? true; // Default to true if not found
                _discountAmount = (data['discountAmount'] ?? 0.0).toDouble();
                _acOffStartTime = data['acOffStartTime'] ?? 0;
              }

              return Container(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                decoration: BoxDecoration(
                  color: _isACOn ?
                  AppColors.secondary.value.withOpacity(0.1) :
                  Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _isACOn ? AppColors.secondary.value : Colors.grey,
                      width: 1.5
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isACOn ? Icons.ac_unit : Icons.ac_unit_outlined,
                      size: 32.0,
                      color: _isACOn ? AppColors.secondary.value : Colors.grey,
                    ),
                    SizedBox(width: 16),
                    Text(
                      _isACOn ? "AC ON" : "AC OFF",
                      style: TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                        color: _isACOn ? AppColors.secondary.value : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Distance and pricing info
          StreamBuilder<DatabaseEvent>(
              stream: _rideDetailsStream,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.snapshot.exists) {
                  final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                  _totalDistanceKm = data['distance'] != null
                      ? double.parse(data['distance'].toString()) / 1000
                      : _totalDistanceKm;
                }

                double maxACCharge = _totalDistanceKm * AC_EXTRA_COST_PER_KM;

                return Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Column(
                    children: [
                      Text(
                        'Trip distance: ${_totalDistanceKm.toStringAsFixed(1)} km',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Maximum AC charge: Rs${maxACCharge.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }
          ),

          // Discount display
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Text(
              'Total discount: Rs${_discountAmount.toStringAsFixed(1)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
                fontSize: 16,
              ),
            ),
          ),

          // Show real-time running discount if AC is OFF
          if (!_isACOn && _acOffStartTime > 0)
            StreamBuilder(
                stream: Stream.periodic(Duration(seconds: 1)),
                builder: (context, snapshot) {
                  final currentTime = DateTime.now().millisecondsSinceEpoch;
                  final offDurationMinutes = (currentTime - _acOffStartTime) / 60000;

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Current session: ${offDurationMinutes.toStringAsFixed(1)} min with AC off',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.orange[700],
                        fontSize: 14,
                      ),
                    ),
                  );
                }
            ),

          SizedBox(height: 16.0),

          // Toggle button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _toggleAC(context),
              icon: Icon(
                  _isACOn ? Icons.power_settings_new : Icons.power_off_outlined,
                  size: 18,
                  color: Colors.white
              ),
              label: Text(_isACOn ? 'Turn AC OFF' : 'Turn AC ON'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isACOn ? Colors.orange : Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}