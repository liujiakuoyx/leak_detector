// Copyright (c) 2021, Jiakuo Liu. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:leak_detector/src/leak_data_store.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'leak_data.dart';

///数据库升级表[版本号 | 数据库版本 | 备注
/// 1.0.0 | 1 | 创建数据库
const int _kLeakDatabaseVersion = 1;

///database
class _LeakDataBase {
  static Future<Database> _openDatabase() async {
    return openDatabase(
      join(await getDatabasesPath(), 'leak_recording.db'),
      version: _kLeakDatabaseVersion,
      onCreate: (Database db, int version) {
        // Run the CREATE TABLE statement on the database.
        return db.execute(
          "CREATE TABLE IF NOT EXISTS ${_LeakRecordingTable._kTableName}("
          "${_LeakRecordingTable._kId} TEXT NOT NULL PRIMARY KEY, "
          "${_LeakRecordingTable._kGCRootType} TEXT, "
          "${_LeakRecordingTable._kLeakPathJson} TEXT)",
        );
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {},
    );
  }
}

/// table
class _LeakRecordingTable {
  static const String _kTableName = 'leak_recording_table';
  static const String _kGCRootType = 'gcType';
  static const String _kLeakPathJson = 'leakPath'; //leaked path to json
  static const String _kId = '_id'; //time
}

///[_LeakRecordingTable] Helper
class LeakedRecordSQLiteStore implements LeakedRecordStore {
  static LeakedRecordSQLiteStore? _instance;

  Future<Database> get database => _LeakDataBase._openDatabase();

  factory LeakedRecordSQLiteStore() {
    _instance ??= LeakedRecordSQLiteStore._();
    return _instance!;
  }

  LeakedRecordSQLiteStore._();

  Future<List<LeakedInfo>> _queryAll() async {
    // Get a reference to the database.
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _LeakRecordingTable._kTableName,
    );
    if (maps.isNotEmpty) {
      return maps.map((dataMap) => _toData(dataMap)).toList();
    } else {
      return [];
    }
  }

  Future<void> _insert(LeakedInfo data) async {
    final Database db = await database;
    await db.insert(
      _LeakRecordingTable._kTableName,
      _toDatabaseMap(data),
      conflictAlgorithm: ConflictAlgorithm.replace, //冲突替换
    );
  }

  Future<void> _insertAll(List<LeakedInfo> data) async {
    final Database db = await database;
    data.forEach((info) async {
      await db.insert(
        _LeakRecordingTable._kTableName,
        _toDatabaseMap(info),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> _deleteById(int id) async {
    // Get a reference to the database (获得数据库引用)
    final db = await database;
    // Remove the Data from the Database.
    await db.delete(
      _LeakRecordingTable._kTableName,
      // Use a `where` clause to delete a specific meeting (使用 `where` 语句删除指定的id).
      where: "${_LeakRecordingTable._kId} = ?",
      // Pass the Data's id as a whereArg to prevent SQL injection (通过 `whereArg` 将 id 传递给 `delete` 方法，以防止 SQL 注入)
      whereArgs: [id.toString()],
    );
  }

  Future<void> _deleteAll() async {
    // Get a reference to the database (获得数据库引用)
    final db = await database;
    // Remove the Data from the Database.
    await db.delete(_LeakRecordingTable._kTableName);
  }

  Map<String, dynamic> _toDatabaseMap(LeakedInfo data) {
    return {
      _LeakRecordingTable._kId: data.timestamp.toString(),
      _LeakRecordingTable._kGCRootType: data.gcRootType,
      _LeakRecordingTable._kLeakPathJson: data.retainingPathJson,
    };
  }

  LeakedInfo _toData(Map<String, dynamic> dataMap) {
    String gcRootType = dataMap[_LeakRecordingTable._kGCRootType];
    String leakPathJson = dataMap[_LeakRecordingTable._kLeakPathJson];
    String timestamp = dataMap[_LeakRecordingTable._kId];
    List dataList = jsonDecode(leakPathJson);
    return LeakedInfo(
      dataList.map((map) => RetainingNode.fromJson(map)).toList(),
      gcRootType,
      timestamp: int.tryParse(timestamp),
    );
  }

  @override
  void add(LeakedInfo info) => _insert(info);

  @override
  void addAll(List<LeakedInfo> list) => _insertAll(list);

  @override
  void clear() => _deleteAll();

  @override
  Future<List<LeakedInfo>> getAll() => _queryAll();

  @override
  void deleteById(int id) => _deleteById(id);
}
