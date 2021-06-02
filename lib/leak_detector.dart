// Copyright (c) 2021, Jiakuo Liu. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library leak_detector;

import 'src/leak_data.dart';
import 'src/leak_data_store.dart';

export 'src/leak_detector.dart';
export 'src/leak_state_mixin.dart';
export 'src/view/leak_preview_page.dart';
export 'src/leak_data.dart';
export 'src/leak_navigator_observer.dart';

///read historical leaked data
Future<List<LeakedInfo>> getLeakedRecording() => LeakedRecordStore().getAll();
