// Copyright (c) 2021, Jiakuo Liu. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import 'leak_data.dart';
import 'vm_service_utils.dart';

///analyze leaked path
///引用链分析
class LeakAnalyzer {
  /// The type of GC root which is holding a reference to the specified object.
  /// Possible values include:  * class table  * local handle  * persistent
  /// handle  * stack  * user global  * weak persistent handle  * unknown
  ///
  /// run on subIsolate
  static Future<LeakedInfo?> analyze(AnalyzeData analyzeData) async {
    final leakedInstance = analyzeData.leakedInstance;
    final maxRetainingPath = analyzeData.maxRetainingPath;
    if (leakedInstance?.id != null && maxRetainingPath != null) {
      final retainingPath = await VmServerUtils()
          .getRetainingPath(leakedInstance!.id!, maxRetainingPath);
      if (retainingPath?.elements != null &&
          retainingPath!.elements!.isNotEmpty) {
        final retainingObjectList = retainingPath.elements!;
        final stream = Stream.fromIterable(retainingObjectList)
            .asyncMap<RetainingNode?>(_defaultAnalyzeNode);
        List<RetainingNode> retainingPathList = [];
        (await stream.toList()).forEach((e) {
          if (e != null) {
            retainingPathList.add(e);
          }
        });

        return LeakedInfo(retainingPathList, retainingPath.gcRootType);
      }
    }
    return null;
  }

  static Future<LeakedNodeType> _getObjectType(Class? clazz) async {
    if (clazz?.name == null) return LeakedNodeType.unknown;
    if (clazz!.name == 'Widget') {
      return LeakedNodeType.widget;
    } else if (clazz.name == 'Element') {
      return LeakedNodeType.element;
    }
    if (clazz.superClass?.id != null) {
      Class? superClass = (await VmServerUtils()
          .getObjectInstanceById(clazz.superClass!.id!)) as Class?;
      return _getObjectType(superClass);
    } else {
      return LeakedNodeType.unknown;
    }
  }

  ///0 FieldRef
  ///1 classRef
  static Future<List?> getFieldAndClassByName(Class? clazz, String name) async {
    if (clazz?.fields == null) return null;
    for (int i = 0; i < clazz!.fields!.length; i++) {
      var field = clazz.fields![i];
      if (field.id != null && field.id!.endsWith(name)) {
        return [field, Class.parse(clazz.json)];
      }
    }
    if (clazz.superClass?.id != null) {
      Class? superClass = (await VmServerUtils()
          .getObjectInstanceById(clazz.superClass!.id!)) as Class?;
      return getFieldAndClassByName(superClass, name);
    } else {
      return null;
    }
  }

  static Future<String?> _getKeyInfo(RetainingObject retainingObject) async {
    String? keyString;
    if (retainingObject.parentMapKey?.id != null) {
      Obj? keyObj = await VmServerUtils()
          .getObjectInstanceById(retainingObject.parentMapKey!.id!);
      if (keyObj?.json != null) {
        Instance? keyInstance = Instance.parse(keyObj!.json!);
        if (keyInstance != null &&
            (keyInstance.kind == 'String' ||
                keyInstance.kind == 'Int' ||
                keyInstance.kind == 'Double' ||
                keyInstance.kind == 'Bool')) {
          keyString = '${keyInstance.kind}: \'${keyInstance.valueAsString}\'';
        } else {
          if (keyInstance?.id != null) {
            keyString =
                'Object: class=${keyInstance?.classRef?.name}, ${await VmServerUtils().invokeMethod(keyInstance!.id!, 'toString', [])}';
          }
        }
      }
    }
    return keyString;
  }

  static Future<SourceCodeLocation?> _getSourceCodeLocation(
      dynamic parentField, Class clazz) async {
    SourceCodeLocation? sourceCodeLocation;
    if (parentField != null && clazz.name != '_Closure') {
      //get field and owner class
      List? fieldAndClass = await getFieldAndClassByName(
          clazz, Uri.encodeQueryComponent('$parentField'));
      if (fieldAndClass != null) {
        FieldRef fieldRef = fieldAndClass[0];
        Class fieldClass = fieldAndClass[1];
        if (fieldRef.id != null) {
          Field? field = (await VmServerUtils()
              .getObjectInstanceById(fieldRef.id!)) as Field?;
          if (field != null && field.location?.script?.id != null) {
            //get field's Script info, source code, line number, clounm number
            Script? script = (await VmServerUtils()
                .getObjectInstanceById(field.location!.script!.id!)) as Script?;
            if (script != null && field.location?.tokenPos != null) {
              int? line =
                  script.getLineNumberFromTokenPos(field.location!.tokenPos!);
              int? column =
                  script.getColumnNumberFromTokenPos(field.location!.tokenPos!);
              String? codeLine;
              codeLine = script.source
                  ?.substring(
                      field.location!.tokenPos!, field.location!.endTokenPos)
                  .split('\n')
                  .first;
              sourceCodeLocation = SourceCodeLocation(codeLine, line, column,
                  fieldClass.name, fieldClass.library?.uri);
            }
          }
        }
      }
    }
    return sourceCodeLocation;
  }

