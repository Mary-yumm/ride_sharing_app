import 'package:flutter/material.dart';
import 'package:ride_sharing_app/utils/app_colors.dart';

class OptionsBottomSheet extends StatefulWidget {
  @override
  _OptionsBottomSheetState createState() => _OptionsBottomSheetState();
}

class _OptionsBottomSheetState extends State<OptionsBottomSheet> {
  bool _moreThanFourPassengers = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with title and close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Options',
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Theme.of(context).hintColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.0),

                  // Switch for "More than 4 passengers"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'More than 4 passengers',
                        style: TextStyle(color: Theme.of(context).hintColor, fontSize: 16.0),
                      ),
                      Switch(
                        value: _moreThanFourPassengers,
                        onChanged: (value) {
                          setState(() {
                            _moreThanFourPassengers = value;
                          });
                        },
                        activeColor: AppColors.secondary.value,
                      ),
                    ],
                  ),
                  SizedBox(height: 16.0),

                  // Comments Text Field
                  TextField(
                    style: TextStyle(color: AppColors.primary), // Text color
                    decoration: InputDecoration(
                      hintText: 'Comments',
                      hintStyle: TextStyle(color: AppColors.textGrey),
                      filled: true,
                      fillColor: AppColors.lightGrey,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.0),

                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary.value,
                        foregroundColor: AppColors.white,
                        minimumSize: Size(double.infinity, 48.0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
