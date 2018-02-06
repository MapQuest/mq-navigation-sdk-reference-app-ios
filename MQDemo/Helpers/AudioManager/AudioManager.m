//
//  AudioManager.m

@import UIKit;
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "AudioManager.h"
#import "NSTimer+Block.h"
#import "NSObject+DelayedBlock.h"

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)


// Changing the audio system?  Here are some tests you should do on real hardware to ensure you didn't
// break anything:
//
// -Try turning volume up and down while navigating and prompt playing
// -Try turning volume up and down while navigating and no prompt playing (should adjust app volume, not system volume)
// -Try turning volume up and down when viewing map or on home screen (should adjust system volume, not app volume)
// -Start navigation, hit the home button, then go back to the app, and verify that the volume buttons work.
//
// -Navigate with music playing (app will lower volume of music)
// -Navigate and close the app (prompts should still play, music should still duck)
//
// -Record voice prompts with music playing (app will mute music while recording)
//
// -Plug in headphones while app is running
// -Plug in headphones while app is running and audio is playing
// -Yank headphones while app is running
// -Yank headphones while app is running and audio is playing
// -Receive a system audio alert (SMS) while app is running
// -Receive a system audio alert (SMS) while app is running and audio is playing
//

NSString* const AudioManagerAudioRouteChanged = @"AudioManagerAudioRouteChanged";


@interface AudioManager (/*Private*/) <AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate>

@property (readwrite) NSString* audioRouteName;

@end


#pragma mark
@implementation AudioManager {
    AVAudioPlayer *_player;
    AVAudioRecorder *_recorder;

    BOOL _playingAudio;
    BOOL _readyToPlay;

    NSString* _recordPath;
    CGFloat _loudestPeak;
    NSTimer* _finishRecordingTimer; // We delay finishing recording, to get that last bit of audio (bluetooth)

    AVSpeechSynthesisVoice* _voice;
    AVSpeechSynthesizer* _synthesizer;
    CGFloat _utteranceRate;
    
    NSString* _audioRouteName;
    AudioRouteType _audioRouteType;
    
    NSString* _expectedAudioRouteName;
    AudioRouteType _expectedAudioRouteType;
    
    // Map each utterance to the corresponding completion block
    NSMutableDictionary* _utteranceCompletionMap;
    NSMutableDictionary* _playerCompletionMap;
    
    // This is used to indicate what thing is currently playing.
    // It will be an AVSpeechUtterance for text or AVAudioPlayer for audio data
    NSObject* _currentlyPlayingData;

    // Debug stuff for getting to the bottom of our audio woes
    NSTimer* _playbackMonitorTimer;
    NSString* _lastRequestedText;
    NSString* _lastStartedText;
    NSString* _lastFinishedText;
    BOOL _textCanceled;
}

@synthesize playingAudio = _playingAudio;

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (id)init
{
    if (!(self = [super init]))
        return nil;

    NSArray *paths          = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* docFolderPath = [paths objectAtIndex:0];
    _recordPath             = [docFolderPath stringByAppendingPathComponent:@"sound.m4a"];
    
    [self setupVoiceAndUtteranceRateWithLanguage:nil];

    // Set Defaults
    _volumeLevel = AudioVolumeLevelHigh;
    [self setBluetoothMode:AudioBluetoothModeAuto];
    
    _expectedOutputLatency = 0.0;
    
    _utteranceCompletionMap = [NSMutableDictionary new];
    _playerCompletionMap = [NSMutableDictionary new];

    NSError* errRet;
    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryAmbient error:nil];
    [session setActive:NO error:&errRet];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_audioSessionRouteChanged:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:[AVAudioSession sharedInstance]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_silenceSecondaryAudioHintChanged:)
                                                 name:AVAudioSessionSilenceSecondaryAudioHintNotification
                                               object:[AVAudioSession sharedInstance]];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_appWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_appDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_appWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_appDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    // Log the initial audio route
    [self _tagAudioRouteInfoWithReason:@"Initial"];

    return self;
}

