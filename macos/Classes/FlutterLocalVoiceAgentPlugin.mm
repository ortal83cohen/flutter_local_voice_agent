#import "FlutterLocalVoiceAgentPlugin.h"
#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>
#include <CoreAudio/CoreAudio.h>
#include <atomic>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <thread>
#include "flva.h"
#include "mic_permission.h"

@interface FlutterLocalVoiceAgentPlugin ()
- (void)defaultDeviceChanged;
@end

static OSStatus FlvaDefaultDeviceListener(AudioObjectID, UInt32, const AudioObjectPropertyAddress *, void *client) {
  FlutterLocalVoiceAgentPlugin *owner=(__bridge FlutterLocalVoiceAgentPlugin *)client;
  [owner defaultDeviceChanged];
  return noErr;
}

static int FlvaDefaultInputRate(void) {
  AudioDeviceID device=kAudioObjectUnknown;
  UInt32 size=sizeof(device);
  AudioObjectPropertyAddress address={kAudioHardwarePropertyDefaultInputDevice,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
  if(AudioObjectGetPropertyData(kAudioObjectSystemObject,&address,0,NULL,&size,&device)!=noErr || device==kAudioObjectUnknown)return 48000;
  Float64 rate=0;
  size=sizeof(rate);
  AudioObjectPropertyAddress rateAddress={kAudioDevicePropertyNominalSampleRate,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
  if(AudioObjectGetPropertyData(device,&rateAddress,0,NULL,&size,&rate)!=noErr)return 48000;
  int hz=(int)llround(rate);
  if(hz<8000 || hz>192000)return 48000;
  return hz;
}

static void FlvaMixMono(const AVAudioPCMBuffer *buffer,float *mono,int frames) {
  const int channels=(int)buffer.format.channelCount;
  float *const *data=buffer.floatChannelData;
  if(!data || channels<=1) {
    if(data && data[0])memcpy(mono,data[0],(size_t)frames*sizeof(float));
    else memset(mono,0,(size_t)frames*sizeof(float));
    return;
  }
  for(int i=0;i<frames;++i) {
    float sum=0;
    for(int ch=0;ch<channels;++ch)sum+=data[ch][i];
    mono[i]=sum/(float)channels;
  }
}

static float FlvaRms(const float *samples,int frames) {
  if(!samples || frames<=0)return 0;
  double sum=0;
  for(int i=0;i<frames;++i)sum+=(double)samples[i]*samples[i];
  return (float)sqrt(sum/(double)frames);
}

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
  BOOL _deviceListeners;
  int _inputRate;
  NSString *_suspension;
}
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel=[FlutterMethodChannel methodChannelWithName:@"flutter_local_voice_agent" binaryMessenger:registrar.messenger];
  FlutterLocalVoiceAgentPlugin *instance=[[self alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}
- (instancetype)init {
  if((self=[super init])) {
    _control=dispatch_queue_create("dev.localvoice.control",DISPATCH_QUEUE_SERIAL);
    _acceptAudio=false;_callbacks=0;_pending=0;
    NSNotificationCenter *n=NSNotificationCenter.defaultCenter;
    [n addObserver:self selector:@selector(deactivated:) name:NSApplicationWillResignActiveNotification object:nil];
    [n addObserver:self selector:@selector(engineConfigurationChanged:) name:AVAudioEngineConfigurationChangeNotification object:nil];
    [self addDefaultDeviceListeners];
  }return self;
}
- (void)addDefaultDeviceListeners {
  if(_deviceListeners)return;
  AudioObjectPropertyAddress input={kAudioHardwarePropertyDefaultInputDevice,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
  AudioObjectPropertyAddress output={kAudioHardwarePropertyDefaultOutputDevice,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
  AudioObjectAddPropertyListener(kAudioObjectSystemObject,&input,FlvaDefaultDeviceListener,(__bridge void *)self);
  AudioObjectAddPropertyListener(kAudioObjectSystemObject,&output,FlvaDefaultDeviceListener,(__bridge void *)self);
  _deviceListeners=YES;
}
- (void)removeDefaultDeviceListeners {
  if(!_deviceListeners)return;
  AudioObjectPropertyAddress input={kAudioHardwarePropertyDefaultInputDevice,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
  AudioObjectPropertyAddress output={kAudioHardwarePropertyDefaultOutputDevice,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
  AudioObjectRemovePropertyListener(kAudioObjectSystemObject,&input,FlvaDefaultDeviceListener,(__bridge void *)self);
  AudioObjectRemovePropertyListener(kAudioObjectSystemObject,&output,FlvaDefaultDeviceListener,(__bridge void *)self);
  _deviceListeners=NO;
}
- (void)complete:(FlutterResult)result value:(id)value { dispatch_async(dispatch_get_main_queue(),^{result(value);}); }
- (FlutterError *)error:(NSString *)code message:(NSString *)message { return [FlutterError errorWithCode:code message:message details:nil]; }
- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if([call.method isEqualToString:@"start"]) {
    if(!NSApp.isActive){result([self error:@"invalidState" message:@"Start requires a foreground application"]);return;}
    // Denied or restricted microphone access must not reach startAudio.
    // That keeps capture closed: no AVAudioEngine start and no input tap.
    AVAuthorizationStatus status=[AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    const int decision=flva_mic_start_decision((int)status);
    if(decision==FLVA_MIC_ASK){
      [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted){
        dispatch_async(dispatch_get_main_queue(),^{
          if(granted)[self handleMethodCall:call result:result];
          else {
            NSLog(@"FLVA start refused permissionDenied granted=0");
            result([self error:@"permissionDenied" message:@"Microphone permission denied"]);
          }
        });
      }];
      return;
    }
    if(decision==FLVA_MIC_DENY){
      NSLog(@"FLVA start refused permissionDenied status=%ld",(long)status);
      result([self error:@"permissionDenied" message:@"Microphone permission denied"]);
      return;
    }
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
    _inputRate=FlvaDefaultInputRate();
    NSDictionary *p=args[@"paths"];
    if(![p isKindOfClass:NSDictionary.class])return [self error:@"invalidAsset" message:@"Missing model paths"];
    FlvaConfig c{};
    c.vad=[p[@"vad"] UTF8String];c.encoder=[p[@"encoder"] UTF8String];c.decoder=[p[@"decoder"] UTF8String];c.joiner=[p[@"joiner"] UTF8String];c.asr_tokens=[p[@"asrTokens"] UTF8String];
    c.tts_model=[p[@"ttsModel"] UTF8String];c.tts_tokens=[p[@"ttsTokens"] UTF8String];c.tts_lexicon=[p[@"ttsLexicon"] UTF8String];c.llm_model=[p[@"llmModel"] UTF8String];c.input_rate=_inputRate;
    c.speaker_id=[args[@"speakerId"] intValue];
    char message[2048]{};_session=flva_create(&c,message,sizeof(message));
    if(!_session){
      NSString *nativeMessage=[NSString stringWithUTF8String:message];
      if([nativeMessage isEqualToString:@"unsupportedProfile"])return [self error:@"unsupportedProfile" message:nativeMessage];
      return [self error:@"inferenceFailed" message:nativeMessage];
    }
    NSLog(@"FLVA create inputRate=%d outputRate=%d speakerId=%d",_inputRate,flva_output_rate(_session),c.speaker_id);
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
  _engine=[[AVAudioEngine alloc] init];
  AVAudioInputNode *input=_engine.inputNode;
  AVAudioFormat *format=[input outputFormatForBus:0];
  if(!format || format.channelCount<1 || format.sampleRate<8000){[self stopAudio];return [self error:@"audioUnavailable" message:@"Audio input is unavailable"];}
  if((int)llround(format.sampleRate)!=_inputRate){[self stopAudio];return [self error:@"audioUnavailable" message:@"Audio route format changed; recreate the agent"];}
  AVAudioFormat *tapFormat=[[AVAudioFormat alloc] initStandardFormatWithSampleRate:format.sampleRate channels:1];
  if(!tapFormat){[self stopAudio];return [self error:@"audioUnavailable" message:@"Mono float32 tap format is unavailable"];}
  if(!flva_start(_session)){[self stopAudio];return [self error:@"invalidState" message:@"Native start failed"];}
  _acceptAudio=true;
  __weak FlutterLocalVoiceAgentPlugin *weakSelf=self;
  [input installTapOnBus:0 bufferSize:512 format:tapFormat block:^(AVAudioPCMBuffer *buffer,AVAudioTime *when){
    FlutterLocalVoiceAgentPlugin *owner=weakSelf;if(!owner)return;
    owner->_callbacks.fetch_add(1);
    const int frames=(int)buffer.frameLength;
    if(owner->_acceptAudio.load() && frames>0) {
      float stack[512];
      float *mono=frames<=512?stack:(float *)malloc((size_t)frames*sizeof(float));
      if(mono){
        if(buffer.floatChannelData && buffer.format.channelCount==1)memcpy(mono,buffer.floatChannelData[0],(size_t)frames*sizeof(float));
        else FlvaMixMono(buffer,mono,frames);
        int pushed=flva_push(owner->_session,mono,frames);
        int count=owner->_callbacks.load();
        if(pushed==0 || (count%100)==1)NSLog(@"FLVA capture callbacks=%d frames=%d rms=%.4f push=%d",count,frames,FlvaRms(mono,frames),pushed);
        if(mono!=stack)free(mono);
      }
    }
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
  NSError *error=nil;
  if(![_engine startAndReturnError:&error]){[self stopAudio];flva_stop(_session);return [self error:@"audioUnavailable" message:error.localizedDescription];}
  NSLog(@"FLVA startAudio inputRate=%d channels=%u outputRate=%d",_inputRate,(unsigned)format.channelCount,flva_output_rate(_session));
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
}
- (void)suspend:(NSString *)reason {
  _acceptAudio=false;
  // One atomic latch prevents a burst of OS notifications from growing the queue.
  if(_pending.fetch_add(1)>=32){_pending.fetch_sub(1);return;}
  dispatch_async(_control,^{[self stopAudio];if(self->_session)flva_stop(self->_session);self->_suspension=reason;self->_pending.fetch_sub(1);});
}
- (void)deactivated:(NSNotification *)n {
  if(_acceptAudio.load() || _running)[self suspend:@"audioUnavailable"];
}
- (void)engineConfigurationChanged:(NSNotification *)n {
  if(_acceptAudio.load() || _running)[self suspend:@"routeChanged"];
}
- (void)defaultDeviceChanged {
  if(_acceptAudio.load() || _running)[self suspend:@"routeChanged"];
}
- (void)detachFromEngineForRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  [NSNotificationCenter.defaultCenter removeObserver:self];
  [self removeDefaultDeviceListeners];
  _acceptAudio=false;
  dispatch_async(_control,^{[self stopAudio];if(self->_session){flva_destroy(self->_session);self->_session=nullptr;}});
}
@end
