import 'dart:developer';

import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  ServiceProtocolInfo info = await Service.getInfo();
  var serverUri = info.serverUri;
  if (serverUri != null) {
    VmService vmService = await vmServiceConnectUri(
        convertToWebSocketUrl(serviceProtocolUrl: serverUri).toString());
    print('success ${(await vmService.getVM()).version}');
  }
}
