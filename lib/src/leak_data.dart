// Copyright (c) 2021, Jiakuo Liu. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

///Leak the reference chain and other information of the object
class LeakedInfo {
  ///Reference chain, if there are multiple reference chains, there is only one
  List<RetainingNode> retainingPath;

  /// The type of GC root which is holding a reference to the specified object.
  /// Possible values include:  * class table  * local handle  * persistent
  /// handle  * stack  * user global  * weak persistent handle  * unknown
  String? gcRootType;

  ///Time to completion of leak detection
  int? timestamp;

  LeakedInfo(this.retainingPath, this.gcRootType, {this.timestamp}) {
    if (timestamp == null) {
      timestamp = DateTime.now().millisecondsSinceEpoch;
    }
  }

  bool get isNotEmpty => retainingPath.isNotEmpty;

  ///to json string
  String get retainingPathJson {
    if (isNotEmpty) {
      return jsonEncode(retainingPath.map((path) => path.toJson()).toList());
    }
    return '[]';
  }

  @override
  String toString() {
    return '$gcRootType, retainingPath: $retainingPathJson';
  }
}

///leaked node info
class RetainingNode {
  String clazz = ''; //class name
  String? parentField; //parentField
  bool important = false; //进过分析是否为重要的节点
  String? libraries; //libraries name
  String? string; //object toString()
  String? parentKey; //if object in a Map,map's key
  int? parentIndex; //if object in a List,it is index in the List
  SourceCodeLocation? sourceCodeLocation; //source code, code location
  ClosureInfo? closureInfo; //if object is closure
  late LeakedNodeType leakedNodeType; //widget, element...

  RetainingNode(
    this.clazz, {
    this.parentKey,
    this.parentIndex,
    this.string,
    this.sourceCodeLocation,
    this.parentField,
    this.libraries,
    this.important = false,
    this.closureInfo,
    this.leakedNodeType = LeakedNodeType.unknown,
  });

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  Map<String, dynamic> toJson() {
    return {
      'clazz': clazz,
      'parentKey': parentKey,
      'string': string,
      'parentIndex': parentIndex,
      'sourceCodeLocation': sourceCodeLocation?.toJson(),
      'parentField': parentField,
      'libraries': libraries,
      'important': important,
      'leakedNodeType': leakedNodeType.index,
      'closureInfo': closureInfo?.toJson(),
    };
  }

  RetainingNode.fromJson(Map<String, dynamic> json) {
    clazz = json['clazz'];
    parentKey = json['parentKey'];
    parentIndex = json['parentIndex'];
    string = json['string'];
    leakedNodeType =
        LeakedNodeType.values[(json['leakedNodeType'] ?? 0) as int];
    if (json['sourceCodeLocation'] is Map) {
      sourceCodeLocation =
          SourceCodeLocation.fromJson(json['sourceCodeLocation']);
    }
    parentField = json['parentField'];
    libraries = json['libraries'];
    important = json['important'];
    if (json['closureInfo'] is Map) {
      closureInfo = ClosureInfo.fromJson(json['closureInfo']);
    }
  }
}

///leaked field source code location
class SourceCodeLocation {
  String? code;
  int? lineNum;
  int? columnNum;
  String? className;
  String? uri; //lib uri

  SourceCodeLocation(
      this.code, this.lineNum, this.columnNum, this.className, this.uri);

  SourceCodeLocation.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    lineNum = json['lineNum'];
    columnNum = json['columnNum'];
    className = json['className'];
    uri = json['uri'];
  }

  @override
  String toString() {
    return '$code($lineNum:$columnNum) $uri#$className';
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'lineNum': lineNum,
      'columnNum': columnNum,
      'className': className,
      'uri': uri,
    };
  }
}

/// if leaked node if Closure
class ClosureInfo {
  String? closureFunctionName;
  String? closureOwner; //可能是 方法、类、包
  String? closureOwnerClass; //如果owner是类=owner，owner是方法所在类
  String? libraries;
  int? funLine;
  int? funColumn;

  ClosureInfo({
    this.closureFunctionName,
    this.closureOwner,
    this.closureOwnerClass,
    this.libraries,
    this.funLine,
    this.funColumn,
  });

  ClosureInfo.fromJson(Map<String, dynamic> json) {
    closureFunctionName = json['closureFunctionName'];
    closureOwner = json['closureOwner'];
    closureOwnerClass = json['closureOwnerClass'];
    libraries = json['libraries'];
    funLine = json['funLine'];
    funColumn = json['funColumn'];
  }

  Map<String, dynamic> toJson() {
    return {
      'closureFunctionName': closureFunctionName,
      'closureOwner': closureOwner,
      'closureOwnerClass': closureOwnerClass,
      'libraries': libraries,
      'funLine': funLine,
      'funColumn': funColumn,
    };
  }

  @override
  String toString() {
    return '$libraries\nclosureFunName:$closureFunctionName($funLine:$funColumn)\nowner:$closureOwner\nownerClass:$closureOwnerClass';
  }
}

enum LeakedNodeType {
  unknown,
  widget,
  element,
}
