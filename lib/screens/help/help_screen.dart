import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';

class FAQScreen extends StatelessWidget {
  static const String idScreen = "FaqScreen";

  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: const [
          FAQCategory(
            category: 'My profile',
            faqs: [
              FAQItem(title: 'My account is blocked', screen: FAQDetailScreen(detail: 'My account is blocked info')),
              FAQItem(title: 'How to change my info?', screen: FAQDetailScreen(detail: 'How to change info?')),
              FAQItem(title: 'How to delete my account?', screen: FAQDetailScreen(detail: 'How to delete account info')),
            ],
          ),
          FAQCategory(
            category: 'Safety',
            faqs: [
              FAQItem(title: 'Driver verification', screen: FAQDetailScreen(detail: 'Driver verification info')),
              FAQItem(title: 'Safety tips', screen: FAQDetailScreen(detail: 'Safety tips info')),
              FAQItem(title: 'Service rules', screen: FAQDetailScreen(detail: 'Service rules info')),
              FAQItem(title: 'Safety features', screen: FAQDetailScreen(detail: 'Safety features info')),
              FAQItem(title: 'Information security', screen: FAQDetailScreen(detail: 'Information security info')),
              FAQItem(title: 'Insurance', screen: FAQDetailScreen(detail: 'Insurance info')),
            ],
          ),
          FAQCategory(
            category: 'Payment',
            faqs: [
              FAQItem(title: 'How much should I offer?', screen: FAQDetailScreen(detail: 'How much should I offer? info')),
              FAQItem(title: 'Payment methods', screen: FAQDetailScreen(detail: 'Payment methods info')),
              FAQItem(title: 'Toll roads', screen: FAQDetailScreen(detail: 'Toll roads info')),
            ],
          ),
          FAQCategory(
            category: 'Before the Ride',
            faqs: [
              FAQItem(title: 'How to find a driver?', screen: FAQDetailScreen(detail: 'How much should I offer? info')),
              FAQItem(title: 'How to join a ride in RideShare?', screen: FAQDetailScreen(detail: 'Payment methods info')),
              FAQItem(title: 'How to cancel an accpeted order?', screen: FAQDetailScreen(detail: 'Toll roads info')),
            ],
          ),
          FAQCategory(
            category: 'Order Issues',
            faqs: [
              FAQItem(title: 'Driver asked to cancel', screen: FAQDetailScreen(detail: 'How much should I offer? info')),
              FAQItem(title: 'I left my belongings in the car', screen: FAQDetailScreen(detail: 'Payment methods info')),
              FAQItem(title: 'Different driver or car', screen: FAQDetailScreen(detail: 'Toll roads info')),
            ],
          ),
          FAQCategory(
            category: 'Questions about drivers',
            faqs: [
              FAQItem(title: 'How to call the driver?', screen: FAQDetailScreen(detail: 'How much should I offer? info')),
              FAQItem(title: 'Driver asked to cancel', screen: FAQDetailScreen(detail: 'Payment methods info')),
              FAQItem(title: 'How to becoms a driver?', screen: FAQDetailScreen(detail: 'Toll roads info')),
            ],
          ),
        ],
      ),
    );
  }
}

class FAQCategory extends StatelessWidget {
  final String category;
  final List<FAQItem> faqs;

  const FAQCategory({super.key, required this.category, required this.faqs});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        category,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      children: faqs,
    );
  }
}

class FAQItem extends StatelessWidget {
  final String title;
  final Widget screen;

  const FAQItem({super.key, required this.title, required this.screen});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
            fontSize: 14, // Set the font size here
            //fontWeight: FontWeight.w500, // Optional: adjust font weight
            //fontFamily: 'Brand-Regular'
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 15, // Set the icon size here
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      },
    );
  }
}


class FAQDetailScreen extends StatelessWidget {
  final String detail;

  const FAQDetailScreen({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("FAQ Detail"),
        foregroundColor: Theme.of(context).hintColor,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          detail,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
