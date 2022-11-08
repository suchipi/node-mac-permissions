#include "napi.h"

#include "impl.h"

/***** EXPORTED FUNCTIONS *****/

// Returns the user's access consent status as a string.
Napi::Value GetAuthStatus(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();
  std::string auth_status;

  const std::string type = info[0].As<Napi::String>().Utf8Value();
  if (type == "contacts") {
    auth_status = ContactAuthStatus();
  } else if (type == "calendar") {
    auth_status = EventAuthStatus("calendar");
  } else if (type == "reminders") {
    auth_status = EventAuthStatus("reminders");
  } else if (type == "full-disk-access") {
    auth_status = FDAAuthStatus();
  } else if (type == "microphone") {
    auth_status = MediaAuthStatus("microphone");
  } else if (type == "photos-add-only") {
    auth_status = PhotosAuthStatus("add-only");
  } else if (type == "photos-read-write") {
    auth_status = PhotosAuthStatus("read-write");
  } else if (type == "speech-recognition") {
    auth_status = SpeechRecognitionAuthStatus();
  } else if (type == "camera") {
    auth_status = MediaAuthStatus("camera");
  } else if (type == "accessibility") {
    auth_status = AXIsProcessTrusted() ? kAuthorized : kDenied;
  } else if (type == "location") {
    auth_status = LocationAuthStatus();
  } else if (type == "screen") {
    auth_status = ScreenAuthStatus();
  } else if (type == "bluetooth") {
    auth_status = BluetoothAuthStatus();
  } else if (type == "music-library") {
    auth_status = MusicLibraryAuthStatus();
  } else if (type == "input-monitoring") {
    auth_status = InputMonitoringAuthStatus();
  }

  return Napi::Value::From(env, auth_status);
}

// Request access to various protected folders on the system.
Napi::Promise AskForFoldersAccess(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();
  Napi::Promise::Deferred deferred = Napi::Promise::Deferred::New(env);
  const std::string folder_name = info[0].As<Napi::String>().Utf8Value();

  NSString *path = @"";
  if (folder_name == "documents") {
    NSURL *url = URLForDirectory(NSDocumentDirectory);
    path = [url path];
  } else if (folder_name == "downloads") {
    NSURL *url = URLForDirectory(NSDownloadsDirectory);
    path = [url path];
  } else if (folder_name == "desktop") {
    NSURL *url = URLForDirectory(NSDesktopDirectory);
    path = [url path];
  }

  NSError *error = nil;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray<NSString *> *contents __unused =
      [fm contentsOfDirectoryAtPath:path error:&error];

  std::string status = (error) ? kDenied : kAuthorized;
  deferred.Resolve(Napi::String::New(env, status));
  return deferred.Promise();
}

// Request Contacts access.
Napi::Promise AskForContactsAccess(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();
  Napi::Promise::Deferred deferred = Napi::Promise::Deferred::New(env);
  Napi::ThreadSafeFunction ts_fn = Napi::ThreadSafeFunction::New(
      env, Napi::Function::New(env, NoOp), "contactsCallback", 0, 1);

  __block Napi::ThreadSafeFunction tsfn = ts_fn;
  CNContactStore *store = [CNContactStore new];
  [store
      requestAccessForEntityType:CNEntityTypeContacts
               completionHandler:^(BOOL granted, NSError *error) {
                 auto callback = [=](Napi::Env env, Napi::Function js_cb,
                                     const char *granted) {
                   deferred.Resolve(Napi::String::New(env, granted));
                 };
                 tsfn.BlockingCall(granted ? "authorized" : "denied", callback);
                 tsfn.Release();
               }];

  return deferred.Promise();
}

// Request Calendar access.
Napi::Promise AskForCalendarAccess(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();
  Napi::Promise::Deferred deferred = Napi::Promise::Deferred::New(env);
  Napi::ThreadSafeFunction ts_fn = Napi::ThreadSafeFunction::New(
      env, Napi::Function::New(env, NoOp), "calendarCallback", 0, 1);

  __block Napi::ThreadSafeFunction tsfn = ts_fn;
  [[EKEventStore new]
      requestAccessToEntityType:EKEntityTypeEvent
                     completion:^(BOOL granted, NSError *error) {
                       auto callback = [=](Napi::Env env, Napi::Function js_cb,
                                           const char *granted) {
                         deferred.Resolve(Napi::String::New(env, granted));
                       };
                       tsfn.BlockingCall(granted ? "authorized" : "denied",
                                         callback);
                       tsfn.Release();
                     }];

  return deferred.Promise();
}

