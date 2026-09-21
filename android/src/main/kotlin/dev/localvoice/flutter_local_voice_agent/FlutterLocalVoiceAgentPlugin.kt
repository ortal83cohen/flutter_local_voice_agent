package dev.localvoice.flutter_local_voice_agent

import android.Manifest
import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.pm.PackageManager
import android.media.*
import android.os.*
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

/** Foreground owner; control work and joins never run on the platform thread. */
class FlutterLocalVoiceAgentPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    ActivityAware, PluginRegistry.RequestPermissionsResultListener, Application.ActivityLifecycleCallbacks {
    companion object { init { System.loadLibrary("flva") }; private const val PERMISSION = 4819 }
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private val main = Handler(Looper.getMainLooper())
    private val control = ThreadPoolExecutor(1, 1, 0, TimeUnit.SECONDS, ArrayBlockingQueue(32))
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var handle = 0L
    @Volatile private var active = false
    private var recorder: AudioRecord? = null
    private var player: AudioTrack? = null
    private var captureThread: Thread? = null
    private var renderThread: Thread? = null
    private var focus: AudioFocusRequest? = null
    private var suspended: String? = null
    private var capturedFrames = 0L
    private var pushedFrames = 0L
    private var captureReads = 0L
    private var lastCaptureLog = 0L
    @Volatile private var foreground = false
    private val audio get() = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val thermal = if (Build.VERSION.SDK_INT >= 29) PowerManager.OnThermalStatusChangedListener {
        if (it >= PowerManager.THERMAL_STATUS_SEVERE) suspendAudio("thermalPressure")
    } else null
    private val routes = object : AudioDeviceCallback() {
        override fun onAudioDevicesRemoved(removed: Array<out AudioDeviceInfo>) {
            if (active && removed.isNotEmpty()) suspendAudio("routeChanged")
        }
    }
    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        context=b.applicationContext
        channel=MethodChannel(b.binaryMessenger,"flutter_local_voice_agent");channel.setMethodCallHandler(this)
        (context as Application).registerActivityLifecycleCallbacks(this)
        audio.registerAudioDeviceCallback(routes, main)
        if(Build.VERSION.SDK_INT>=29 && thermal!=null) (context.getSystemService(Context.POWER_SERVICE) as PowerManager).addThermalStatusListener(thermal)
    }
    private fun submit(result: MethodChannel.Result?, block: () -> Any?) {
        try { control.execute {
            try { val value=block(); main.post { result?.success(value) } }
            catch(e: Exception) { main.post { result?.error(when { e is SecurityException -> "permissionDenied"; e.message == "unsupportedProfile" -> "unsupportedProfile"; else -> "audioUnavailable" },e.message,null) } }
        } } catch(e: java.util.concurrent.RejectedExecutionException) { result?.error("capacityExceeded","Control queue is full",null) }
    }
    private fun log(message: String) = Log.i("FLVA", message)
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if(call.method=="start") {
            if(!foreground || activity==null) {result.error("invalidState","A foreground Activity is required",null);return}
            if(context.checkSelfPermission(Manifest.permission.RECORD_AUDIO)!=PackageManager.PERMISSION_GRANTED) {
                if(pendingPermission!=null){result.error("invalidState","Permission request already pending",null);return}
                pendingPermission=result;activity!!.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO),PERMISSION);return
            }
        }
        submit(result) {
            when(call.method) {
                "create" -> {
                    log("create requested")
                    check(handle==0L){"Dispose the existing session first"}
                    require(call.argument<String>("mode") != "fullDuplexRequired"){"Full duplex is not qualified"}
                    val p=call.argument<Map<String,String>>("paths") ?: error("Missing model paths")
                    val keys=arrayOf("vad","encoder","decoder","joiner","asrTokens","ttsModel","ttsTokens","ttsLexicon","llmModel")
                    val speakerId=(call.argument<Number>("speakerId") ?: 0).toInt()
                    handle=nativeCreate(keys.map {p[it] ?: ""}.toTypedArray(), speakerId)
                    mapOf("outputRate" to nativeRate(handle))
                }
                "start" -> { check(handle!=0L); log("start requested handle=$handle"); startAudio(); null }
                "stop" -> { stopAudio(); if(handle!=0L)nativeStop(handle); null }
                "interrupt" -> {
                    check(handle!=0L); val g=nativeInterrupt(handle)
                    player?.pause();player?.flush();if(active)player?.play();g
                }
                "reply" -> { check(handle!=0L); check(nativeReply(handle,call.argument<Number>("generation")!!.toLong(),call.argument<String>("text")!!)==1){"Stale or oversized reply"};null }
                "poll" -> {
                    val events=mutableListOf<Map<String,Any>>()
                    suspended?.let { events.add(mapOf("kind" to "suspended","code" to it));suspended=null }
                    if(handle!=0L) for(i in 0 until 31) {
                        val e=nativePoll(handle) ?: break
                        events.add(mapOf("sequence" to e[0].toLong(),"generation" to e[1].toLong(),"kind" to e[2],"activity" to e[3],"code" to e[4],"text" to e[5]))
                    }; if (events.isNotEmpty()) log("poll events=${events.size} kinds=${events.joinToString(",") { it["kind"].toString() }}"); events
                }
                "dispose" -> { stopAudio();if(handle!=0L){nativeDestroy(handle);handle=0};null }
                "setSpeakerId" -> {
                    check(handle!=0L)
                    val speakerId=(call.argument<Number>("speakerId") ?: 0).toInt()
                    check(nativeSetSpeakerId(handle, speakerId)==1){"unsupportedProfile"}
                    null
                }
                else -> throw IllegalArgumentException("Unknown command")
            }
        }
    }
    @Suppress("MissingPermission")
    private fun startAudio() {
        if(active)return
        check(foreground){"Activity is not foreground"}
        val attrs=AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()
        focus=AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            .setAudioAttributes(attrs).setOnAudioFocusChangeListener({ if(it<0)suspendAudio("audioFocusLost") },main).build()
        check(audio.requestAudioFocus(focus!!)==AudioManager.AUDIOFOCUS_REQUEST_GRANTED){"Audio focus denied"}
        try {
            val min=AudioRecord.getMinBufferSize(16000,AudioFormat.CHANNEL_IN_MONO,AudioFormat.ENCODING_PCM_FLOAT)
            check(min>0){"16 kHz float capture unavailable"}
            recorder=AudioRecord.Builder().setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION)
                .setAudioFormat(AudioFormat.Builder().setSampleRate(16000).setChannelMask(AudioFormat.CHANNEL_IN_MONO).setEncoding(AudioFormat.ENCODING_PCM_FLOAT).build())
                .setBufferSizeInBytes(maxOf(min,4096)).build()
            val rate=nativeRate(handle)
            val outMin=AudioTrack.getMinBufferSize(rate,AudioFormat.CHANNEL_OUT_MONO,AudioFormat.ENCODING_PCM_FLOAT)
            check(outMin>0){"Voice output rate unavailable"}
            player=AudioTrack.Builder().setAudioAttributes(attrs).setAudioFormat(AudioFormat.Builder().setSampleRate(rate).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).setEncoding(AudioFormat.ENCODING_PCM_FLOAT).build())
                .setBufferSizeInBytes(maxOf(outMin,4096)).setTransferMode(AudioTrack.MODE_STREAM).build()
            check(recorder!!.state==AudioRecord.STATE_INITIALIZED && player!!.state==AudioTrack.STATE_INITIALIZED)
            log("audio initialized input=16000Hz mono float32 output=${rate}Hz buffer=${recorder!!.bufferSizeInFrames}")
            check(nativeStart(handle)==1){"Native start failed"}
            active=true;recorder!!.startRecording();player!!.play()
            val rec=recorder!!;val out=player!!;val h=handle
            captureThread=Thread({
                val pcm=FloatArray(512);val bytes=ByteBuffer.allocateDirect(2048).order(ByteOrder.nativeOrder());val floats=bytes.asFloatBuffer()
                while(active) {
                    val n=try { rec.read(pcm,0,pcm.size,AudioRecord.READ_BLOCKING) } catch(_:Exception) { if(active)suspendAudio("permissionOrCaptureLost");break }
                    if(n<=0){if(active)suspendAudio("captureFailed");break}
                    var peak=0f; var sum=0.0; var finite=0; var nonFinite=0
                    for(i in 0 until n) {
                        val sample=pcm[i]
                        if(sample.isFinite()) {
                            finite++
                            val v=kotlin.math.abs(sample)
                            if(v>peak) peak=v
                            sum += v.toDouble()
                        } else {
                            nonFinite++
                        }
                    }
                    capturedFrames += n; captureReads++
                    floats.position(0);floats.put(pcm,0,n)
                    val pushed=nativePush(h,bytes,n); if(pushed==1) pushedFrames += n
                    val now=SystemClock.elapsedRealtime()
                    if(captureReads==1L || now-lastCaptureLog>=1000L) {
                        lastCaptureLog=now
                        val mean=if(finite>0) sum/finite else 0.0
                        log("capture reads=$captureReads frames=$capturedFrames pushed=$pushedFrames lastFrames=$n finite=$finite nonFinite=$nonFinite meanAbs=$mean peak=$peak pushResult=$pushed")
                    }
                }
            },"flva-capture").also {it.start()}
            renderThread=Thread({
                val pcm=FloatArray(512);val bytes=ByteBuffer.allocateDirect(2048).order(ByteOrder.nativeOrder());val floats=bytes.asFloatBuffer()
                while(active) {
                    nativeRender(h,bytes,pcm.size);floats.position(0);floats.get(pcm)
                    var offset=0
                    while(active && offset<pcm.size){val n=try{out.write(pcm,offset,pcm.size-offset,AudioTrack.WRITE_BLOCKING)}catch(_:Exception){if(active)suspendAudio("playbackFailed");return@Thread};if(n<=0){if(active)suspendAudio("playbackFailed");return@Thread};offset+=n}
                }
            },"flva-render").also {it.start()}
        } catch(e:Exception){stopAudio();if(handle!=0L)nativeStop(handle);throw e}
    }
    private fun stopAudio() {
        log("stopAudio active=$active reads=$captureReads captured=$capturedFrames pushed=$pushedFrames")
        active=false
        try{recorder?.stop()}catch(_:Exception){}
        try{player?.pause();player?.flush()}catch(_:Exception){}
        captureThread?.join();renderThread?.join();captureThread=null;renderThread=null
        recorder?.release();player?.release();recorder=null;player=null
        focus?.let{audio.abandonAudioFocusRequest(it)};focus=null
    }
    private fun suspendAudio(reason:String) {
        active=false
        submit(null){if(handle!=0L)nativeInterrupt(handle);stopAudio();if(handle!=0L)nativeStop(handle);suspended=reason;null}
    }
    override fun onRequestPermissionsResult(code:Int,permissions:Array<out String>,grants:IntArray):Boolean {
        if(code!=PERMISSION)return false
        val r=pendingPermission;pendingPermission=null
        if(grants.isNotEmpty()&&grants[0]==PackageManager.PERMISSION_GRANTED)submit(r){check(handle!=0L);startAudio();null}
        else r?.error("permissionDenied","Microphone permission denied",null)
        return true
    }
    override fun onAttachedToActivity(b:ActivityPluginBinding){binding=b;activity=b.activity;foreground=true;b.addRequestPermissionsResultListener(this)}
    override fun onDetachedFromActivityForConfigChanges()=onDetachedFromActivity()
    override fun onReattachedToActivityForConfigChanges(b:ActivityPluginBinding)=onAttachedToActivity(b)
    override fun onDetachedFromActivity(){foreground=false;binding?.removeRequestPermissionsResultListener(this);binding=null;activity=null;pendingPermission?.error("invalidState","Activity detached",null);pendingPermission=null;suspendAudio("activityDetached")}
    override fun onDetachedFromEngine(b:FlutterPlugin.FlutterPluginBinding){channel.setMethodCallHandler(null);audio.unregisterAudioDeviceCallback(routes);(context as Application).unregisterActivityLifecycleCallbacks(this);if(Build.VERSION.SDK_INT>=29&&thermal!=null)(context.getSystemService(Context.POWER_SERVICE) as PowerManager).removeThermalStatusListener(thermal);submit(null){stopAudio();if(handle!=0L){nativeDestroy(handle);handle=0};null};control.shutdown()}
    override fun onActivityPaused(a:Activity){if(a===activity){foreground=false;suspendAudio("background")}}
    override fun onActivityResumed(a:Activity){if(a===activity)foreground=true}
    override fun onActivityCreated(a:Activity,b:Bundle?){}
    override fun onActivityStarted(a:Activity){}
    override fun onActivityStopped(a:Activity){}
    override fun onActivitySaveInstanceState(a:Activity,b:Bundle){}
    override fun onActivityDestroyed(a:Activity){}
    private external fun nativeCreate(paths:Array<String>, speakerId:Int):Long
    private external fun nativeSetSpeakerId(h:Long, speakerId:Int):Int
    private external fun nativeRate(h:Long):Int
    private external fun nativeStart(h:Long):Int
    private external fun nativeStop(h:Long)
    private external fun nativeDestroy(h:Long)
    private external fun nativeInterrupt(h:Long):Long
    private external fun nativePush(h:Long,b:ByteBuffer,n:Int):Int
    private external fun nativeRender(h:Long,b:ByteBuffer,n:Int)
    private external fun nativeReply(h:Long,g:Long,text:String):Int
    private external fun nativePoll(h:Long):Array<String>?
}
