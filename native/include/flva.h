#ifndef FLVA_H
#define FLVA_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* ABI 1. Control operations are serialized by the platform owner. All string
 * inputs are copied by create/reply. No borrowed pointers escape these calls.
 * create/stop/destroy may block: call off UI and audio threads. */
typedef struct FlvaSession FlvaSession;
typedef struct {
  const char *vad, *encoder, *decoder, *joiner, *asr_tokens;
  const char *tts_model, *tts_tokens, *tts_lexicon;
  const char *llm_model; /* empty: Dart logic; requires optional build otherwise */
  int32_t input_rate; /* mono float32, 8000..192000, constant per session */
  int32_t speaker_id; /* >= 0; default 0 */
} FlvaConfig;
/* Fixed-capacity UTF-8 messages. kind: state, partial, final, reply, error.
 * activity: idle/listening/recognizing/thinking/speaking. code is an error name.
 * Generation is the request identity; Dart replies must echo it unchanged. */
typedef struct {
  uint64_t sequence, generation;
  char kind[16], activity[24], code[40], text[2048];
} FlvaEvent;
FlvaSession *flva_create(const FlvaConfig *, char *error, int32_t error_capacity);
/* Next generate uses speaker_id. Out-of-range leaves the stored id and session. */
int32_t flva_set_speaker_id(FlvaSession *, int32_t speaker_id, char *error, int32_t error_capacity);
int32_t flva_output_rate(const FlvaSession *);
int32_t flva_start(FlvaSession *);
/* Interrupt invalidates output synchronously; worker reset is asynchronous. */
uint64_t flva_interrupt(FlvaSession *);
void flva_stop(FlvaSession *);
void flva_destroy(FlvaSession *); /* audio callbacks MUST already be quiescent */
int32_t flva_reply(FlvaSession *, uint64_t generation, const char *utf8);
/* One producer/consumer each. No allocations, waiting, or inference. Push is
 * all-or-nothing; overflow latches discontinuity. Render zero-fills underflow. */
int32_t flva_push(FlvaSession *, const float *, int32_t frames);
void flva_render(FlvaSession *, float *, int32_t frames);
int32_t flva_poll(FlvaSession *, FlvaEvent *);
#ifdef __cplusplus
}
#endif
#endif
