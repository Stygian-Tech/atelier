//! `wasm-bindgen` exports for the same V1 canonicalization contract as C.

use crate::{
    canonicalize_checkpoint_v1, canonicalize_envelope_v1, capabilities_v1_json,
    BINDING_ABI_VERSION_V1,
};
use wasm_bindgen::prelude::*;

#[wasm_bindgen(js_name = collaborationAbiVersionV1)]
pub fn collaboration_abi_version_v1() -> u32 {
    BINDING_ABI_VERSION_V1
}

#[wasm_bindgen(js_name = collaborationCapabilitiesV1)]
pub fn collaboration_capabilities_v1() -> String {
    capabilities_v1_json().to_owned()
}

#[wasm_bindgen(js_name = collaborationLiveIrohTransportAvailableV1)]
pub fn collaboration_live_iroh_transport_available_v1() -> bool {
    false
}

#[wasm_bindgen(js_name = canonicalizeEnvelopeV1)]
pub fn canonicalize_envelope_wasm_v1(input: &str) -> Result<String, JsValue> {
    canonicalize_envelope_v1(input).map_err(|error| JsValue::from_str(&error.to_string()))
}

#[wasm_bindgen(js_name = canonicalizeCheckpointV1)]
pub fn canonicalize_checkpoint_wasm_v1(input: &str) -> Result<String, JsValue> {
    canonicalize_checkpoint_v1(input).map_err(|error| JsValue::from_str(&error.to_string()))
}