// Request Reminders access.
Napi::Promise AskForRemindersAccess(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();
  Napi::Promise::Deferred deferred = Napi::Promise::Deferred::New(env);
  Napi::ThreadSafeFunction ts_fn = Napi::ThreadSafeFunction::New(
      env, Napi::Function::New(env, NoOp), "remindersCallback", 0, 1);

  __block Napi::ThreadSafeFunction tsfn = ts_fn;
  [[EKEventStore new]
      requestAccessToEntityType:EKEntityTypeReminder
                     completion:^(BOOL granted, NSError *error) {
                       auto callback = [=](Napi::Env env,
                                           Napi::Function prom_cb,
                                           const char *granted) {
                         deferred.Resolve(Napi::String::New(env, granted));
                       };
                       tsfn.BlockingCall(granted ? "authorized" : "denied",
                                         callback);
                       tsfn.Release();
                     }];

  return deferred.Promise();
}

// Request Full Disk Access.
void AskForFullDiskAccess(const Napi::CallbackInfo &info) {
  OpenPrefPane("Privacy_AllFiles");
}

// Request Camera access.
Napi::Promise AskForCameraAccess(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();
  Napi::Promise::Deferred deferred = Napi::Promise::Deferred::New(env);
  Napi::ThreadSafeFunction ts_fn = Napi::ThreadSafeFunction::New(
      env, Napi::Function::New(env, NoOp), "cameraCallback", 0, 1);

  if (@available(macOS 10.14, *)) {
    std::string auth_status = MediaAuthStatus("camera");

    if (auth_status == kNotDetermined) {
      __block Napi::ThreadSafeFunction tsfn = ts_fn;
      [AVCaptureDevice
          requestAccessForMediaType:AVMediaTypeVideo
                  completionHandler:^(BOOL granted) {
                    auto callback = [=](Napi::Env env, Napi::Function js_cb,
                                        const char *granted) {
                      deferred.Resolve(Napi::String::New(env, granted));
                    };

                    tsfn.BlockingCall(granted ? "authorized" : "denied",
                                      callback);
                    tsfn.Release();
                  }];
    } else if (auth_status == kDenied) {
      OpenPrefPane("Privacy_Camera");

      ts_fn.Release();
      deferred.Resolve(Napi::String::New(env, kDenied));
    } else {
      ts_fn.Release();
      deferred.Resolve(Napi::String::New(env, auth_status));
    }
  } else {
    ts_fn.Release();
    deferred.Resolve(Napi::String::New(env, kAuthorized));
  }

  return deferred.Promise();
}

// Request Speech Recognition access.
Napi::Promise AskForSpeechRecognitionAccess(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();
  Napi::Promise::Deferred deferred = Napi::Promise::Deferred::New(env);
  Napi::ThreadSafeFunction ts_fn = Napi::ThreadSafeFunction::New(
      env, Napi::Function::New(env, NoOp), "speechRecognitionCallback", 0, 1);

  if (@available(macOS 10.15, *)) {
    std::string auth_status = SpeechRecognitionAuthStatus();

    if (auth_status == kNotDetermined) {
      __block Napi::ThreadSafeFunction tsfn = ts_fn;
      [SFSpeechRecognizer
          requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
            auto callback = [=](Napi::Env env, Napi::Function js_cb,
                                const char *granted) {
              deferred.Resolve(Napi::String::New(env, granted));
            };
            std::string auth_result = StringFromSpeechRecognitionStatus(status);
            tsfn.BlockingCall(auth_result.c_str(), callback);
            tsfn.Release();
          }];
    } else if (auth_status == kDenied) {
      OpenPrefPane("Privacy_SpeechRecognition");

      ts_fn.Release();
      deferred.Resolve(Napi::String::New(env, kDenied));
    } else {
      ts_fn.Release();
      deferred.Resolve(Napi::String::New(env, auth_status));
    }
  } else {
    ts_fn.Release();
    deferred.Resolve(Napi::String::New(env, kAuthorized));
  }

  return deferred.Promise();
}