- (void)setupVoiceAndUtteranceRateWithLanguage:(NSString*)languageCode
{
    if (languageCode == nil) {
        languageCode = @"en-US";
    }
    
    languageCode = [languageCode stringByReplacingOccurrencesOfString:@"_" withString:@"-"];
    
    // Speech
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9.0")) {
        _voice = [AVSpeechSynthesisVoice voiceWithIdentifier:[NSString stringWithFormat:@"com.apple.ttsbundle.siri_female_%@_premium", languageCode]];
        
        if (_voice == nil) {
            _voice = [AVSpeechSynthesisVoice voiceWithIdentifier:[NSString stringWithFormat:@"com.apple.ttsbundle.siri_female_%@_compact", languageCode]];
        }
    }
    
    if (_voice == nil) {
        _voice = [AVSpeechSynthesisVoice voiceWithLanguage:languageCode];

        if (_voice == nil) {
            _voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"en-US"];
        }
    }
    
    NSAssert(_voice != nil, @"Problem…");
    
    NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
    if ([currSysVer floatValue] < 8.0) {
        // iOS 7
        // This was also hand-tuned. Why the default is no fast doesn't make much sense.
        _utteranceRate = (AVSpeechUtteranceDefaultSpeechRate + AVSpeechUtteranceMinimumSpeechRate) / 2.0;
        
    } else if ([currSysVer floatValue] >= 9.0) {
        // iOS 9+ (& iOS 9 SDK)
        _utteranceRate = 0.505;  // Seems like Apple finally fixed this in iOS 9.
        
    } else {
        // iOS 8
        _utteranceRate = 0.12; // Hand-tuned this. The default rate of 0.5 sounds insanely fast.
    }
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)setActive:(BOOL)active
{
    if (_active == active) {
        return;
    }

    _active = active;
    [self _setIdle];
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)setForeground:(BOOL)foreground
{
    if (foreground == _foreground) {
        return;
    }

    _foreground = foreground;
    [self _setIdle];
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)setBluetoothMode:(AudioBluetoothMode)bluetoothMode
{
    if (bluetoothMode == _bluetoothMode) {
        return;
    }
    _bluetoothMode = bluetoothMode;
    [self _checkExpectedAudioRoute];
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
-(void)playAudio:(NSData*)audioData completion:(PlayAudioCompletion)block
{
    if (_volumeLevel == AudioVolumeLevelMute) {
        block(NO);
        return;
    }
    
    if (_recorder.isRecording) {
        block(NO);
        return;
    }
    
    if (![self _prepareToPlay]) {
        block(NO);
        [self _tagEvent:@"avaudioplayer error" withProperties:@{@"where": @"playAudio"}];
        return;
    }

    NSError* err = nil;
    _player = [[AVAudioPlayer alloc] initWithData:audioData error:&err];
    _player.volume = [self _volumeNumericSetting];
    if (err != nil) {
        [self _tagEvent:@"avaudioplayer error" withProperties:@{@"code" : @([err code])}];
        _player = nil;
        block(NO);
        return;
    }
    
    if (block != nil) {
        [_playerCompletionMap setObject:[block copy] forKey:@(_player.hash)];
    }
        
    _player.delegate = self;
    _currentlyPlayingData = _player;
    [_player play];
    _playingAudio = YES;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
-(void)playAudio:(NSData*)audioData text:(NSString*)text language:(nullable NSString*)languageCode completion:(PlayAudioCompletion)block
{
    if (_volumeLevel == AudioVolumeLevelMute) {
        block(NO);
        return;
    }
    
    if (!audioData) {
        [self playText:text language:languageCode completion:block];
        return;
    }

    [self playAudio:audioData completion:^(BOOL successful) {
        if (!successful) {
            block(NO);
        } else if (text) {
            [self playText:text language:languageCode completion:block];
        }
    }];
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
-(void)playText:(NSString*)text language:(nullable NSString*)languageCode completion:(PlayAudioCompletion)block
{
    if (_volumeLevel == AudioVolumeLevelMute) {
        block(NO);
        return;
    }
    
    if (_recorder.isRecording) {
        block(NO);
        return;
    }
    
    // If previous TTS is still playing...
    if ([_synthesizer isSpeaking] && _currentlyPlayingData) {
        PlayAudioCompletion completion = _utteranceCompletionMap[@(_currentlyPlayingData.hash)];
        [_utteranceCompletionMap removeObjectForKey:@(_currentlyPlayingData.hash)];
        completion(NO);
    }

    if (![self _prepareToPlay]) {
        [self _tagEvent:@"avaudioplayer error" withProperties:@{@"where": @"playText"}];
        block(NO);
        return;
    }

    [self setupVoiceAndUtteranceRateWithLanguage:languageCode];
    AVSpeechUtterance* utterance = [[AVSpeechUtterance alloc] initWithString:text];
    utterance.voice = _voice;
    utterance.rate = _utteranceRate;
    utterance.volume = [self _volumeNumericSetting];
    
    [_utteranceCompletionMap setObject:[block copy] forKey:@(utterance.hash)];

    [self _startPlaybackMonitor:[self _durationForString:text]*3.0];
    _lastRequestedText = text;
    _textCanceled = NO;

    // Create a fresh synthesizer for each utterance. It's possible to re-use
    // the same synthesizer, but we've seen weird audio buginess in the past
    // that might be related to that.
    _synthesizer = [[AVSpeechSynthesizer alloc] init];
    _synthesizer.delegate = self;

    _playingAudio = YES;
    _currentlyPlayingData = utterance;
    [_synthesizer speakUtterance:utterance];

    // Is it possible for it to be paused? It shouldn't, but let's make sure
    [_synthesizer continueSpeaking];
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
-(void) stopPlayback {
    [self _stopPlayback];
    [self _setIdle];
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
-(void) requestRecordPermission:(nullable void (^)(BOOL))completion
{
    [self _stopPlaybackAndWait];
    [self _setIdle];
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        // THIS DOESN'T GET CALLED ON MAIN THREAD!!
        [self performBlockOnMainThread:^{
            if (completion) {
                completion(granted);
            }
        }];
    }];
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
-(BOOL) recordAudio:(BOOL)vibrateFirst
{
    // If there's a current recording that's finishing up, finish it up now
    [self _finalizeRecording];

    [_recorder stop];
    _recorder = nil;

    if (![self _prepareToRecord]) {
        return NO;
    }

    _loudestPeak = -160.0;
    
    NSError* err;
    if ([[NSFileManager defaultManager] isDeletableFileAtPath:_recordPath]) {
        BOOL success = [[NSFileManager defaultManager] removeItemAtPath:_recordPath error:&err];
        if (!success) {
            // Hmm..
        }
    }
    
    NSURL *newURL = [[NSURL alloc] initFileURLWithPath:_recordPath];
    
    NSDictionary *recordSettings = [[NSDictionary alloc] initWithObjectsAndKeys:
                                    [NSNumber numberWithFloat: 44100.], AVSampleRateKey,
                                    [NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                                    [NSNumber numberWithInt: 1], AVNumberOfChannelsKey,
                                    [NSNumber numberWithInt: AVAudioQualityHigh],
                                    AVEncoderAudioQualityKey,
                                    nil];

    _recorder = [[AVAudioRecorder alloc] initWithURL:newURL settings:recordSettings error:&err];
    
    BOOL success = NO;
    if (_recorder) {
        _recorder.meteringEnabled = YES;

        if ([_recorder prepareToRecord]) {
            if (vibrateFirst) {
                // We want to vibrate after most of the setup, because the setup can
                // take a while (e.g. with bluetooth) and we don't want to prompt
                // the user to speak until we're actually ready to record.
                // We have to do this BEFORE starting recording though, because
                // iOS disables all vibration while recording and there's no way
                // around it, which is awesome.
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);

                // And this is awful, but we need to allow a little time for the
                // vibrate. Otherwise, sometimes it seems to be silenced by the
                // record.
                [NSThread sleepForTimeInterval:0.1];
            }

            if ([_recorder record]) {
                success = YES;
            }
        }
    }

    return success;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
-(NSData*) stopRecording
{
    return [self stopRecordingWithCompletion:nil];
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
-(nullable NSData*) stopRecordingWithCompletion:(nullable RecordAudioCompletion)completion
{
    NSData* audio = nil;
    [_finishRecordingTimer invalidate];
    _finishRecordingTimer = nil;

    if (_recorder) {
        if (completion && [self _checkInputType:@"BluetoothHFP"]) {
            // This is async. We record for an extra 0.5 seconds, because bluetooth
            // recording latency means not all the audio has been saved to the
            // file yet.
            // TODO: Do this better. Predict the latency by checking the file
            // after starting recording, and use that latency? Or is there a
            // more 'correct' way to do this?
            _finishRecordingTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 block:^{
                _finishRecordingTimer = nil;
                NSData* data = [self stopRecording]; // Won't be async because we didn't give a completion
                completion(data);
            }];

            // Return the current contents of the file, though it might not be
            // used since the completion is coming later.
            return [NSData dataWithContentsOfFile:_recordPath];
        }

        [_recorder stop];

        // Give the recorder a chance to actually stop. Otherwise,
        // setting the session to inactive will fail.
        int tries = 10;
        while (_recorder.isRecording && tries-- > 0) {
            NSTimeInterval sleepSeconds = 0.02;
            [NSThread sleepForTimeInterval:sleepSeconds];
        }
        _recorder = nil;
        audio = [NSData dataWithContentsOfFile:_recordPath];
    }
    
    [self _setIdle];

    if (completion) {
        completion(audio);
    }

    return audio;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (CGFloat) averageLevel
{
    [_recorder updateMeters];
    
    CGFloat ave  = [_recorder averagePowerForChannel:0];
    CGFloat peak = [_recorder peakPowerForChannel:0];
    CGFloat min  = -60.0;
    
    if (peak > _loudestPeak) {
        _loudestPeak = peak;
    }
    
    CGFloat range = _loudestPeak - min;  // positive
    
    CGFloat normalizedPower = ((min - ave) / range);
    
    return normalizedPower * -1.0;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
-(CGFloat) playbackProgress
{
    if (_player && _player.playing) {
        return _player.currentTime / _player.duration;
    }
    return 0.0;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (BOOL) isRecording
{
    return _recorder.isRecording;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
-(void) appResumed
{
    // What happens if audio is being recorded? Could get stuck...
    
    [self _setIdle];
    [self _checkExpectedAudioRoute];
}


#pragma mark - Private
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (BOOL)_checkInputType:(NSString*)inputType
{
    for (AVAudioSessionPortDescription* port in [AVAudioSession sharedInstance].currentRoute.inputs) {
        if ([port.portType isEqualToString:inputType]) {
            return YES;
        }
    }
    return NO;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)_finalizeRecording
{
    // Sometimes we delay stopRecording a bit to make sure we get everything.
    // This triggers that timer to really stop recording and call the completion.
    if (_finishRecordingTimer) {
        NSTimer* t = _finishRecordingTimer;
        _finishRecordingTimer = nil;
        [t fire];
    }
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (BOOL)_logAudioSessionError:(NSError*)error what:(NSString*)what where:(NSString*)where
{
    if (error) {
        [self _tagEvent:@"avaudiosession error" withProperties:@{@"code" : @(error.code),
                                                                 @"what" : what,
                                                                 @"where": where}];
        return YES;
    }
    return NO;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (NSTimeInterval) _durationForString:(NSString*)text
{
    // Derived by fitting some prompts.
    // Something more robust wouldn't be a bad idea.
    return 1.24 + 0.06 * text.length;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void) _playbackMonitorHandler:(NSTimer*)timer
{
    [self _tagEvent:@"audio timeout" withProperties:@{@"synthesizer.isSpeaking" : @(_synthesizer.isSpeaking),
                                                      @"synthesizer.isPaused" : @(_synthesizer.isPaused),
                                                      @"recorder.isRecording": @(_recorder.isRecording),
                                                      @"playingAudio": @(_playingAudio),
                                                      @"lastRequestedText": _lastRequestedText==nil ? NSNull.null : _lastRequestedText,
                                                      @"lastStartedText": _lastStartedText==nil ? NSNull.null : _lastStartedText,
                                                      @"textCanceled": @(_textCanceled)}];

    [self _stopPlaybackMonitor];
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void) _startPlaybackMonitor:(NSTimeInterval)delay
{
    [_playbackMonitorTimer invalidate];
    _playbackMonitorTimer = [NSTimer
                             scheduledTimerWithTimeInterval:delay
                                                     target:self
                                                   selector:@selector(_playbackMonitorHandler:)
                                                   userInfo:nil
                                                    repeats:NO];
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void) _stopPlaybackMonitor
{
    [_playbackMonitorTimer invalidate];
    _playbackMonitorTimer = nil;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
-(void) _stopPlayback
{
    [_player stop];
    [_synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    [self _stopPlaybackMonitor];
    _playingAudio = NO;

    _player = nil;
    _synthesizer = nil;

    // Clear out the completion maps, because they won't be finishing
    [_utteranceCompletionMap removeAllObjects];
    [_playerCompletionMap removeAllObjects];

    // Does NOT set the session to idle
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void) _stopPlaybackAndWait
{
    // Make a copy of these pointers, because they might be nilled out
    AVAudioPlayer* player = _player;
    AVSpeechSynthesizer* synthesizer = _synthesizer;

    [self _stopPlayback];

    int tries = 10;
    while ((synthesizer.isSpeaking || player.isPlaying) && tries-- > 0) {
        // Give the synthesizer/player a chance to actually stop. Otherwise,
        // setting the session to inactive will fail.
        NSTimeInterval sleepSeconds = 0.02;
        [NSThread sleepForTimeInterval:sleepSeconds];
    }
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)_setIdle
{
    if (_playingAudio || _recorder.isRecording) {
        return;
    }

    // Make sure the audio is really stopped before going forward
    [self _stopPlaybackAndWait];

    // If the session was set up to play, it isn't anymore.
    _readyToPlay = NO;
    
    NSError* err;
    AVAudioSession* session = [AVAudioSession sharedInstance];
    if (!_foreground || !_active) {
        
        // We don't need the volume switch to be connected to the TTS volume, because we're either
        // in the background or not in nav mode.
        
        // Flag allows background music that it can start playing again after we are done playing our direction.
        [session setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&err];
        [self _logAudioSessionError:err what:@"setActive(NO)" where:@"_setIdle, not foreground or not active"];
    }
    else {
        
        // Volume switch hack. When our app is running in the foreground and in nav mode, we always want the
        // volume switch to change our TTS volume, whether we're currently speaking or not.
        
        [session setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&err];
        [self _logAudioSessionError:err what:@"setActive(NO)" where:@"_setIdle"];
        err = nil;

        [session setCategory:AVAudioSessionCategoryAmbient error:&err];
        [self _logAudioSessionError:err what:@"setCategory" where:@"_setIdle"];
        err = nil;

        [session setActive:YES error:&err];
        [self _logAudioSessionError:err what:@"setActive(YES)" where:@"_setIdle"];
    }
    
    if (session.currentRoute.outputs.count > 0) {
        [self _updateAudioRouteWithAudioRouteName:[session.currentRoute.outputs[0] portType]];
    }
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (BOOL) _prepareToPlay
{
    [self _stopPlaybackAndWait]; // Stops the playback, but doesn't kill the session

    if (_readyToPlay) {
        // We're already playing audio. So leave the audio session active.
        return YES;
    }

    NSError* errRet;
    AVAudioSession* session = [AVAudioSession sharedInstance];

    [session setActive:NO error:&errRet];

    // I've seen this fail with "The operation couldn't be completed" while
    // using bluetooth. It seems to kind of work if we just ignore the error
    // though.
    [self _logAudioSessionError:errRet what:@"setActive(NO)" where:@"_prepareToPlay"];
    errRet = nil;
    
    NSString* category;
    AVAudioSessionCategoryOptions options;

    [self _determineAudioSystemCategory:&category options:&options expectedOutputLatency:&_expectedOutputLatency];
    
    [session setCategory:category
             withOptions:options
                   error:&errRet];

    if ([self _logAudioSessionError:errRet what:@"setCategory" where:@"_prepareToPlay"]) {
        return NO;
    }

    [session setMode:AVAudioSessionModeDefault error:&errRet];
    if ([self _logAudioSessionError:errRet what:@"setMode" where:@"_prepareToPlay"]) {
        return NO;
    }

    [session setActive:YES error:&errRet];
    if ([self _logAudioSessionError:errRet what:@"setActive(YES)" where:@"_prepareToPlay"]) {
        return NO;
    }

    _readyToPlay = YES;

    // Auto Route may change after switching the category. Need to study this more.
    if (session.currentRoute.outputs.count > 0) {
        [self _updateAudioRouteWithAudioRouteName:[session.currentRoute.outputs[0] portType]];
    }
    
    return YES;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (BOOL) _prepareToRecord
{
    [self _stopPlaybackAndWait];
    [self stopPlayback];

    NSError* errRet;
    AVAudioSession* session = [AVAudioSession sharedInstance];

    // If the session was set up to play, it isn't anymore.
    _readyToPlay = NO;

    [session setActive:NO error:&errRet];
    if ([self _logAudioSessionError:errRet what:@"setActive(NO)" where:@"_prepareToRecord"]) {
        return NO;
    }

    // Use PlayAndRecord because it allows co-existing with other audio that's
    // playing like music. With Record only, it interrupts the background audio.
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
             withOptions:(AVAudioSessionCategoryOptionMixWithOthers|
                          AVAudioSessionCategoryOptionDuckOthers|
                          AVAudioSessionCategoryOptionDefaultToSpeaker)
                   error:&errRet];

    if ([self _logAudioSessionError:errRet what:@"setCategory" where:@"_prepareToRecord"]) {
        return NO;
    }

    [session setMode:AVAudioSessionModeDefault error:&errRet];
    if ([self _logAudioSessionError:errRet what:@"setMode" where:@"_prepareToRecord"]) {
        return NO;
    }

    // Input gain is initially set to just over 0.1.  0.3 has a tiny bit of clipping while speaking
    // loud.  There must be some AGC stuff, right?
    BOOL canSet = [session isInputGainSettable];
    if (canSet) {
        [session setInputGain:0.2 error:&errRet];
        if ([self _logAudioSessionError:errRet what:@"setInputGain" where:@"_prepareToRecord"]) {
            return NO;
        }
    }

    [session setActive:YES error:&errRet];
    if ([self _logAudioSessionError:errRet what:@"setActive(YES)" where:@"_prepareToRecord"]) {
        return NO;
    }

    return YES;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void) _determineAudioSystemCategory:(NSString**)category options:(AVAudioSessionCategoryOptions*)options expectedOutputLatency:(NSTimeInterval*)expectedOutputLatency
{
    // This helps Podcast apps know to stop playing instead of ducking volume. Only available on iOS9
    AVAudioSessionCategoryOptions interruptSpokenAudioOptionFlag = 0x0;
    NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
    if ([currSysVer floatValue] >= 9.0) {
        // Turn off temporarily until Apple fixes behavior when SetSession is turned on.
//        interruptSpokenAudioOptionFlag = AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers;
    }
    
    NSTimeInterval const duckingDelay = 0.4; // This should be pretty consistent.
    NSTimeInterval const A2DPDelay = 1.0; // I've seen this near zero.
    NSTimeInterval const HFPDelay = 2.5;  // Usually a horrible delay. No idea how accurate this is.
    
    // Can't check for AudioRouteType since many HFP devices don't show up as Audio Routes unless they are active and playing audio.
    if (_bluetoothMode == AudioBluetoothModeHFP) {
        
        // User wants to force to Bluetooth HFP. We'll allow it!
        
        // [TODO] Is it possible for a car to support A2DP but not HFP? If so, I believe this will
        // revert to the speaker instead of trying to go over A2DP.
        
        *category = AVAudioSessionCategoryPlayAndRecord;
        *options = (AVAudioSessionCategoryOptionAllowBluetooth|
                    AVAudioSessionCategoryOptionMixWithOthers|
                    AVAudioSessionCategoryOptionDuckOthers|
                    AVAudioSessionCategoryOptionDefaultToSpeaker);
        
        *expectedOutputLatency = HFPDelay;
        
    } else if (_audioRouteType == AudioRouteTypeBluetooth && _bluetoothMode == AudioBluetoothModeOff) {
        
        // In this mode, we try to avoid playing audio all together. The key is to set the PlayAndRecord
        // category and omit the AllowBluetooth flag. Even though we're only playing audio, seems to
        // do the trick.
        
        *category = AVAudioSessionCategoryPlayAndRecord;
        
        if ([self _backgroundAudioPlaying]) {
            
            // This should sort of be an edge case (I think).
            // If we're paired with bluetooth and other audio is playing through it,
            // we don't want to duck, we want to interrupt the audio altogether. It will
            // stop playing over BT, we'll play our audio over the speaker (or whatever).
            
            // doesn't work when backgrounded, but google doesn't work either... (Mazda CX-5)
            // I've also seen it work, but the background audio never resumes.   (GOGroove BlueGATE, Bose Soundlink Mini)
            *options = (AVAudioSessionCategoryOptionDefaultToSpeaker);
            
            *expectedOutputLatency = 1.0; // Wild guess, should update as we get more data.
            
        } else {
            
            // Disable bluetooth. Ducking probably irrelevant.
            *options = (AVAudioSessionCategoryOptionMixWithOthers|
                        AVAudioSessionCategoryOptionDuckOthers|
                        AVAudioSessionCategoryOptionDefaultToSpeaker);
            *expectedOutputLatency = 0.0;
        }
        
    } else if (_audioRouteType == AudioRouteTypeBluetooth && _bluetoothMode == AudioBluetoothModeOn) {
        
        // Simply try to play audio and hope for the best. The Playback category will try to push
        // the audio over the A2DP channel. This rarely works in cars if audio isn't playing, but
        // will in some. Usually works if music is playing.
        
        *category = AVAudioSessionCategoryPlayback;
        *options = (AVAudioSessionCategoryOptionMixWithOthers|
                    AVAudioSessionCategoryOptionDuckOthers);
        
        if ([self _backgroundAudioPlaying]) {
            *expectedOutputLatency = duckingDelay;
        } else {
            *expectedOutputLatency = A2DPDelay;
        }
        
    } else if (_audioRouteType == AudioRouteTypeBluetooth && _bluetoothMode == AudioBluetoothModeAuto) {
        
        // Auto tries to be smart. Most cars do well when audio is already playing, and terrible if
        // audio is not playing. So our strategy is to duck it in if background audio is playing, go
        // over the speaker if it isn't.
        
        if ([self _backgroundAudioPlaying]) {
            
            // If audio is playing, try to play audio through A2DP
            *category = AVAudioSessionCategoryPlayback;
            *options = (AVAudioSessionCategoryOptionMixWithOthers|
                        AVAudioSessionCategoryOptionDuckOthers);
            *expectedOutputLatency = duckingDelay;
            
        } else {
            
            // No audio playing in background, disable BT w/ PlayAndRecord cat and omitAllowBluetooth.
            *category = AVAudioSessionCategoryPlayAndRecord;
            *options = (AVAudioSessionCategoryOptionMixWithOthers|
                        AVAudioSessionCategoryOptionDuckOthers|
                        AVAudioSessionCategoryOptionDefaultToSpeaker);
            *expectedOutputLatency = 0.0;
        }
        
    } else {
        
        // Speaker / AUX / USB
        // For the non bluetooth cases, we just play normally and hope for the best.
        
        *category = AVAudioSessionCategoryPlayback;
        *options = (AVAudioSessionCategoryOptionMixWithOthers|
                    AVAudioSessionCategoryOptionDuckOthers);
        
        // Note that we've added the interrupt spoken audio flag here. It is
        // too buggy over USB or Bluetooth, but should work great here!
        if (_audioRouteType != AudioRouteTypeUSB) {
            *options |= interruptSpokenAudioOptionFlag;
        }
        
        *expectedOutputLatency = 0.0;
        if ([self _backgroundAudioPlaying]) {
            *expectedOutputLatency += duckingDelay;
        }
    }
    
    return;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)_checkExpectedAudioRoute
{
    // TODO: I don't like that the logic used to determine whether to divert audio away from
    // Bluetooth is in two different places. 
    if ((_bluetoothMode == AudioBluetoothModeAuto && [self _currentOutputIsA2DP] && ![self _backgroundAudioPlaying] && !_readyToPlay) ||
        (_bluetoothMode == AudioBluetoothModeOff && [self _currentOutputIsA2DP] && ![self _backgroundAudioPlaying] && !_readyToPlay)) {
        
        // OK, this is pretty complicated. If we've configured the audio system to override bluetooth and
        // send it to the next best audio route, the only way I know of to figure out where it plans to send
        // audio is to make playback active for a moment.
        
        // This will make playback active, and change the audio route. We shouldn't risk interrupting background music, because
        // we're only doing this if it isn't playing :)
        [self _prepareToPlay];
        
        // Set idle again.
        [self _setIdle];
        
    } else if (_bluetoothMode == AudioBluetoothModeOff && [self _currentOutputIsA2DP] && [self _backgroundAudioPlaying] && !_readyToPlay) {
        
        // We can't test where audio is going to be sent, because _prepareToPlay will interrupt the background music, but
        // we can sure our audio will go somewhere other than Bluetooth.
        
        // do nothing, might be weird edge cases where expected route could be out of sync when the audio rate changes.
        
    } else {
        // Make projected audio and actual audio the same
        BOOL changed = _expectedAudioRouteType != _audioRouteType;
        
        _expectedAudioRouteType = _audioRouteType;
        _expectedAudioRouteName = _audioRouteName;
        
        // Update the latency
        if (!_playingAudio) {
            NSString* category;
            AVAudioSessionCategoryOptions options;
            NSTimeInterval expectedOutputLatency;
            [self _determineAudioSystemCategory:&category options:&options expectedOutputLatency:&expectedOutputLatency];
            _expectedOutputLatency = expectedOutputLatency;
        }
        
        if (changed) {
            // send event
            [[NSNotificationCenter defaultCenter] postNotificationName:AudioManagerAudioRouteChanged
                                                                object:self];
        }
    }
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)_didFinishPlayingData:(NSObject*)data success:(BOOL)success completion:(PlayAudioCompletion)completion
{
    BOOL setIdle = NO;

    if (_currentlyPlayingData == data) {
        _playingAudio = NO;
        setIdle = YES;
        _currentlyPlayingData = nil;
        [self _stopPlaybackMonitor];

        _lastRequestedText = nil;
        _lastStartedText = nil;
        _lastFinishedText = nil;
        _textCanceled = NO;
    }
    
    if (completion != nil) {
        completion(success);
    }

    // Delay setIdle to after calling the completion, so that if more audio was
    // immediately queued, we leave the session active. This happens when we do
    // the beep followed by tts. setIdle will see that audio is playing and do
    // nothing.
    if (setIdle) {
        [self _setIdle];
    }
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void) _tagEvent:(NSString*)event withProperties:(NSDictionary*)properties
{
    if (self.loggingDelegate) {
        NSString* eventString = [NSString stringWithFormat:@"%@: %@", event, [self _JSONStringWithPrettyPrint:YES fromDictionary:properties]];
        [self.loggingDelegate audioLogEvent:eventString];
    }
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (BOOL) _backgroundAudioPlaying
{
    AVAudioSession* session = [AVAudioSession sharedInstance];
    
    return session.secondaryAudioShouldBeSilencedHint;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (CGFloat) _volumeNumericSetting
{
    if (_volumeLevel == AudioVolumeLevelHigh) {
        return 1.0;
    } else if (_volumeLevel == AudioVolumeLevelMed) {
        return 0.8;
    } else if (_volumeLevel == AudioVolumeLevelLow) {
        return 0.6;
    } else {
        return 0.0;
    }
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void) _updateAudioRouteWithAudioRouteName:(NSString*)systemAudioRouteName
{
    // Set our version of the text
    NSString* audioRouteName = [self _friendlyAudioRouteNameForAudioRoute:systemAudioRouteName];
    
    // Did the audio route change?
    if (_audioRouteName == audioRouteName || [audioRouteName compare:_audioRouteName] == NSOrderedSame) {
        return;
    }
    
    _audioRouteName = audioRouteName;
    
    // update type
    _audioRouteType = [self _audioRouteTypeForAudioRoute:systemAudioRouteName];
    
    if (_readyToPlay) {
        // Only update the expected audio route if the audio system is set up for active playback.
        // This is because the audio route may change during playback based on the category and options
        // we've set up.
        _expectedAudioRouteName = _audioRouteName;
        _expectedAudioRouteType = _audioRouteType;
    }
    
    // send event
    [[NSNotificationCenter defaultCenter] postNotificationName:AudioManagerAudioRouteChanged
                                                        object:self];
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (NSString*) _friendlyAudioRouteNameForAudioRoute:(NSString*)systemAudioRouteName
{
    if ([systemAudioRouteName compare:AVAudioSessionPortLineOut] == NSOrderedSame) {
        return @"AUX";
    } else if ([systemAudioRouteName compare:AVAudioSessionPortHeadphones] == NSOrderedSame) {
        return @"AUX";
    } else if ([systemAudioRouteName compare:AVAudioSessionPortBluetoothA2DP] == NSOrderedSame) {
        return @"Bluetooth";
    } else if ([systemAudioRouteName compare:AVAudioSessionPortBluetoothHFP] == NSOrderedSame) {
        return @"Bluetooth";
    } else if ([systemAudioRouteName compare:AVAudioSessionPortUSBAudio] == NSOrderedSame) {
        return @"USB";
    } else if ([systemAudioRouteName compare:AVAudioSessionPortBluetoothA2DP] == NSOrderedSame) {
        return @"Bluetooth";
    } else {
        return systemAudioRouteName;
    }
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (AudioRouteType) _audioRouteTypeForAudioRoute:(NSString*)systemAudioRouteName
{
    if ([systemAudioRouteName compare:AVAudioSessionPortLineOut] == NSOrderedSame) {
        return AudioRouteTypeAUX;
    } else if ([systemAudioRouteName compare:AVAudioSessionPortHeadphones] == NSOrderedSame) {
        return AudioRouteTypeAUX;
    } else if ([systemAudioRouteName compare:AVAudioSessionPortBluetoothA2DP] == NSOrderedSame) {
        return AudioRouteTypeBluetooth;
    } else if ([systemAudioRouteName compare:AVAudioSessionPortBluetoothHFP] == NSOrderedSame) {
        return AudioRouteTypeBluetooth;
    } else if ([systemAudioRouteName compare:AVAudioSessionPortUSBAudio] == NSOrderedSame) {
        return AudioRouteTypeUSB;
    } else if ([systemAudioRouteName compare:AVAudioSessionPortBluetoothA2DP] == NSOrderedSame) {
        return AudioRouteTypeBluetooth;
    } else if ([systemAudioRouteName compare:AVAudioSessionPortBuiltInSpeaker] == NSOrderedSame) {
        return AudioRouteTypeSpeaker;
    } else {
        return AudioRouteTypeOther;
    }
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void) _tagAudioRouteInfoWithReason:(NSString*)reason
{

}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
-(NSString*) _JSONStringWithPrettyPrint:(BOOL) prettyPrint fromDictionary:(NSDictionary*)dictionary
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
                                                       options:(NSJSONWritingOptions) (prettyPrint ? NSJSONWritingPrettyPrinted : 0)
                                                         error:&error];
    
    if (! jsonData) {
        NSLog(@"jsonStringWithPrettyPrint: error: %@", error.localizedDescription);
        return @"{}";
    } else {
        return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
}


#pragma mark - AVAudioPlayer Delegate Methods
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    PlayAudioCompletion completion = _playerCompletionMap[@(player.hash)];
    [_playerCompletionMap removeObjectForKey:@(player.hash)];

    // Pull out completion for player
    [self _didFinishPlayingData:player success:flag completion:completion];
}


#pragma mark - AVSpeechSynthesizer Delegate Methods
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance
{
    PlayAudioCompletion completion = _utteranceCompletionMap[@(utterance.hash)];
    [_utteranceCompletionMap removeObjectForKey:@(utterance.hash)];

    _lastFinishedText = utterance.speechString;

    [self _didFinishPlayingData:utterance success:YES completion:completion];
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didCancelSpeechUtterance:(AVSpeechUtterance *)utterance
{
    _textCanceled = YES;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didStartSpeechUtterance:(AVSpeechUtterance *)utterance
{
    _lastStartedText = utterance.speechString;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didPauseSpeechUtterance:(AVSpeechUtterance *)utterance
{
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didContinueSpeechUtterance:(AVSpeechUtterance *)utterance
{
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (NSString *)volumeLevelString
{
    NSDictionary *volumeToString = @{@(AudioVolumeLevelMute): @"Mute",
                                     @(AudioVolumeLevelLow): @"Low Volume",
                                     @(AudioVolumeLevelMed): @"Normal Volume",
                                     @(AudioVolumeLevelHigh): @"High Volume"};
    
    return [volumeToString objectForKey:@(self.volumeLevel)];
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (NSDictionary*)_getInfoForAudioSource:(AVAudioSessionDataSourceDescription*)source selectedSource:(AVAudioSessionDataSourceDescription*)selectedSource
{
    if (!source) return @{};

    NSMutableDictionary* info = [NSMutableDictionary dictionaryWithDictionary:@{@"selected": @(selectedSource == source)}];

    if (source.dataSourceName)
        info[@"name"] = source.dataSourceName;
    if (source.dataSourceID)
        info[@"id"] = source.dataSourceID;
    if (source.location)
        info[@"location"] = source.location;
    if (source.orientation)
        info[@"orientation"] = source.orientation;

    return info;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (NSDictionary*)_getInfoForAudioPort:(AVAudioSessionPortDescription*)port
{
    if (!port) return @{};

    NSMutableDictionary* info = [NSMutableDictionary new];
    if (port.portName)
        info[@"name"] = port.portName;
    if (port.portType)
        info[@"type"] = port.portType;
    if (port.UID)
        info[@"uid"] = port.UID;

    NSMutableArray* dataSources = [NSMutableArray arrayWithCapacity:port.dataSources.count];
    for (AVAudioSessionDataSourceDescription* source in port.dataSources) {
        [dataSources addObject:[self _getInfoForAudioSource:source selectedSource:port.selectedDataSource]];
    }

    info[@"sources"] = dataSources;
    info[@"channels"] = @(port.channels.count);

    return info;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (NSDictionary*)_getInfoForAudioRoute:(AVAudioSessionRouteDescription*)route
{
    if (!route) {
        return @{};
    }

    NSMutableArray* inputs = [NSMutableArray arrayWithCapacity:route.inputs.count];
    for (AVAudioSessionPortDescription* desc in route.inputs) {
        [inputs addObject:[self _getInfoForAudioPort:desc]];
    }

    NSMutableArray* outputs = [NSMutableArray arrayWithCapacity:route.outputs.count];
    for (AVAudioSessionPortDescription* desc in route.outputs) {
        [outputs addObject:[self _getInfoForAudioPort:desc]];
    }

    return @{@"inputs": inputs, @"outputs": outputs};
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (BOOL) _currentOutputIsA2DP
{
    AVAudioSession* session = [AVAudioSession sharedInstance];
    if (session.currentRoute.outputs.count > 0) {
        NSString* portType = [session.currentRoute.outputs[0] portType];
        return [portType isEqualToString:AVAudioSessionPortBluetoothA2DP];
    }
    return NO;
}


#pragma mark - NSNotificationCenter callbacks
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)_audioSessionRouteChanged:(NSNotification *)notification
{
    NSDictionary* userInfo = [notification userInfo];
    AVAudioSessionRouteChangeReason reason;
    reason = [[userInfo objectForKey:AVAudioSessionRouteChangeReasonKey]
              unsignedIntegerValue];

    BOOL reasonNewAvailable = (reason == AVAudioSessionRouteChangeReasonNewDeviceAvailable);
    BOOL reasonOldUnavailable = (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable);
    if (!reasonNewAvailable && !reasonOldUnavailable) {
        return;
    }

    AVAudioSession* session = [AVAudioSession sharedInstance];
    AVAudioSessionRouteDescription* newRoute = session.currentRoute;

    // Note: this won't reflect inputs normally, because the default audio
    // category that we set doesn't permit recording.
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // Update the ivars and do tag the event on the main thread
        if (newRoute.outputs.count > 0) {
            [self _updateAudioRouteWithAudioRouteName:[session.currentRoute.outputs[0] portType]];
        }
        
        [self _checkExpectedAudioRoute];
        
        NSString* category;
        AVAudioSessionCategoryOptions options;
        NSTimeInterval expectedOutputLatency;
        [self _determineAudioSystemCategory:&category options:&options expectedOutputLatency:&expectedOutputLatency];
        _expectedOutputLatency = expectedOutputLatency;
    });
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)_silenceSecondaryAudioHintChanged:(NSNotification *)notification
{
    [self _checkExpectedAudioRoute];
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)_appWillResignActive:(NSNotification *)notification
{
    if (self.isRecording) {
        [self stopRecording];
    }
    
    self.foreground = NO;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)_appDidEnterBackground:(NSNotification *)notification
{
    self.foreground = NO;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)_appWillEnterForeground:(NSNotification *)notification
{
    self.foreground = YES;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)_appDidBecomeActive:(NSNotification *)notification
{
    [self appResumed];
    self.foreground = YES;
}

@end
