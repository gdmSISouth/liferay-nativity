#import <Cocoa/Cocoa.h>

#import "LNStandardVersionComparator.h"

#define EXPORT __attribute__((visibility("default")))

#define FINDER_MIN_TESTED_VERSION @"10.7"
#define FINDER_MAX_TESTED_VERSION @"10.8.3"

// SIMBL-compatible interface
@interface LiferayNativityShell : NSObject { }
-(void) install;
-(void) uninstall;
@end

// just a dummy class for locating our bundle
@interface LiferayNativityInjector : NSObject { }
@end

@implementation LiferayNativityInjector { }
@end

static bool liferayNativityLoaded = false;
static NSString* liferayNativityBundleName = @"LiferayNativityFinder";

typedef struct {
  NSString* location;
} configuration;

static OSErr AEPutParamString(AppleEvent* event, AEKeyword keyword, NSString* string) {
  UInt8* textBuf;
  CFIndex length, maxBytes, actualBytes;

  length = CFStringGetLength((CFStringRef)string);
  maxBytes = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8);
  textBuf = malloc(maxBytes);
  if (textBuf) {
    CFStringGetBytes((CFStringRef)string, CFRangeMake(0, length), kCFStringEncodingUTF8, 0, true, (UInt8*)textBuf, maxBytes, &actualBytes);
    OSErr err = AEPutParamPtr(event, keyword, typeUTF8Text, textBuf, actualBytes);
    free(textBuf);
    return err;
  } else {
    return memFullErr;
  }
}

static void reportError(AppleEvent* reply, NSString* msg) {
  NSLog(@"LiferayNativityInjector: %@", msg);
  AEPutParamString(reply, keyErrorString, msg);
}

typedef enum {
  InvalidBundleType,
  LiferayNativityBundleType,
} LNBundleType;

