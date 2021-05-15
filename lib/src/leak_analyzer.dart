// Copyright (c) $today.year, Jiakuo Liu. All rights reserved. Use of this source code
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
  static Future<LeakedInfo> analyze(AnalyzeData analyzeData) async {
    final leakedInstance = analyzeData.leakedInstance;
    final maxRetainingPath = analyzeData.maxRetainingPath;
    if (leakedInstance != null && maxRetainingPath != null) {
      final retainingPath = await VmServerUtils().getRetainingPath(leakedInstance.id, maxRetainingPath);
      if (retainingPath?.elements != null && retainingPath.elements.isNotEmpty) {
        final retainingObjectList = retainingPath.elements;
        try {
          List<RetainingNode> retainingPathList = [];
          for (int i = 0; i < retainingObjectList.length; i++) {
            var retainingObject = retainingObjectList[i];
            //analyze node
            if (retainingObject.value is InstanceRef) {
              InstanceRef instanceRef = retainingObject.value;
              final String name = instanceRef.classRef.name;

              //get class info
              Class clazz = await VmServerUtils().getObjectInstanceById(instanceRef.classRef.id);

              //parentField source code location
              SourceCodeLocation sourceCodeLocation = await _getSourceCodeLocation(retainingObject.parentField, clazz);

              //object toString
              String toString = await VmServerUtils().invokeMethod(instanceRef.id, 'toString', []);

              //if is Map, get Key info.
              String keyString = await _getKeyInfo(retainingObject);

              //if is Closure,get ClosureInfo
              ClosureInfo closureInfo = await _getClosureInfo(Instance.parse(retainingObject.value.json));

              retainingPathList.add(RetainingNode(
                name,
                parentField: retainingObject.parentField?.toString(),
                parentIndex: retainingObject.parentListIndex,
                parentKey: keyString,
                libraries: clazz?.library?.uri,
                sourceCodeLocation: sourceCodeLocation,
                string: toString,
                closureInfo: closureInfo,
              ));
            } else if (retainingObject.value.type != '@Context') {
              retainingPathList.add(RetainingNode(
                retainingObject.value.type,
                parentField: retainingObject.parentField?.toString(),
              ));
            }
          }
          return LeakedInfo(retainingPathList, retainingPath.gcRootType);
        } catch (e) {
          print('error$e');
        }
      }
    }
    return null;
  }

  ///0 FieldRef
  ///1 classRef
  static Future<List> getFieldAndClassByName(Class clazz, String name) async {
    if (clazz == null) return null;
    for (int i = 0; i < clazz.fields.length; i++) {
      var field = clazz.fields[i];
      if (field.id.endsWith(name)) {
        return [field, Class.parse(clazz.json)];
      }
    }
    if (clazz.superClass != null) {
      Class superClass = await VmServerUtils().getObjectInstanceById(clazz.superClass.id);
      return getFieldAndClassByName(superClass, name);
    } else {
      return null;
    }
  }

  static Future<String> _getKeyInfo(RetainingObject retainingObject) async {
    String keyString;
    if (retainingObject.parentMapKey != null) {
      Obj keyObj = await VmServerUtils().getObjectInstanceById(retainingObject.parentMapKey.id);
      if (keyObj != null) {
        Instance keyInstance = Instance.parse(keyObj.json);
        if (keyInstance.kind == 'String' ||
            keyInstance.kind == 'Int' ||
            keyInstance.kind == 'Double' ||
            keyInstance.kind == 'Bool') {
          keyString = '${keyInstance.kind}: \'${keyInstance?.valueAsString}\'';
        } else {
          keyString =
              'Object: class=${keyInstance?.classRef?.name}, ${await VmServerUtils().invokeMethod(keyInstance.id, 'toString', [])}';
        }
      }
    }
    return keyString;
  }

  static Future<SourceCodeLocation> _getSourceCodeLocation(String parentField, Class clazz) async {
    SourceCodeLocation sourceCodeLocation;
    if (parentField != null && clazz.name != '_Closure') {
      //get field and owner class
      List fieldAndClass = await getFieldAndClassByName(clazz, Uri.encodeQueryComponent(parentField));
      FieldRef fieldRef = fieldAndClass[0];
      Class fieldClass = fieldAndClass[1];
      if (fieldRef != null) {
        //get field info
        Field field = await VmServerUtils().getObjectInstanceById(fieldRef.id);
        if (field != null && field.location?.script != null) {
          //get field's Script info, source code, line number, clounm number
          Script script = await VmServerUtils().getObjectInstanceById(field.location.script.id);
          if (script != null) {
            int line = script.getLineNumberFromTokenPos(field.location.tokenPos);
            int column = script.getColumnNumberFromTokenPos(field.location.tokenPos);
            String codeLine =
                script.source.substring(field.location.tokenPos, field.location.endTokenPos).split('\n').first;
            sourceCodeLocation = SourceCodeLocation(codeLine, line, column, fieldClass?.name, fieldClass?.library?.uri);
          }
        }
      }
    }
    return sourceCodeLocation;
  }

  static Future<ClosureInfo> _getClosureInfo(Instance instance) async {
    if (instance != null && instance.kind == 'Closure') {
      final name = instance.closureFunction?.name;
      final owner = instance.closureFunction?.owner;
      final info = ClosureInfo(closureFunctionName: name, closureOwner: owner?.name);
      await _getClosureOwnerInfo(owner, info);
      return info;
    }
    return null;
  }

  static _getClosureOwnerInfo(dynamic ref, ClosureInfo info) async {
    if (ref is LibraryRef) {
      Library library = await VmServerUtils().getObjectInstanceById(ref.id);
      info.libraries = library?.uri;
    } else if (ref is ClassRef) {
      Class clazz = await VmServerUtils().getObjectInstanceById(ref.id);
      info.closureOwnerClass = clazz?.name;
      info.libraries = clazz?.library?.uri;
    } else if (ref is FuncRef) {
      if (info.funLine == null) {
        //if fun location is null, get the fun code location.
        Func func = await VmServerUtils().getObjectInstanceById(ref.id);
        if (func?.location?.script != null) {
          //get script info.
          Script script = await VmServerUtils().getObjectInstanceById(func.location.script.id);
          if (script != null) {
            info.funLine = script.getLineNumberFromTokenPos(func.location.tokenPos);
            info.funColumn = script.getColumnNumberFromTokenPos(func.location.tokenPos);
          }
        }
      }
      await _getClosureOwnerInfo(ref.owner, info);
    }
  }
}

class AnalyzeData {
  final InstanceRef leakedInstance;
  final int maxRetainingPath;

  AnalyzeData(this.leakedInstance, this.maxRetainingPath);
}
