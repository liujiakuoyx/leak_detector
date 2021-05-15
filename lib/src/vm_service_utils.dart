// Copyright (c) $today.year, Jiakuo Liu. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:developer';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';
import 'package:vm_service/utils.dart';

const String _findLibrary = 'package:leak_detector/src/vm_service_utils.dart';

class VmServerUtils {
  static VmServerUtils _instance;
  bool _enable = false;
  Uri _observatoryUri;
  VmService _vmService;
  VM _vm;

  Future<bool> get hasVmService async => (await getVmService()) != null;

  factory VmServerUtils() {
    _instance ??= VmServerUtils._();
    return _instance;
  }

  bool get isEnable => _enable;

  VmServerUtils._() {
    //init
    assert(() {
      _enable = true;
      return true;
    }());
  }

  Future<Uri> getObservatoryUri() async {
    if (_enable) {
      // _observatoryUri = await _channel.invokeMethod('getObservatoryUri');
      ServiceProtocolInfo serviceProtocolInfo = await Service.getInfo();
      _observatoryUri = serviceProtocolInfo.serverUri;
    }
    return _observatoryUri;
  }

  Future<VmService> getVmService() async {
    if (_vmService == null) {
      final uri = await getObservatoryUri();
      if (uri != null) {
        _vmService = await vmServiceConnectUri(convertToWebSocketUrl(serviceProtocolUrl: uri).toString());
      }
    }
    return _vmService;
  }

  Future<VM> getVM() async {
    if (_vm == null) {
      _vm = await (await getVmService())?.getVM();
    }
    return _vm;
  }

  Future<LibraryRef> findLibrary(String uri) async {
    Isolate mainIsolate = await findMainIsolate();
    final libraries = mainIsolate.libraries;
    for (int i = 0; i < libraries.length; i++) {
      var lib = libraries[i];
      if (lib.uri == uri) {
        return lib;
      }
    }
    return null;
  }

  Future<Isolate> findMainIsolate() async {
    IsolateRef ref;
    final vm = await getVM();
    if (vm == null) return null;
    vm.isolates.forEach((isolate) {
      if (isolate.name == 'main') {
        ref = isolate;
      }
    });
    final vms = await getVmService();
    return vms.getIsolate(ref.id);
  }

  Future<String> getObjectId(dynamic obj) async {
    final library = await findLibrary(_findLibrary);
    final vms = await getVmService();
    if (vms == null) return null;
    final mainIsolate = await findMainIsolate();
    Response keyResponse = await vms.invoke(mainIsolate.id, library.id, 'generateNewKey', []);
    if (keyResponse != null) {
      final keyRef = InstanceRef.parse(keyResponse.json);
      String key = keyRef.valueAsString;
      _objCache[key] = obj;

      try {
        Response valueResponse = await vms.invoke(mainIsolate.id, library.id, "keyToObj", [keyRef.id]);
        if (valueResponse != null) {
          final valueRef = InstanceRef.parse(valueResponse.json);
          return valueRef.id;
        }
      } catch (e) {
        print('getObjectId $e');
      } finally {
        _objCache.remove(key);
      }
    }
    return null;
  }

  Future<String> invokeMethod(String targetId, String method, List<String> argumentIds) async {
    final vms = await getVmService();
    if (vms == null) return null;
    final mainIsolate = await findMainIsolate();
    try {
      Response valueResponse = await vms.invoke(mainIsolate.id, targetId, method, argumentIds);
      if (valueResponse != null) {
        final valueRef = InstanceRef.parse(valueResponse.json);
        return valueRef.valueAsString;
      }
    } catch (e) {}
    return null;
  }

  ///通过ObjectId获取Instance
  Future<Obj> getObjectInstanceById(String objId) async {
    final vms = await getVmService();
    if (vms == null) return null;
    final mainIsolate = await findMainIsolate();
    try {
      Obj object = await vms.getObject(mainIsolate.id, objId);
      return object;
    } catch (e) {
      print('getObjectInstanceById error:$e');
    }
    return null;
  }

  ///通过Object获取Instance
  Future<Instance> getInstanceByObject(dynamic obj) async {
    final vms = await getVmService();
    if (vms == null) return null;
    final mainIsolate = await findMainIsolate();
    try {
      final objId = await getObjectId(obj);
      Obj object = await vms.getObject(mainIsolate.id, objId);
      if (object != null) {
        final instance = Instance.parse(object.json);
        return instance;
      }
    } catch (e) {
      print('getInstanceByObject error:$e');
    }
    return null;
  }

  Future<RetainingPath> getRetainingPath(String objId, int limit) async {
    final vms = await getVmService();
    if (vms == null) return null;
    final mainIsolate = await findMainIsolate();
    return vms.getRetainingPath(mainIsolate.id, objId, limit);
  }

  Future startGCAsync() async {
    final vms = await getVmService();
    if (vms == null) return null;
    final isolate = await findMainIsolate();
    await vms.getAllocationProfile(isolate.id, gc: true);
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
  BoundField getField(String name) {
    for (int i = 0; i < fields.length; i++) {
      var field = fields[i];
      if (field.decl.name == name) {
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
