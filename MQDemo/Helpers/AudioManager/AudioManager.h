//
//  AudioManager.h

@import Foundation;
@import UIKit;

NS_ASSUME_NONNULL_BEGIN

typedef void(^PlayAudioCompletion)(BOOL successful);
typedef void(^RecordAudioCompletion)(NSData* _Nullable audioData);

extern NSString* const AudioManagerAudioRouteChanged;

typedef NS_ENUM(NSInteger, AudioRouteType) {
    AudioRouteTypeSpeaker = 0,
    AudioRouteTypeBluetooth,
    AudioRouteTypeUSB,
    AudioRouteTypeAUX,
    AudioRouteTypeOther
};

typedef NS_ENUM(NSInteger, AudioBluetoothMode) {
    AudioBluetoothModeAuto = 0,
    AudioBluetoothModeOn,
    AudioBluetoothModeOff,
    AudioBluetoothModeHFP
};

typedef NS_ENUM(NSInteger, AudioVolumeLevel) {
    AudioVolumeLevelHigh = 0,
    AudioVolumeLevelMed,
    AudioVolumeLevelLow,
    AudioVolumeLevelMute
};

@protocol AudioManagerLoggingDelegate <NSObject>
- (void) audioLogEvent:(NSString*)event;
@end


@interface AudioManager : NSObject

-(void) playAudio:(NSData*)audioData completion:(PlayAudioCompletion)block;
-(void) playText:(NSString*)text language:(nullable NSString*)languageCode completion:(PlayAudioCompletion)block;
-(void) playAudio:(NSData*)audioData text:(NSString*)text language:(nullable NSString*)languageCode completion:(PlayAudioCompletion)block;
-(void) stopPlayback;

-(void) requestRecordPermission:(void (^ _Nullable)(BOOL) )completion;
-(BOOL) recordAudio:(BOOL)vibrateFirst;

// Stop recording, and get whatever audio has been recorded.
-(NSData*) stopRecording;

// Will return the currently recorded data instantly, and also call the
// completion when audio has finished recording (callback may be called
// instantly).
-(NSData* _Nullable) stopRecordingWithCompletion:(RecordAudioCompletion _Nullable)completion;

// Call this whenever the app resumes from the background so the audio system can always
// ensure it is in the right state.
-(void) appResumed;

// Convert AudioVolumeLevel to human readable string.
- (NSString *)volumeLevelString;

@property (nonatomic, readonly) CGFloat averageLevel;  // Recording
@property (nonatomic, readonly) CGFloat playbackProgress;
@property (nonatomic, readonly) BOOL playingAudio;
@property (nonatomic, readonly) BOOL isRecording;

@property (nonatomic) AudioBluetoothMode bluetoothMode;

@property (nonatomic) AudioVolumeLevel volumeLevel; // Defaults to AudioVolumeLevelMed!

// "active" represents that the app is in a state where it will be generating
// audio. E.g., when navigating.
@property (nonatomic) BOOL active;

// "foreground" represents whether the app is in the foreground or background.
@property (nonatomic) BOOL foreground;

@property (readonly) AudioRouteType audioRouteType;
@property (readonly)  NSString* audioRouteName;

@property (readonly) AudioRouteType expectedAudioRouteType;
@property (readonly) NSString* expectedAudioRouteName;

@property (readonly) NSTimeInterval expectedOutputLatency;

@property (nonatomic, weak) id <AudioManagerLoggingDelegate> loggingDelegate;

// When active and in the foreground, the audio session will be set such that
// the volume controls set the app volume, as opposed to the ringer volume.

NS_ASSUME_NONNULL_END

@end
