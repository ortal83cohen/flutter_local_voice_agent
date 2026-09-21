#ifndef FLVA_MIC_PERMISSION_H
#define FLVA_MIC_PERMISSION_H

#ifdef __cplusplus
extern "C" {
#endif

// Maps AVAuthorizationStatus integers used by the macOS start path.
// 0 NotDetermined, 1 Restricted, 2 Denied, 3 Authorized.
enum FlvaMicStartDecision {
  FLVA_MIC_ASK = 0,
  FLVA_MIC_DENY = 1,
  FLVA_MIC_ALLOW = 2
};

static inline int flva_mic_start_decision(int authorization_status) {
  if (authorization_status == 0) {
    return FLVA_MIC_ASK;
  }
  if (authorization_status == 3) {
    return FLVA_MIC_ALLOW;
  }
  return FLVA_MIC_DENY;
}

#ifdef __cplusplus
}
#endif

#endif
