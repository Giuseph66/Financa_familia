import 'package:financa/app/app.dart';
import 'package:financa/core/supabase/supabase_bootstrap.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await SupabaseBootstrap.initialize();
  runApp(FinancaApp(bootstrap: bootstrap));
}
