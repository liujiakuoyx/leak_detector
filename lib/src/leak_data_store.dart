// Copyright (c) 2021, Jiakuo Liu. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:leak_detector/src/leak_sqlite_store.dart';

import '../leak_detector.dart';

///Leaked record store.
abstract class LeakedRecordStore {
  static LeakedRecordStore? _instance;

  //TODO add windows, linux data store.
  factory LeakedRecordStore() {
    if (_instance == null) {
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        _instance = LeakedRecordSQLiteStore();
      } else if (Platform.isWindows) {
        //TODO windows store
      } else if (Platform.isLinux) {
        //TODO linux store
      }
    }
    return _instance!;
  }

  //get all data
  Future<List<LeakedInfo>> getAll();

  //clean the store
  void clear();

  //delete by id
  void deleteById(int id);

  //insert a info list
  void addAll(List<LeakedInfo> list);

  //add one
  void add(LeakedInfo info);
}
