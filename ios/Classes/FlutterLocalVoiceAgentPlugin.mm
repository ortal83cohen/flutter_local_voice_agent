#import "FlutterLocalVoiceAgentPlugin.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#include <atomic>
#include <thread>
#include "flva.h"

@implementation FlutterLocalVoiceAgentPlugin {
  dispatch_queue_t _control;
  FlvaSession *_session;
  AVAudioEngine *_engine;
  AVAudioSourceNode *_source;
  std::atomic<bool> _acceptAudio;
  std::atomic<int> _callbacks;
  std::atomic<int> _pending;
  BOOL _tapInstalled;
  BOOL _running;
  int _inputRate;
  NSString *_suspension;
}
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel=[FlutterMethodChannel methodChannelWithName:@"flutter_local_voice_agent" binaryMessenger:registrar.messenger];
  FlutterLocalVoiceAgentPlugin *instance=[[self alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
  [registrar addApplicationDelegate:instance];
}
- (instancetype)init {
  if((self=[super init])) {
    _control=dispatch_queue_create("dev.localvoice.control",DISPATCH_QUEUE_SERIAL);
    _acceptAudio=false;_callbacks=0;_pending=0;
    NSNotificationCenter *n=NSNotificationCenter.defaultCenter;
    [n addObserver:self selector:@selector(interrupted:) name:AVAudioSessionInterruptionNotification object:nil];
    [n addObserver:self selector:@selector(routeChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
    [n addObserver:self selector:@selector(reset:) name:AVAudioSessionMediaServicesWereResetNotification object:nil];
    [n addObserver:self selector:@selector(thermal:) name:NSProcessInfoThermalStateDidChangeNotification object:nil];
    [n addObserver:self selector:@selector(background:) name:UIApplicationWillResignActiveNotification object:nil];
  }return self;
}
- (void)complete:(FlutterResult)result value:(id)value { dispatch_async(dispatch_get_main_queue(),^{result(value);}); }
- (FlutterError *)error:(NSString *)code message:(NSString *)message { return [FlutterError errorWithCode:code message:message details:nil]; }
- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if([call.method isEqualToString:@"start"]) {
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive){result([self error:@"invalidState" message:@"Start requires a foreground application"]);return;}
    AVAudioSessionRecordPermission p=AVAudioSession.sharedInstance.recordPermission;
    if(p==AVAudioSessionRecordPermissionUndetermined){
      [AVAudioSession.sharedInstance requestRecordPermission:^(BOOL granted){dispatch_async(dispatch_get_main_queue(),^{if(granted)[self handleMethodCall:call result:result];else result([self error:@"permissionDenied" message:@"Microphone permission denied"]);});}];return;
    }
    if(p!=AVAudioSessionRecordPermissionGranted){result([self error:@"permissionDenied" message:@"Microphone permission denied"]);return;}
  }
  if(_pending.fetch_add(1)>=32){_pending.fetch_sub(1);result([self error:@"capacityExceeded" message:@"Control queue is full"]);return;}
  dispatch_async(_control, ^{
    id value=nil;
    @try { value=[self execute:call]; }
    @catch(NSException *e){value=[self error:@"audioUnavailable" message:e.reason];}
    self->_pending.fetch_sub(1);
    [self complete:result value:value];
  });
}
- (id)execute:(FlutterMethodCall *)call {
  NSString *method=call.method;NSDictionary *args=[call.arguments isKindOfClass:NSDictionary.class]?call.arguments:@{};
  if([method isEqualToString:@"create"]){
    if(_session)return [self error:@"invalidState" message:@"Dispose the previous session first"];
    if([args[@"mode"] isEqual:@"fullDuplexRequired"])return [self error:@"unsupportedProfile" message:@"Full duplex is not qualified"];
    NSError *error=nil;AVAudioSession *audio=AVAudioSession.sharedInstance;
    if(![audio setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeDefault options:AVAudioSessionCategoryOptionDefaultToSpeaker error:&error] || ![audio setPreferredSampleRate:48000 error:&error] || ![audio setActive:YES error:&error])return [self error:@"audioUnavailable" message:error.localizedDescription];
    _inputRate=(int)audio.sampleRate;
    NSDictionary *p=args[@"paths"];
    if(![p isKindOfClass:NSDictionary.class])return [self error:@"invalidAsset" message:@"Missing model paths"];
    FlvaConfig c{};
    c.vad=[p[@"vad"] UTF8String];c.encoder=[p[@"encoder"] UTF8String];c.decoder=[p[@"decoder"] UTF8String];c.joiner=[p[@"joiner"] UTF8String];c.asr_tokens=[p[@"asrTokens"] UTF8String];
    c.tts_model=[p[@"ttsModel"] UTF8String];c.tts_tokens=[p[@"ttsTokens"] UTF8String];c.tts_lexicon=[p[@"ttsLexicon"] UTF8String];c.llm_model=[p[@"llmModel"] UTF8String];c.input_rate=_inputRate;
    c.speaker_id=[args[@"speakerId"] intValue];
    char message[2048]{};_session=flva_create(&c,message,sizeof(message));
    [audio setActive:NO error:nil];
    if(!_session){
      NSString *nativeMessage=[NSString stringWithUTF8String:message];
      if([nativeMessage isEqualToString:@"unsupportedProfile"])return [self error:@"unsupportedProfile" message:nativeMessage];
      return [self error:@"inferenceFailed" message:nativeMessage];
    }
    return @{@"outputRate":@(flva_output_rate(_session))};
  }
  if([method isEqualToString:@"dispose"]){[self stopAudio];if(_session){flva_destroy(_session);_session=nullptr;}return nil;}
  if([method isEqualToString:@"stop"]){[self stopAudio];if(_session)flva_stop(_session);return nil;}
  if(!_session)return [self error:@"invalidState" message:@"Create a session first"];
  if([method isEqualToString:@"start"])return [self startAudio];
  if([method isEqualToString:@"setSpeakerId"]){
    char message[2048]{};
    if(!flva_set_speaker_id(_session,[args[@"speakerId"] intValue],message,sizeof(message))){
      NSString *nativeMessage=[NSString stringWithUTF8String:message];
      if([nativeMessage isEqualToString:@"unsupportedProfile"])return [self error:@"unsupportedProfile" message:nativeMessage];
      return [self error:@"audioUnavailable" message:nativeMessage];
    }
    return nil;
  }
  if([method isEqualToString:@"interrupt"]){return @(flva_interrupt(_session));}
  if([method isEqualToString:@"reply"]){if(!flva_reply(_session,[args[@"generation"] unsignedLongLongValue],[args[@"text"] UTF8String]))return [self error:@"invalidState" message:@"Stale or oversized reply"];return nil;}
  if([method isEqualToString:@"poll"]){
    NSMutableArray *events=[NSMutableArray arrayWithCapacity:32];
    if(_suspension){[events addObject:@{@"kind":@"suspended",@"code":_suspension}];_suspension=nil;}
    FlvaEvent e{};
    for(int i=0;i<31 && flva_poll(_session,&e);++i){
      [events addObject:@{@"sequence":@(e.sequence),@"generation":@(e.generation),@"kind":[NSString stringWithUTF8String:e.kind]?:@"error",@"activity":[NSString stringWithUTF8String:e.activity]?:@"idle",@"code":[NSString stringWithUTF8String:e.code]?:@"inferenceFailed",@"text":[NSString stringWithUTF8String:e.text]?:@""}];
    }return events;
  }
  return FlutterMethodNotImplemented;
}
- (id)startAudio {
  if(_running)return nil;
  NSError *error=nil;AVAudioSession *audio=AVAudioSession.sharedInstance;
  if(![audio setActive:YES error:&error])return [self error:@"audioUnavailable" message:error.localizedDescription];
  _engine=[[AVAudioEngine alloc] init];AVAudioInputNode *input=_engine.inputNode;
  AVAudioFormat *format=[input outputFormatForBus:0];
  if(format.commonFormat!=AVAudioPCMFormatFloat32 || format.channelCount<1 || (int)format.sampleRate!=_inputRate){[self stopAudio];return [self error:@"audioUnavailable" message:@"Audio route format changed; recreate the agent"];} 
  if(!flva_start(_session)){[self stopAudio];return [self error:@"invalidState" message:@"Native start failed"];} 
  _acceptAudio=true;
  __weak FlutterLocalVoiceAgentPlugin *weakSelf=self;
  [input installTapOnBus:0 bufferSize:512 format:format block:^(AVAudioPCMBuffer *buffer,AVAudioTime *when){
    FlutterLocalVoiceAgentPlugin *owner=weakSelf;if(!owner)return;
    owner->_callbacks.fetch_add(1);
    if(owner->_acceptAudio.load() && buffer.floatChannelData)flva_push(owner->_session,buffer.floatChannelData[0],(int)buffer.frameLength);
    owner->_callbacks.fetch_sub(1);
  }];_tapInstalled=YES;
  AVAudioFormat *out=[[AVAudioFormat alloc] initStandardFormatWithSampleRate:flva_output_rate(_session) channels:1];
  _source=[[AVAudioSourceNode alloc] initWithFormat:out renderBlock:^OSStatus(BOOL *silence,const AudioTimeStamp *time,AVAudioFrameCount count,AudioBufferList *buffers){
    FlutterLocalVoiceAgentPlugin *owner=weakSelf;
    for(UInt32 i=0;i<buffers->mNumberBuffers;++i)memset(buffers->mBuffers[i].mData,0,buffers->mBuffers[i].mDataByteSize);
    if(!owner){*silence=YES;return noErr;}
    owner->_callbacks.fetch_add(1);
    if(owner->_acceptAudio.load()&&buffers->mNumberBuffers)flva_render(owner->_session,(float*)buffers->mBuffers[0].mData,(int)count);
    owner->_callbacks.fetch_sub(1);*silence=NO;return noErr;
  }];
  [_engine attachNode:_source];[_engine connect:_source to:_engine.mainMixerNode format:out];
  if(![_engine startAndReturnError:&error]){[self stopAudio];flva_stop(_session);return [self error:@"audioUnavailable" message:error.localizedDescription];}
  _running=YES;return nil;
}
- (void)stopAudio {
  _acceptAudio=false;
  if(_session)flva_interrupt(_session);
  [_engine stop];
  if(_tapInstalled){[_engine.inputNode removeTapOnBus:0];_tapInstalled=NO;}
  while(_callbacks.load()!=0)std::this_thread::yield();
  if(_source){[_engine disconnectNodeOutput:_source];[_engine detachNode:_source];}
  _source=nil;_engine=nil;_running=NO;
  [AVAudioSession.sharedInstance setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}
- (void)suspend:(NSString *)reason {
  _acceptAudio=false;
  // One atomic latch prevents a burst of OS notifications from growing the queue.
  if(_pending.fetch_add(1)>=32){_pending.fetch_sub(1);return;}
  dispatch_async(_control,^{[self stopAudio];if(self->_session)flva_stop(self->_session);self->_suspension=reason;self->_pending.fetch_sub(1);});
}
- (void)interrupted:(NSNotification *)n {if([n.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue]==AVAudioSessionInterruptionTypeBegan)[self suspend:@"interrupted"];}
- (void)routeChanged:(NSNotification *)n {if(_acceptAudio.load())[self suspend:@"routeChanged"];}
- (void)reset:(NSNotification *)n {[self suspend:@"mediaServicesReset"];}
- (void)thermal:(NSNotification *)n {if(NSProcessInfo.processInfo.thermalState>=NSProcessInfoThermalStateSerious)[self suspend:@"thermalPressure"];}
- (void)background:(NSNotification *)n {[self suspend:@"background"];}
- (void)detachFromEngineForRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  [NSNotificationCenter.defaultCenter removeObserver:self];_acceptAudio=false;
  dispatch_async(_control,^{[self stopAudio];if(self->_session){flva_destroy(self->_session);self->_session=nullptr;}});
}
@end