// Request Photos access.
Napi::Promise AskForPhotosAccess(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();
  Napi::Promise::Deferred deferred = Napi::Promise::Deferred::New(env);
  Napi::ThreadSafeFunction ts_fn = Napi::ThreadSafeFunction::New(
      env, Napi::Function::New(env, NoOp), "photosCallback", 0, 1);

  std::string access_level = info[0].As<Napi::String>().Utf8Value();
  std::string auth_status = PhotosAuthStatus(access_level);

  if (auth_status == kNotDetermined) {
    __block Napi::ThreadSafeFunction tsfn = ts_fn;
    if (@available(macOS 10.16, *)) {
      [PHPhotoLibrary
          requestAuthorizationForAccessLevel:GetPHAccessLevel(access_level)
                                     handler:^(PHAuthorizationStatus status) {
                                       auto callback =
                                           [=](Napi::Env env,
                                               Napi::Function js_cb,
                                               const char *granted) {
                                             deferred.Resolve(Napi::String::New(
                                                 env, granted));
                                           };
                                       tsfn.BlockingCall(
                                           StringFromPhotosStatus(status)
                                               .c_str(),
                                           callback);
                                       tsfn.Release();
                                     }];
    } else {
      [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        auto callback = [=](Napi::Env env, Napi::Function js_cb,
                            const char *granted) {
          deferred.Resolve(Napi::String::New(env, granted));
        };
        tsfn.BlockingCall(StringFromPhotosStatus(status).c_str(), callback);
        tsfn.Release();
      }];
    }
  } else if (auth_status == kDenied) {
    OpenPrefPane("Privacy_Photos");

    ts_fn.Release();
    deferred.Resolve(Napi::String::New(env, kDenied));
  } else {
    ts_fn.Release();
    deferred.Resolve(Napi::String::New(env, auth_status));
  }
  return deferred.Promise();
}

// Request Microphone access.
Napi::Promise AskForMicrophoneAccess(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();
  Napi::Promise::Deferred deferred = Napi::Promise::Deferred::New(env);
  Napi::ThreadSafeFunction ts_fn = Napi::ThreadSafeFunction::New(
      env, Napi::Function::New(env, NoOp), "microphoneCallback", 0, 1);

  if (@available(macOS 10.14, *)) {
    std::string auth_status = MediaAuthStatus("microphone");

    if (auth_status == kNotDetermined) {
      __block Napi::ThreadSafeFunction tsfn = ts_fn;
      [AVCaptureDevice
          requestAccessForMediaType:AVMediaTypeAudio
                  completionHandler:^(BOOL granted) {
                    auto callback = [=](Napi::Env env, Napi::Function js_cb,
                                        const char *granted) {
                      deferred.Resolve(Napi::String::New(env, granted));
                    };

                    tsfn.BlockingCall(granted ? "authorized" : "denied",
                                      callback);
                    tsfn.Release();
                  }];
    } else if (auth_status == kDenied) {
      OpenPrefPane("Privacy_Microphone");

      ts_fn.Release();
      deferred.Resolve(Napi::String::New(env, kDenied));
    } else {
      ts_fn.Release();
      deferred.Resolve(Napi::String::New(env, auth_status));
    }
  } else {
    ts_fn.Release();
    deferred.Resolve(Napi::String::New(env, kAuthorized));
  }

  return deferred.Promise();
}

// Request Input Monitoring access.
Napi::Promise AskForInputMonitoringAccess(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();
  Napi::Promise::Deferred deferred = Napi::Promise::Deferred::New(env);

  if (@available(macOS 10.15, *)) {
    std::string auth_status = InputMonitoringAuthStatus();

    if (auth_status == kNotDetermined) {
      IOHIDRequestAccess(kIOHIDRequestTypeListenEvent);
      deferred.Resolve(Napi::String::New(env, kDenied));
    } else if (auth_status == kDenied) {
      OpenPrefPane("Privacy_ListenEvent");

      deferred.Resolve(Napi::String::New(env, kDenied));
    } else {
      deferred.Resolve(Napi::String::New(env, auth_status));
    }
  } else {
    deferred.Resolve(Napi::String::New(env, kAuthorized));
  }

  return deferred.Promise();
}

