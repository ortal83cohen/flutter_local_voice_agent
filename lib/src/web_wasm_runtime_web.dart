import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'models.dart';
import 'web_wasm_runtime.dart';

/// Production worker that loads official 1.13.8 wrappers off the UI thread.
WebWasmRuntime createPlatformWebWasmRuntime() => WorkerWebWasmRuntime();

/// Dedicated worker for Silero VAD, streaming Zipformer, and VITS.
final class WorkerWebWasmRuntime implements WebWasmRuntime {
  web.Worker? _worker;
  Completer<Map<String, Object?>>? _pending;
  final List<String> _transcripts = <String>[];

  @override
  Future<void> boot({
    required List<int> wasm,
    required String glueJs,
    required String asrJs,
    required String vadJs,
    required String ttsJs,
  }) async {
    await dispose();
    final blob = web.Blob(
      [_workerSource.toJS].toJS,
      web.BlobPropertyBag(type: 'application/javascript'),
    );
    final url = web.URL.createObjectURL(blob);
    final worker = web.Worker(url.toJS);
    worker.onmessage = _onMessage.toJS;
    _worker = worker;
    final wasmBytes = List<int>.from(wasm);
    await _request(<String, Object?>{
      'cmd': 'boot',
      'glue': glueJs,
      'asr': asrJs,
      'vad': vadJs,
      'tts': ttsJs,
      'wasm': wasmBytes,
    }, expect: 'booted');
  }

  @override
  Future<void> mount(Map<String, List<int>> files) async {
    await _request(<String, Object?>{
      'cmd': 'mount',
      'files': files.map((key, value) => MapEntry(key, List<int>.from(value))),
    }, expect: 'mounted');
  }

  @override
  Future<void> construct(Map<String, String> paths) async {
    await _request(<String, Object?>{
      'cmd': 'construct',
      'paths': paths,
    }, expect: 'ready');
  }

  @override
  Future<String?> acceptFrame(List<double> frame) async {
    final worker = _worker;
    if (worker == null) {
      return _transcripts.isEmpty ? null : _transcripts.removeAt(0);
    }
    final payload = JSObject()
      ..setProperty('cmd'.toJS, 'frame'.toJS)
      ..setProperty('samples'.toJS, Float32List.fromList(frame).toJS);
    worker.postMessage(payload);
    if (_transcripts.isEmpty) {
      return null;
    }
    return _transcripts.removeAt(0);
  }

  @override
  Future<List<double>> synthesize(String text, {int speakerId = 0}) async {
    final reply = await _request(<String, Object?>{
      'cmd': 'synthesize',
      'text': text,
      'sid': speakerId,
    }, expect: 'audio');
    final samples = reply['samples'];
    if (samples is List) {
      return samples.map((value) => (value as num).toDouble()).toList();
    }
    return const <double>[];
  }

  @override
  void invalidate() {
    _transcripts.clear();
    _failPending(
      const AgentFailure(
        AgentErrorCode.inferenceFailed,
        'The current web generation was invalidated.',
        fatal: false,
      ),
    );
    _worker?.postMessage(<String, Object?>{'cmd': 'invalidate'}.jsify());
  }

  @override
  Future<void> dispose() async {
    _transcripts.clear();
    invalidate();
    final worker = _worker;
    _worker = null;
    if (worker != null) {
      worker.postMessage(<String, Object?>{'cmd': 'dispose'}.jsify());
      worker.terminate();
    }
  }

  void _onMessage(web.MessageEvent event) {
    final raw = event.data.dartify();
    if (raw is! Map) return;
    final message = raw.map((key, value) => MapEntry('$key', value));
    final cmd = '${message['cmd']}';
    if (cmd == 'transcript') {
      final text = '${message['text']}'.trim();
      if (text.isNotEmpty) {
        debugPrint('FLVA wasm transcript length=${text.length}');
        _transcripts.add(text);
      }
      return;
    }
    if (cmd == 'error') {
      final code = _code('${message['code']}');
      final error = AgentFailure(code, '${message['message']}', fatal: false);
      if (_pending == null) {
        debugPrint('FLVA wasm error ${message['message']}');
        return;
      }
      _completePending(error: error);
      return;
    }
    _completePending(value: message);
  }

  Future<Map<String, Object?>> _request(
    Map<String, Object?> message, {
    required String expect,
  }) async {
    final worker = _worker;
    if (worker == null) {
      throw const AgentFailure(
        AgentErrorCode.unsupportedProfile,
        'The sherpa-onnx WASM worker is not started.',
        fatal: false,
      );
    }
    final completer = Completer<Map<String, Object?>>();
    _pending = completer;
    worker.postMessage(message.jsify());
    final reply = await completer.future;
    if (reply['cmd'] != expect) {
      throw AgentFailure(
        AgentErrorCode.inferenceFailed,
        'Unexpected WASM worker reply.',
        fatal: false,
      );
    }
    return reply;
  }

