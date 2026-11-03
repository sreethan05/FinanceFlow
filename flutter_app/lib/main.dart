import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'src/api/finance_api.dart';
import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationSupportDirectory();
  final cookieDirectory = Directory('${directory.path}/cookies');
  await cookieDirectory.create(recursive: true);
  final api = FinanceApi.create(cookieDirectory: cookieDirectory.path);
  runApp(FinanceFlowApp(api: api));
}
