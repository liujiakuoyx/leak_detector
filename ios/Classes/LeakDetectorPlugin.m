#import "LeakDetectorPlugin.h"
#if __has_include(<leak_detector/leak_detector-Swift.h>)
#import <leak_detector/leak_detector-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "leak_detector-Swift.h"
#endif

@implementation LeakDetectorPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftLeakDetectorPlugin registerWithRegistrar:registrar];
}
@end