  void _completePending({Map<String, Object?>? value, AgentFailure? error}) {
    final pending = _pending;
    _pending = null;
    if (pending == null || pending.isCompleted) return;
    if (error != null) {
      pending.completeError(error);
    } else {
      pending.complete(value ?? const <String, Object?>{});
    }
  }

  void _failPending(AgentFailure error) {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(error);
    }
  }

  AgentErrorCode _code(String name) => AgentErrorCode.values.firstWhere(
    (value) => value.name == name,
    orElse: () => AgentErrorCode.inferenceFailed,
  );
}

const _workerSource = r'''
'use strict';
let moduleObj = null;
let vad = null;
let recognizer = null;
let stream = null;
let tts = null;
let generation = 0;
let frameCount = 0;
let detectedFrames = 0;
let silentAfterDetect = 0;
function fail(code, message) {
  console.error('FLVA wasm ' + code + ' ' + message);
  postMessage({cmd: 'error', code: code, message: message});
}
function writeFile(path, bytes) {
  const parts = String(path).split('/').filter(Boolean);
  let dir = '';
  for (let i = 0; i < parts.length - 1; i++) {
    dir += '/' + parts[i];
    try { moduleObj.FS.mkdir(dir); } catch (e) {}
  }
  moduleObj.FS.writeFile('/' + parts.join('/'), new Uint8Array(bytes));
}
function toFloat32(raw) {
  if (raw instanceof Float32Array) return raw;
  if (!raw) return new Float32Array(0);
  if (ArrayBuffer.isView(raw)) return new Float32Array(raw.buffer, raw.byteOffset, raw.byteLength / 4);
  if (typeof raw.length === 'number') return Float32Array.from(raw);
  return new Float32Array(0);
}
function peakOf(samples) {
  let peak = 0;
  for (let i = 0; i < samples.length; i++) {
    const value = Math.abs(samples[i]);
    if (value > peak) peak = value;
  }
  return peak;
}
function amplify(samples) {
  const peak = peakOf(samples);
  if (peak <= 0 || peak >= 0.08) return samples;
  const gain = Math.min(0.2 / peak, 12);
  const out = new Float32Array(samples.length);
  for (let i = 0; i < samples.length; i++) out[i] = samples[i] * gain;
  return out;
}
function ensureStream() {
  if (!stream && recognizer) stream = recognizer.createStream();
  return stream;
}
function resetStream() {
  if (!stream) return;
  try { stream.free(); } catch (e) {}
  stream = null;
}
function decodeCurrent() {
  const current = stream;
  if (!current || !recognizer) return '';
  while (recognizer.isReady(current)) {
    recognizer.decode(current);
  }
  const result = recognizer.getResult(current);
  return result && result.text ? String(result.text).trim() : '';
}
function emitTranscript(text) {
  const value = String(text || '').trim();
  if (!value) return;
  console.log('FLVA wasm transcript length=' + value.length);
  postMessage({cmd: 'transcript', text: value});
}
self.onmessage = async (event) => {
  const msg = event.data;
  try {
    switch (msg.cmd) {
      case 'boot': {
        (0, eval)(msg.glue);
        (0, eval)(msg.asr);
        (0, eval)(msg.vad);
        (0, eval)(msg.tts);
        if (typeof SherpaOnnx !== 'function') {
          fail('unsupportedProfile', 'SherpaOnnx factory is missing.');
          return;
        }
        moduleObj = await SherpaOnnx({wasmBinary: new Uint8Array(msg.wasm)});
        postMessage({cmd: 'booted'});
        break;
      }
      case 'mount': {
        for (const [path, bytes] of Object.entries(msg.files || {})) {
          writeFile(path, bytes);
        }
        postMessage({cmd: 'mounted'});
        break;
      }
      case 'construct': {
        const paths = msg.paths || {};
        try {
          console.log('FLVA wasm construct vad path=' + paths.vad);
          vad = createVad(moduleObj, {
            sileroVad: {
              model: paths.vad,
              threshold: 0.3,
              minSilenceDuration: 0.4,
              minSpeechDuration: 0.15,
              maxSpeechDuration: 20,
              windowSize: 512,
            },
            tenVad: {
              model: '',
              threshold: 0.5,
              minSilenceDuration: 0.5,
              minSpeechDuration: 0.25,
              maxSpeechDuration: 20,
              windowSize: 256,
            },
            sampleRate: 16000,
            numThreads: 1,
            provider: 'cpu',
            debug: 0,
            bufferSizeInSeconds: 30,
          });
        } catch (e) {
          fail('invalidAsset', 'Silero VAD could not be constructed. ' + (e && e.message ? e.message : e));
          return;
        }
        try {
          console.log(
            'FLVA wasm construct recognizer encoder=' + paths.encoder +
            ' decoder=' + paths.decoder + ' joiner=' + paths.joiner
          );
          recognizer = createOnlineRecognizer(moduleObj, {
            featConfig: {sampleRate: 16000, featureDim: 80},
            modelConfig: {
              transducer: {
                encoder: paths.encoder,
                decoder: paths.decoder,
                joiner: paths.joiner,
              },
              tokens: paths.asrTokens,
              numThreads: 1,
              provider: 'cpu',
              debug: 0,
            },
            decodingMethod: 'greedy_search',
            enableEndpoint: 1,
            rule1MinTrailingSilence: 1.2,
            rule2MinTrailingSilence: 0.6,
            rule3MinUtteranceLength: 20,
          });
          if (!recognizer || !recognizer.handle) {
            fail('invalidAsset', 'The streaming recognizer rejected the catalog files.');
            return;
          }
        } catch (e) {
          fail('invalidAsset', 'The streaming recognizer rejected the catalog files. ' + (e && e.message ? e.message : e));
          return;
        }
        try {
          console.log('FLVA wasm construct tts path=' + paths.ttsModel);
          tts = createOfflineTts(moduleObj, {
            model: {
              vits: {
                model: paths.ttsModel,
                lexicon: paths.ttsLexicon,
                tokens: paths.ttsTokens,
                dataDir: '',
                noiseScale: 0.667,
                noiseScaleW: 0.8,
                lengthScale: 1.0,
              },
              numThreads: 1,
              debug: 0,
              provider: 'cpu',
            },
            maxNumSentences: 1,
          });
          if (!tts || !tts.handle) {
            fail('invalidAsset', 'VITS could not be constructed.');
            return;
          }
        } catch (e) {
          fail('invalidAsset', 'VITS could not be constructed. ' + (e && e.message ? e.message : e));
          return;
        }
        console.log('FLVA wasm construct ready');
        postMessage({cmd: 'ready'});
        break;
      }
      case 'frame': {
        if (!vad || !recognizer) {
          return;
        }
        const samples = amplify(toFloat32(msg.samples));
        frameCount++;
        const peak = peakOf(samples);
        const current = ensureStream();
        vad.acceptWaveform(samples);
        if (current) {
          current.acceptWaveform(16000, samples);
          while (recognizer.isReady(current)) {
            recognizer.decode(current);
          }
        }
        const detected = vad.isDetected();
        if (detected) {
          detectedFrames++;
          silentAfterDetect = 0;
        } else if (detectedFrames > 0) {
          silentAfterDetect++;
          if (silentAfterDetect >= 16) {
            vad.flush();
            detectedFrames = 0;
            silentAfterDetect = 0;
          }
        }
        if (frameCount <= 3 || frameCount % 50 === 0) {
          console.log(
            'FLVA wasm frame=' + frameCount +
            ' n=' + samples.length +
            ' peak=' + peak.toFixed(5) +
            ' detected=' + detected
          );
        }
        while (!vad.isEmpty()) {
          vad.front();
          vad.pop();
          const piece = decodeCurrent();
          resetStream();
          emitTranscript(piece);
          detectedFrames = 0;
          silentAfterDetect = 0;
        }
        if (stream && recognizer.isEndpoint(stream)) {
          const piece = decodeCurrent();
          recognizer.reset(stream);
          resetStream();
          emitTranscript(piece);
          detectedFrames = 0;
          silentAfterDetect = 0;
        }
        break;
      }
      case 'synthesize': {
        const token = ++generation;
        if (!tts) {
          fail('inferenceFailed', 'TTS is not constructed.');
          return;
        }
        const audio = tts.generate({
          text: msg.text || '',
          sid: msg.sid || 0,
          speed: 1.0,
        });
        if (token !== generation) {
          postMessage({cmd: 'cancelled'});
          return;
        }
        postMessage({
          cmd: 'audio',
          samples: Array.from(audio.samples || []),
          sampleRate: audio.sampleRate || 16000,
        });
        break;
      }
      case 'invalidate':
        generation++;
        if (vad) vad.reset();
        resetStream();
        frameCount = 0;
        detectedFrames = 0;
        silentAfterDetect = 0;
        break;
      case 'dispose':
        generation++;
        resetStream();
        try { if (vad) vad.free(); } catch (e) {}
        try { if (recognizer) recognizer.free(); } catch (e) {}
        try { if (tts) tts.free(); } catch (e) {}
        vad = null;
        recognizer = null;
        tts = null;
        moduleObj = null;
        postMessage({cmd: 'disposed'});
        break;
    }
  } catch (e) {
    fail('inferenceFailed', 'Web inference failed. ' + (e && e.message ? e.message : e));
  }
};
''';
