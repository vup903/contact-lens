import 'package:flutter/material.dart';

void main() {
  runApp(const ContactLensApp());
}

class ContactLensApp extends StatelessWidget {
  const ContactLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contact Lens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2457E6)),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Contact Lens'),
        ),
      ),
    );
  }
}

