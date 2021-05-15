import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_detector/leak_detector.dart';

void main() {
  const MethodChannel channel = MethodChannel('leak_detector');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });
}
