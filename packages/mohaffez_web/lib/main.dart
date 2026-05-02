import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase init will be added in Prompt 4 once firebase_options.dart is generated
  runApp(const ProviderScope(child: MohaffezWebApp()));
}