  static Future<ClosureInfo?> _getClosureInfo(Instance? instance) async {
    if (instance != null && instance.kind == 'Closure') {
      final name = instance.closureFunction?.name;
      final owner = instance.closureFunction?.owner;
      final info =
          ClosureInfo(closureFunctionName: name, closureOwner: owner?.name);
      await _getClosureOwnerInfo(owner, info);
      return info;
    }
    return null;
  }

  static _getClosureOwnerInfo(dynamic ref, ClosureInfo info) async {
    if (ref?.id == null) return;
    if (ref is LibraryRef) {
      Library? library =
          (await VmServerUtils().getObjectInstanceById((ref).id!)) as Library?;
      info.libraries = library?.uri;
    } else if (ref is ClassRef) {
      Class? clazz =
          (await VmServerUtils().getObjectInstanceById(ref.id!)) as Class?;
      info.closureOwnerClass = clazz?.name;
      info.libraries = clazz?.library?.uri;
    } else if (ref is FuncRef) {
      if (info.funLine == null) {
        //if fun location is null, get the fun code location.
        Func? func =
            (await VmServerUtils().getObjectInstanceById(ref.id!)) as Func?;
        if (func?.location?.script?.id != null) {
          //get script info.
          Script? script = (await VmServerUtils()
              .getObjectInstanceById(func!.location!.script!.id!)) as Script?;
          if (script != null && func.location?.tokenPos != null) {
            info.funLine =
                script.getLineNumberFromTokenPos(func.location!.tokenPos!);
            info.funColumn =
                script.getColumnNumberFromTokenPos(func.location!.tokenPos!);
          }
        }
      }
      await _getClosureOwnerInfo(ref.owner, info);
    }
  }

  static Future<RetainingNode?> _defaultAnalyzeNode(
      RetainingObject retainingObject) async {
    if (retainingObject.value is InstanceRef) {
      InstanceRef instanceRef = retainingObject.value as InstanceRef;
      final String name = instanceRef.classRef?.name ?? '';

      Class? clazz;
      if (instanceRef.classRef?.id != null) {
        //get class info
        clazz = (await VmServerUtils()
            .getObjectInstanceById(instanceRef.classRef!.id!)) as Class?;
      }

      SourceCodeLocation? sourceCodeLocation;
      if (retainingObject.parentField != null && clazz != null) {
        //parentField source code location
          sourceCodeLocation =
              await _getSourceCodeLocation(retainingObject.parentField!, clazz);
      }

      String? toString;
      if (instanceRef.id != null) {
        //object toString
        toString =
            await VmServerUtils().invokeMethod(instanceRef.id!, 'toString', []);
      }

      //if is Map, get Key info.
      String? keyString = await _getKeyInfo(retainingObject);

      ClosureInfo? closureInfo;
      if (retainingObject.value?.json != null) {
        //if is Closure,get ClosureInfo
        closureInfo =
            await _getClosureInfo(Instance.parse(retainingObject.value!.json));
      }
      return RetainingNode(
        name,
        parentField: retainingObject.parentField?.toString(),
        parentIndex: retainingObject.parentListIndex,
        parentKey: keyString,
        libraries: clazz?.library?.uri,
        sourceCodeLocation: sourceCodeLocation,
        string: toString,
        closureInfo: closureInfo,
        leakedNodeType: await _getObjectType(clazz),
      );
    } else if (retainingObject.value?.type != '@Context') {
      return RetainingNode(
        retainingObject.value?.type ?? '',
        parentField: retainingObject.parentField?.toString(),
      );
    }
    return null;
  }
}

class AnalyzeData {
  final ObjRef? leakedInstance;
  final int? maxRetainingPath;

  AnalyzeData(this.leakedInstance, this.maxRetainingPath);
}