static OSErr loadBundle(LNBundleType type, AppleEvent* reply, long refcon) {
  bool isLoaded = false;
  NSString* bundleName = nil;
  NSString* targetAppName = nil;
  NSString* versionCheckKey = nil;
  NSString* maxVersion = nil;
  NSString* minVersion = nil;

  switch (type) {
    case LiferayNativityBundleType:
      isLoaded = liferayNativityLoaded;
      bundleName = liferayNativityBundleName;
      targetAppName = @"Finder";
      versionCheckKey = @"LiferayNativityFinderVersionCheck";
      maxVersion = FINDER_MAX_TESTED_VERSION;
      minVersion = FINDER_MIN_TESTED_VERSION;
      break;
    default:
      NSLog(@"Failed to load bundle for type %d", type);
      return 8;

      break;
  }

  if (isLoaded) {
    NSLog(@"LiferayNativityInjector: %@ already loaded.", bundleName);
    return noErr;
  }

  @try {
    NSBundle* mainBundle = [NSBundle mainBundle];
    if (!mainBundle) {
      reportError(reply, [NSString stringWithFormat:@"Unable to locate main %@ bundle!", targetAppName]);
      return 4;
    }

    NSString* mainVersion = [mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    if (!mainVersion || ![mainVersion isKindOfClass:[NSString class]]) {
      reportError(reply, [NSString stringWithFormat:@"Unable to determine %@ version!", targetAppName]);
      return 5;
    }

    // future compatibility check
    if (type == LiferayNativityBundleType) {
      // in Dock we cannot use NSAlert and similar UI stuff - this would hang the Dock process and cause 100% CPU load
      NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
      if ([defaults boolForKey:versionCheckKey]) {
        LNStandardVersionComparator* comparator = [LNStandardVersionComparator defaultComparator];
        if (([comparator compareVersion:mainVersion toVersion:maxVersion] == NSOrderedDescending) ||
            ([comparator compareVersion:mainVersion toVersion:minVersion] == NSOrderedAscending)) {
          NSAlert* alert = [NSAlert new];
          [alert setMessageText:[NSString stringWithFormat:@"You have %@ version %@", targetAppName, mainVersion]];
          [alert setInformativeText:[NSString stringWithFormat:@"But %@ was properly tested only with %@ versions in range %@ - %@\n\nYou have probably updated your system and %@ version got bumped by Apple developers.\n\nYou may expect a new LiferayNativity release soon.", bundleName, targetAppName, targetAppName, minVersion, maxVersion]];
          [alert setShowsSuppressionButton:YES];
          [alert addButtonWithTitle:@"Launch LiferayNativity anyway"];
          [alert addButtonWithTitle:@"Cancel"];
          NSInteger res = [alert runModal];
          if ([[alert suppressionButton] state] == NSOnState) {
            [defaults setBool:NO forKey:versionCheckKey];
          }
          if (res != NSAlertFirstButtonReturn) {
            // cancel
            return noErr;
          }
        }
      }
    }

    NSBundle* liferayNativityInjectorBundle = [NSBundle bundleForClass:[LiferayNativityInjector class]];
    NSString* liferayNativityLocation = [liferayNativityInjectorBundle pathForResource:bundleName ofType:@"bundle"];
    NSBundle* pluginBundle = [NSBundle bundleWithPath:liferayNativityLocation];
    if (!pluginBundle) {
      reportError(reply, [NSString stringWithFormat:@"Unable to create bundle from path: %@ [%@]", liferayNativityLocation, liferayNativityInjectorBundle]);
      return 2;
    }

    NSError* error;
    if (![pluginBundle loadAndReturnError:&error]) {
      reportError(reply, [NSString stringWithFormat:@"Unable to load bundle from path: %@ error: %@", liferayNativityLocation, [error localizedDescription]]);
      return 6;
    }

    Class principalClass = [pluginBundle principalClass];
    if (!principalClass) {
      reportError(reply, [NSString stringWithFormat:@"Unable to retrieve principalClass for bundle: %@", pluginBundle]);
      return 3;
    }
    id principalClassObject = NSClassFromString(NSStringFromClass(principalClass));
    if ([principalClassObject respondsToSelector:@selector(install)]) {
      NSLog(@"LiferayNativityInjector: Installing %@ ...", bundleName);
      [principalClassObject install];
    }

    if (type == LiferayNativityBundleType) {
      liferayNativityLoaded = true;
    }

    return noErr;
  } @catch (NSException* exception) {
    reportError(reply, [NSString stringWithFormat:@"Failed to load %@ with exception: %@", bundleName, exception]);
  }

  return 1;
}

static LNBundleType mainBundleType(AppleEvent* reply) {
  @try {
    NSBundle* mainBundle = [NSBundle mainBundle];
    if (!mainBundle) {
      reportError(reply, [NSString stringWithFormat:@"Unable to locate main bundle!"]);
      return InvalidBundleType;
    }

    if ([[mainBundle bundleIdentifier] isEqualToString:@"com.apple.finder"]) {
      return LiferayNativityBundleType;
    }
  } @catch (NSException* exception) {
    reportError(reply, [NSString stringWithFormat:@"Failed to load main bundle with exception: %@", exception]);
  }

  return InvalidBundleType;
}

EXPORT OSErr HandleLoadEvent(const AppleEvent* ev, AppleEvent* reply, long refcon) {
  NSBundle* injectorBundle = [NSBundle bundleForClass:[LiferayNativityInjector class]];
  NSString* injectorVersion = [injectorBundle objectForInfoDictionaryKey:@"CFBundleVersion"];

  if (!injectorVersion || ![injectorVersion isKindOfClass:[NSString class]]) {
    reportError(reply, [NSString stringWithFormat:@"Unable to determine LiferayNativityInjector version!"]);
    return 7;
  }

  @try {
    return loadBundle(mainBundleType(reply), reply, refcon);
  } @catch (NSException* exception) {
    reportError(reply, [NSString stringWithFormat:@"Failed to load LiferayNativity with exception: %@", exception]);
  }

  return 1;
}

EXPORT OSErr HandleLoadedEvent(const AppleEvent* ev, AppleEvent* reply, long refcon) {
  LNBundleType type = mainBundleType(reply);
  if ((type == LiferayNativityBundleType) && liferayNativityLoaded) {
    return noErr;
  }
  reportError(reply, @"LiferayNativity not loaded");
  return 1;
}

EXPORT OSErr HandleUnloadEvent(const AppleEvent* ev, AppleEvent* reply, long refcon) {
  @try {
    if (!liferayNativityLoaded) {
      NSLog(@"LiferayNativityInjector: not loaded.");
      return noErr;
    }

    NSString* bundleName = liferayNativityBundleName;

    NSBundle* liferayNativityInjectorBundle = [NSBundle bundleForClass:[LiferayNativityInjector class]];
    NSString* liferayNativityLocation = [liferayNativityInjectorBundle pathForResource:bundleName ofType:@"bundle"];
    NSBundle* pluginBundle = [NSBundle bundleWithPath:liferayNativityLocation];
    if (!pluginBundle) {
      reportError(reply, [NSString stringWithFormat:@"Unable to create bundle from path: %@ [%@]", liferayNativityLocation, liferayNativityInjectorBundle]);
      return 2;
    }

    Class principalClass = [pluginBundle principalClass];
    if (!principalClass) {
      reportError(reply, [NSString stringWithFormat:@"Unable to retrieve principalClass for bundle: %@", pluginBundle]);
      return 3;
    }
    id principalClassObject = NSClassFromString(NSStringFromClass(principalClass));
    if ([principalClassObject respondsToSelector:@selector(uninstall)]) {
      NSLog(@"LiferayNativityInjector: Uninstalling %@ ...", bundleName);
      [principalClassObject uninstall];
    }

    liferayNativityLoaded = false;

    return noErr;
  } @catch (NSException* exception) {
    reportError(reply, [NSString stringWithFormat:@"Failed to unload LiferayNativity with exception: %@", exception]);
  }

  return 1;
}