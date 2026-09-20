#include <jni.h>
#include <string>
#include <vector>
#include <cstring>
#include "flva.h"
#include <android/log.h>
#define FLVA_LOG(...) __android_log_print(ANDROID_LOG_INFO, "FLVA", __VA_ARGS__)
static std::string utf8(JNIEnv *e, jstring s) {
  auto cls=e->FindClass("java/lang/String");
  auto encoding=e->NewStringUTF("UTF-8");
  auto bytes=static_cast<jbyteArray>(e->CallObjectMethod(s,e->GetMethodID(cls,"getBytes","(Ljava/lang/String;)[B"),encoding));
  std::string value(e->GetArrayLength(bytes), '\0');
  e->GetByteArrayRegion(bytes,0,value.size(),reinterpret_cast<jbyte*>(value.data()));
  e->DeleteLocalRef(bytes);e->DeleteLocalRef(encoding);e->DeleteLocalRef(cls);return value;
}
static jstring java_string(JNIEnv *e,const char *p) {
  auto cls=e->FindClass("java/lang/String");auto bytes=e->NewByteArray(std::strlen(p));
  e->SetByteArrayRegion(bytes,0,std::strlen(p),reinterpret_cast<const jbyte*>(p));
  auto enc=e->NewStringUTF("UTF-8");
  auto result=static_cast<jstring>(e->NewObject(cls,e->GetMethodID(cls,"<init>","([BLjava/lang/String;)V"),bytes,enc));
  e->DeleteLocalRef(bytes);e->DeleteLocalRef(enc);e->DeleteLocalRef(cls);return result;
}
static FlvaSession *session(jlong h) { return reinterpret_cast<FlvaSession *>(h); }
extern "C" JNIEXPORT jlong JNICALL
Java_dev_localvoice_flutter_1local_1voice_1agent_FlutterLocalVoiceAgentPlugin_nativeCreate(JNIEnv *e, jobject, jobjectArray a) {
  std::vector<std::string> v;
  for (int i=0;i<9;++i) {
    auto s=static_cast<jstring>(e->GetObjectArrayElement(a,i));
    v.emplace_back(utf8(e,s)); e->DeleteLocalRef(s);
  }
  FlvaConfig c{v[0].c_str(),v[1].c_str(),v[2].c_str(),v[3].c_str(),v[4].c_str(),v[5].c_str(),v[6].c_str(),v[7].c_str(),v[8].c_str(),16000};
  char error[2048]{}; auto *s=flva_create(&c,error,sizeof(error));
  if (!s) e->ThrowNew(e->FindClass("java/lang/IllegalStateException"),error);
  return reinterpret_cast<jlong>(s);
}
extern "C" JNIEXPORT jint JNICALL
Java_dev_localvoice_flutter_1local_1voice_1agent_FlutterLocalVoiceAgentPlugin_nativeRate(JNIEnv *,jobject,jlong h){return flva_output_rate(session(h));}
extern "C" JNIEXPORT jint JNICALL
Java_dev_localvoice_flutter_1local_1voice_1agent_FlutterLocalVoiceAgentPlugin_nativeStart(JNIEnv *,jobject,jlong h){return flva_start(session(h));}
extern "C" JNIEXPORT void JNICALL
Java_dev_localvoice_flutter_1local_1voice_1agent_FlutterLocalVoiceAgentPlugin_nativeStop(JNIEnv *,jobject,jlong h){flva_stop(session(h));}
extern "C" JNIEXPORT void JNICALL
Java_dev_localvoice_flutter_1local_1voice_1agent_FlutterLocalVoiceAgentPlugin_nativeDestroy(JNIEnv *,jobject,jlong h){flva_destroy(session(h));}
extern "C" JNIEXPORT jlong JNICALL
Java_dev_localvoice_flutter_1local_1voice_1agent_FlutterLocalVoiceAgentPlugin_nativeInterrupt(JNIEnv *,jobject,jlong h){return flva_interrupt(session(h));}
extern "C" JNIEXPORT jint JNICALL
Java_dev_localvoice_flutter_1local_1voice_1agent_FlutterLocalVoiceAgentPlugin_nativePush(JNIEnv *e,jobject,jlong h,jobject b,jint n){
  auto *p=static_cast<float*>(e->GetDirectBufferAddress(b)); auto result=flva_push(session(h),p,n);
  if(!p || result==0) FLVA_LOG("nativePush rejected ptr=%p frames=%d result=%d",p,n,result);
  return result;
}
extern "C" JNIEXPORT void JNICALL
Java_dev_localvoice_flutter_1local_1voice_1agent_FlutterLocalVoiceAgentPlugin_nativeRender(JNIEnv *e,jobject,jlong h,jobject b,jint n){flva_render(session(h),static_cast<float*>(e->GetDirectBufferAddress(b)),n);}
extern "C" JNIEXPORT jint JNICALL
Java_dev_localvoice_flutter_1local_1voice_1agent_FlutterLocalVoiceAgentPlugin_nativeReply(JNIEnv *e,jobject,jlong h,jlong g,jstring s){
  auto p=utf8(e,s);return flva_reply(session(h),g,p.c_str());
}
extern "C" JNIEXPORT jobjectArray JNICALL
Java_dev_localvoice_flutter_1local_1voice_1agent_FlutterLocalVoiceAgentPlugin_nativePoll(JNIEnv *e,jobject,jlong h){
  FlvaEvent v{};if(!flva_poll(session(h),&v))return nullptr;
  auto a=e->NewObjectArray(6,e->FindClass("java/lang/String"),nullptr);
  std::string seq=std::to_string(v.sequence),g=std::to_string(v.generation);
  const char *values[]={seq.c_str(),g.c_str(),v.kind,v.activity,v.code,v.text};
  for(int i=0;i<6;++i){auto s=java_string(e,values[i]);e->SetObjectArrayElement(a,i,s);e->DeleteLocalRef(s);}return a;
}
