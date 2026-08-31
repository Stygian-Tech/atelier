#ifndef ATELIER_COLLABORATION_V1_H
#define ATELIER_COLLABORATION_V1_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct AtelierCollaborationBufferV1 {
  uint8_t *data;
  size_t len;
  size_t capacity;
} AtelierCollaborationBufferV1;

typedef enum AtelierCollaborationStatusV1 {
  ATELIER_COLLABORATION_OK_V1 = 0,
  ATELIER_COLLABORATION_NULL_POINTER_V1 = 1,
  ATELIER_COLLABORATION_INVALID_UTF8_V1 = 2,
  ATELIER_COLLABORATION_INVALID_ENVELOPE_V1 = 3,
  ATELIER_COLLABORATION_INVALID_CHECKPOINT_V1 = 4,
  ATELIER_COLLABORATION_PANIC_V1 = 255,
} AtelierCollaborationStatusV1;

uint32_t atelier_collaboration_abi_version_v1(void);
uint8_t atelier_collaboration_live_iroh_transport_available_v1(void);

AtelierCollaborationStatusV1 atelier_collaboration_capabilities_v1(
    AtelierCollaborationBufferV1 *output);
AtelierCollaborationStatusV1 atelier_collaboration_canonicalize_envelope_v1(
    const uint8_t *input,
    size_t input_len,
    AtelierCollaborationBufferV1 *output);
AtelierCollaborationStatusV1 atelier_collaboration_canonicalize_checkpoint_v1(
    const uint8_t *input,
    size_t input_len,
    AtelierCollaborationBufferV1 *output);

void atelier_collaboration_buffer_free_v1(
    AtelierCollaborationBufferV1 *buffer);

#ifdef __cplusplus
}
#endif

#endif