// Request Apple Music Library access.
Napi::Promise AskForMusicLibraryAccess(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();
  Napi::Promise::Deferred deferred = Napi::Promise::Deferred::New(env);
  Napi::ThreadSafeFunction ts_fn = Napi::ThreadSafeFunction::New(
      env, Napi::Function::New(env, NoOp), "musicLibraryCallback", 0, 1);

  if (@available(macOS 10.16, *)) {
    std::string auth_status = MusicLibraryAuthStatus();

    if (auth_status == kNotDetermined) {
      __block Napi::ThreadSafeFunction tsfn = ts_fn;
      [SKCloudServiceController
          requestAuthorization:^(SKCloudServiceAuthorizationStatus status) {
            auto callback = [=](Napi::Env env, Napi::Function js_cb,
                                const char *granted) {
              deferred.Resolve(Napi::String::New(env, granted));
            };
            tsfn.BlockingCall(StringFromMusicLibraryStatus(status).c_str(),
                              callback);
            tsfn.Release();
          }];
    } else if (auth_status == kDenied) {
      OpenPrefPane("Privacy_Media");

      ts_fn.Release();
      deferred.Resolve(Napi::String::New(env, kDenied));
    } else {
      ts_fn.Release();
      deferred.Resolve(Napi::String::New(env, auth_status));
    }
  } else {
    ts_fn.Release();
    deferred.Resolve(Napi::String::New(env, kAuthorized));
  }

  return deferred.Promise();
}

// Request Screen Capture Access.
void AskForScreenCaptureAccess(const Napi::CallbackInfo &info) {
  if (@available(macOS 10.16, *)) {
    CGRequestScreenCaptureAccess();
  } else if (@available(macOS 10.15, *)) {
    // Tries to create a capture stream. This is necessary to add the app back
    // to the list in sysprefs if the user previously denied.
    // https://stackoverflow.com/questions/56597221/detecting-screen-recording-settings-on-macos-catalina
    CGDisplayStreamRef stream = CGDisplayStreamCreate(
        CGMainDisplayID(), 1, 1, kCVPixelFormatType_32BGRA, NULL,
        ^(CGDisplayStreamFrameStatus status, uint64_t displayTime,
          IOSurfaceRef frameSurface, CGDisplayStreamUpdateRef updateRef){
        });

    if (stream) {
      CFRelease(stream);
    } else {
      if (!HasOpenSystemPreferencesDialog()) {
        OpenPrefPane("Privacy_ScreenCapture");
      }
    }
  }
}

// Request Accessibility Access.
void AskForAccessibilityAccess(const Napi::CallbackInfo &info) {
  NSDictionary *options = @{(id)kAXTrustedCheckOptionPrompt : @(NO)};
  bool trusted = AXIsProcessTrustedWithOptions((CFDictionaryRef)options);

  if (!trusted) {
    OpenPrefPane("Privacy_Accessibility");
  }
}

// Initializes all functions exposed to JS
Napi::Object Init(Napi::Env env, Napi::Object exports) {
  exports.Set(Napi::String::New(env, "getAuthStatus"),
              Napi::Function::New(env, GetAuthStatus));
  exports.Set(Napi::String::New(env, "askForContactsAccess"),
              Napi::Function::New(env, AskForContactsAccess));
  exports.Set(Napi::String::New(env, "askForCalendarAccess"),
              Napi::Function::New(env, AskForCalendarAccess));
  exports.Set(Napi::String::New(env, "askForRemindersAccess"),
              Napi::Function::New(env, AskForRemindersAccess));
  exports.Set(Napi::String::New(env, "askForFoldersAccess"),
              Napi::Function::New(env, AskForFoldersAccess));
  exports.Set(Napi::String::New(env, "askForFullDiskAccess"),
              Napi::Function::New(env, AskForFullDiskAccess));
  exports.Set(Napi::String::New(env, "askForCameraAccess"),
              Napi::Function::New(env, AskForCameraAccess));
  exports.Set(Napi::String::New(env, "askForMicrophoneAccess"),
              Napi::Function::New(env, AskForMicrophoneAccess));
  exports.Set(Napi::String::New(env, "askForMusicLibraryAccess"),
              Napi::Function::New(env, AskForMusicLibraryAccess));
  exports.Set(Napi::String::New(env, "askForSpeechRecognitionAccess"),
              Napi::Function::New(env, AskForSpeechRecognitionAccess));
  exports.Set(Napi::String::New(env, "askForPhotosAccess"),
              Napi::Function::New(env, AskForPhotosAccess));
  exports.Set(Napi::String::New(env, "askForScreenCaptureAccess"),
              Napi::Function::New(env, AskForScreenCaptureAccess));
  exports.Set(Napi::String::New(env, "askForAccessibilityAccess"),
              Napi::Function::New(env, AskForAccessibilityAccess));
  exports.Set(Napi::String::New(env, "askForInputMonitoringAccess"),
              Napi::Function::New(env, AskForInputMonitoringAccess));

  return exports;
}

NODE_API_MODULE(permissions, Init)
