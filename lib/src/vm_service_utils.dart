// Copyright (c) 2021, Jiakuo Liu. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:developer';
import 'dart:io';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';
import 'package:vm_service/utils.dart';

const String _findLibrary = 'package:leak_detector/src/vm_service_utils.dart';

///VmServer api tools
class VmServerUtils {
  static VmServerUtils? _instance;
  bool _enable = false;
  Uri? _observatoryUri;
  VmService? _vmService;
  VM? _vm;

  Future<bool> get hasVmService async => (await getVmService()) != null;

  factory VmServerUtils() {
    _instance ??= VmServerUtils._();
    return _instance!;
  }

  bool get isEnable => _enable;

  VmServerUtils._() {
    //init
    assert(() {
      _enable = true;
      return true;
    }());
  }

  ///get VmService's WebSocket uri
  Future<Uri?> getObservatoryUri() async {
    if (_enable) {
      // _observatoryUri = await _channel.invokeMethod('getObservatoryUri');
      ServiceProtocolInfo serviceProtocolInfo = await Service.getInfo();
      _observatoryUri = serviceProtocolInfo.serverUri;
    }
    return _observatoryUri;
  }

  ///VmService
  Future<VmService?> getVmService() async {
    if (_vmService == null) {
      final uri = await getObservatoryUri();
      if (uri != null) {
        Uri url = convertToWebSocketUrl(serviceProtocolUrl: uri);
        try {
          _vmService = await vmServiceConnectUri(url.toString());
        } catch (error) {
          if (error is SocketException) {
            //dds is enable
            print('vm_service connection refused, Try:');
            print('run \'flutter run\' with --disable-dds to disable dds.');
          }
        }
      }
    }
    return _vmService;
  }

  Future<VM?> getVM() async {
    if (_vm == null) {
      _vm = await (await getVmService())?.getVM();
    }
    return _vm;
  }

  ///find a [Library] on [Isolate]
  Future<LibraryRef?> findLibrary(String uri) async {
    Isolate? mainIsolate = await findMainIsolate();
    if (mainIsolate != null) {
      final libraries = mainIsolate.libraries;
      if (libraries != null) {
        for (int i = 0; i < libraries.length; i++) {
          var lib = libraries[i];
          if (lib.uri == uri) {
            return lib;
          }
        }
      }
    }
    return null;
  }

  ///find main Isolate in VM
  Future<Isolate?> findMainIsolate() async {
    IsolateRef? ref;
    final vm = await getVM();
    if (vm == null) return null;
    vm.isolates?.forEach((isolate) {
      if (isolate.name == 'main') {
        ref = isolate;
      }
    });
    final vms = await getVmService();
    if (ref?.id != null) {
      return vms?.getIsolate(ref!.id!);
    }
    return null;
  }

  ///get ObjectId in VM by Object
  Future<String?> getObjectId(dynamic obj) async {
    final library = await findLibrary(_findLibrary);
    if (library == null || library.id == null) return null;
    final vms = await getVmService();
    if (vms == null) return null;
    final mainIsolate = await findMainIsolate();
    if (mainIsolate == null || mainIsolate.id == null) return null;
    Response keyResponse =
        await vms.invoke(mainIsolate.id!, library.id!, 'generateNewKey', []);
    final keyRef = InstanceRef.parse(keyResponse.json);
    String? key = keyRef?.valueAsString;
    if (key == null) return null;
    _objCache[key] = obj;

    try {
      Response valueResponse = await vms
          .invoke(mainIsolate.id!, library.id!, "keyToObj", [keyRef!.id!]);
      final valueRef = InstanceRef.parse(valueResponse.json);
      return valueRef?.id;
    } catch (e) {
      print('getObjectId $e');
    } finally {
      _objCache.remove(key);
    }
    return null;
  }

  ///[VmService.invokeMethod]
  Future<String?> invokeMethod(
      String targetId, String method, List<String> argumentIds) async {
    final vms = await getVmService();
    if (vms == null) return null;
    final mainIsolate = await findMainIsolate();
    if (mainIsolate != null && mainIsolate.id != null) {
      try {
        Response valueResponse =
            await vms.invoke(mainIsolate.id!, targetId, method, argumentIds);
        final valueRef = InstanceRef.parse(valueResponse.json);
        return valueRef?.valueAsString;
      } catch (e) {}
    }
    return null;
  }

  ///通过ObjectId获取Instance
  Future<Obj?> getObjectInstanceById(String objId) async {
    final vms = await getVmService();
    if (vms == null) return null;
    final mainIsolate = await findMainIsolate();
    if (mainIsolate != null && mainIsolate.id != null) {
      try {
        Obj object = await vms.getObject(mainIsolate.id!, objId);
        return object;
      } catch (e) {
        print('getObjectInstanceById error:$e');
      }
    }
    return null;
  }

  ///通过Object获取Instance
  Future<Instance?> getInstanceByObject(dynamic obj) async {
    final vms = await getVmService();
    if (vms == null) return null;
    final mainIsolate = await findMainIsolate();
    if (mainIsolate != null && mainIsolate.id != null) {
      try {
        final objId = await getObjectId(obj);
        if (objId != null) {
          Obj object = await vms.getObject(mainIsolate.id!, objId);
          final instance = Instance.parse(object.json);
          return instance;
        }
      } catch (e) {
        print('getInstanceByObject error:$e');
      }
    }
    return null;
  }

  ///[VmService.getRetainingPath]
  Future<RetainingPath?> getRetainingPath(String objId, int limit) async {
    final vms = await getVmService();
    if (vms == null) return null;
    final mainIsolate = await findMainIsolate();
    if (mainIsolate != null && mainIsolate.id != null) {
      return vms.getRetainingPath(mainIsolate.id!, objId, limit);
    }
    return null;
  }

  ///start full gc
  Future startGCAsync() async {
    final vms = await getVmService();
    if (vms == null) return null;
    final isolate = await findMainIsolate();
    if (isolate != null && isolate.id != null) {
      await vms.getAllocationProfile(isolate.id!, gc: true);
    }
  }
}

int _key = 0;

/// 顶级函数，必须常规方法，生成 key 用
String generateNewKey() {
  return "${++_key}";
}

Map<String, dynamic> _objCache = Map();

/// 顶级函数，根据 key 返回指定对象
dynamic keyToObj(String key) {
  return _objCache[key];
}

extension MyInstance on Instance {
  BoundField? getField(String name) {
    if (fields == null) return null;
    for (int i = 0; i < fields!.length; i++) {
      var field = fields![i];
      if (field.decl?.name == name) {
        return field;
      }
    }
    return null;
  }

  dynamic getFieldValueInstance(String name) {
    final field = getField(name);
    if (field != null) {
      return field.value;
    }
    return null;
  }
}
