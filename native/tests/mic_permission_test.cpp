#include "mic_permission.h"

#include <cassert>

int main() {
  assert(flva_mic_start_decision(0) == FLVA_MIC_ASK);
  assert(flva_mic_start_decision(3) == FLVA_MIC_ALLOW);
  assert(flva_mic_start_decision(1) == FLVA_MIC_DENY);
  assert(flva_mic_start_decision(2) == FLVA_MIC_DENY);
  assert(flva_mic_start_decision(-1) == FLVA_MIC_DENY);
  assert(flva_mic_start_decision(4) == FLVA_MIC_DENY);
  return 0;
}
