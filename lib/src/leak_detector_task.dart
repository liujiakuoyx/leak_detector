// Copyright (c) 2021, Jiakuo Liu. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import 'leak_detector.dart';
import 'leak_analyzer.dart';
import 'leak_data.dart';
import 'vm_service_utils.dart';

///check leak task
abstract class _Task<T> {
  void start() async {
    T? result;
    try {
      result = await run();
    } catch (e) {
      print('_Task $e');
    } finally {
      done(result);
    }
  }

  Future<T?> run();

  ///make sure to call after run
  void done(T? result);
}

class DetectorTask extends _Task {
  Expando? expando;

  final VoidCallback? onStart;
  final Function()? onResult;
  final Function(LeakedInfo? leakInfo)? onLeaked;
  final StreamSink<DetectorEvent>? sink;

  DetectorTask(
    this.expando, {
    required this.onResult,
    required this.onLeaked,
    this.onStart,
    this.sink,
  });

  @override
  void done(Object? result) {
    onResult?.call();
  }

  @override
  Future<LeakedInfo?> run() async {
    if (expando != null) {
      onStart?.call();
      if (await _maybeHasLeaked()) {
        //run GC,ensure Object should release
        sink?.add(DetectorEvent(DetectorEventType.startGC));
        await VmServerUtils().startGCAsync(); //GC
        sink?.add(DetectorEvent(DetectorEventType.endGc));
        return await _analyzeLeakedPathAfterGC();
      }
    }
    return null;
  }

  ///after Full GC, check whether there is a leak,
  ///if there is an analysis of the leaked reference chain
  Future<LeakedInfo?> _analyzeLeakedPathAfterGC() async {
    List<dynamic> weakPropertyList =
        await _getExpandoWeakPropertyList(expando!);
    expando = null; //一定要释放引用
    for (var weakProperty in weakPropertyList) {
      if (weakProperty != null) {
        final leakedInstance = await _getWeakPropertyKey(weakProperty.id);
        if (leakedInstance != null && leakedInstance.id != "objects/null") {
          final start = DateTime.now();
          sink?.add(DetectorEvent(DetectorEventType.startAnalyze));
          LeakedInfo? leakInfo = await compute(
            LeakAnalyzer.analyze,
            AnalyzeData(leakedInstance, LeakDetector.maxRetainingPath),
            debugLabel: 'analyze',
          );
          sink?.add(DetectorEvent(DetectorEventType.endAnalyze,
              data: DateTime.now().difference(start)));
          onLeaked?.call(leakInfo);
        }
      }
    }
    return null;
  }

  ///some weak reference != null;
  Future<bool> _maybeHasLeaked() async {
    List<dynamic> weakPropertyList =
        await _getExpandoWeakPropertyList(expando!);
    for (var weakProperty in weakPropertyList) {
      if (weakProperty != null) {
        final leakedInstance = await _getWeakPropertyKey(weakProperty.id);
        if (leakedInstance != null) return true;
      }
    }
    return false;
  }

  ///List Item has id
  Future<List<dynamic>> _getExpandoWeakPropertyList(Expando expando) async {
    if (await VmServerUtils().hasVmService) {
      final data = (await VmServerUtils().getInstanceByObject(expando))
          ?.getFieldValueInstance('_data');
      if (data?.id != null) {
        final dataObj = await VmServerUtils().getObjectInstanceById(data.id);
        if (dataObj?.json != null) {
          Instance? weakListInstance = Instance.parse(dataObj!.json!);
          if (weakListInstance != null) {
            return weakListInstance.elements ?? [];
          }
        }
      }
    }
    return [];
  }

  ///get PropertyKey in [Expando]
  Future<ObjRef?> _getWeakPropertyKey(String weakPropertyId) async {
    final weakPropertyObj =
        await VmServerUtils().getObjectInstanceById(weakPropertyId);
    if (weakPropertyObj != null) {
      final weakPropertyInstance = Instance.parse(weakPropertyObj.json);
      return weakPropertyInstance?.propertyKey;
    }
    return null;
  }
}
