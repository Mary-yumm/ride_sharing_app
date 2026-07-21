import 'package:flutter/material.dart';

class AutocompleteScreen extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(String) onSelected;
  final Future<List<String>> Function(String) fetchSuggestions;
  final String? currentLocation; // Pass the current location

  const AutocompleteScreen({
    Key? key,
    required this.controller,
    required this.hintText,
    required this.onSelected,
    required this.fetchSuggestions,
    this.currentLocation, // Optional current location
  }) : super(key: key);

  @override
  _AutocompleteScreenState createState() => _AutocompleteScreenState();
}

class _AutocompleteScreenState extends State<AutocompleteScreen> {
  List<String> _suggestions = [];

  void _onTextChanged(String value) async {
    if (value.isNotEmpty) {
      final suggestions = await widget.fetchSuggestions(value);
      if (mounted) { // Check if the widget is still mounted
        setState(() {
          _suggestions = suggestions;
        });
      }
    } else {
      if (mounted) { // Check if the widget is still mounted
        setState(() {
          _suggestions = [];
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      _onTextChanged(widget.controller.text);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(() {
      _onTextChanged(widget.controller.text);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hintText),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: widget.controller,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    if (mounted) { // Check if the widget is still mounted
                      setState(() {
                        widget.controller.clear();
                        _suggestions = [];
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          if (widget.hintText == 'From' && widget.currentLocation != null) // Add "Set Current Location" only for "From"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.my_location),
                label: const Text('Set Current Location'),
                onPressed: () {
                  if (mounted) { // Check if the widget is still mounted
                    setState(() {
                      widget.controller.text = widget.currentLocation!;
                      _suggestions = [];
                    });
                  }
                },
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  title: Text(suggestion),
                  onTap: () {
                    widget.onSelected(suggestion);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
