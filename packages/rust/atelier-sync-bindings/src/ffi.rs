//! Versioned C ABI for Swift and Android NDK/JNI host adapters.

use crate::{
    canonicalize_checkpoint_v1, canonicalize_envelope_v1, capabilities_v1_json,
    CollaborationCoreError, BINDING_ABI_VERSION_V1,
};
use std::{
    panic::{catch_unwind, AssertUnwindSafe},
    ptr, slice, str,
};

/// Owned bytes allocated by the collaboration library.
///
/// Call `atelier_collaboration_buffer_free_v1` exactly once when finished.
#[repr(C)]
#[derive(Debug)]
pub struct AtelierCollaborationBufferV1 {
    /// Start of the allocated bytes.
    pub data: *mut u8,
    /// Number of initialized bytes.
    pub len: usize,
    /// Allocation capacity needed by the matching free function.
    pub capacity: usize,
}

impl AtelierCollaborationBufferV1 {
    const fn empty() -> Self {
        Self {
            data: ptr::null_mut(),
            len: 0,
            capacity: 0,
        }
    }
}

impl Default for AtelierCollaborationBufferV1 {
    fn default() -> Self {
        Self::empty()
    }
}

/// Status returned by every fallible C ABI operation.
#[repr(i32)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AtelierCollaborationStatusV1 {
    /// The output buffer contains the requested UTF-8 JSON.
    Ok = 0,
    /// A required pointer was null.
    NullPointer = 1,
    /// Input bytes were not UTF-8.
    InvalidUtf8 = 2,
    /// Envelope parsing or protocol-version validation failed.
    InvalidEnvelope = 3,
    /// Checkpoint parsing or integrity validation failed.
    InvalidCheckpoint = 4,
    /// Rust caught a panic before it crossed the ABI boundary.
    Panic = 255,
}

/// Return the native binding ABI version.
#[unsafe(no_mangle)]
pub extern "C" fn atelier_collaboration_abi_version_v1() -> u32 {
    BINDING_ABI_VERSION_V1
}

/// Return `0`; this serialization package does not link live Iroh transport.
#[unsafe(no_mangle)]
pub extern "C" fn atelier_collaboration_live_iroh_transport_available_v1() -> u8 {
    0
}

/// Allocate the deterministic capability JSON into `output`.
///
/// # Safety
///
/// `output` must be null or point to writable, properly aligned storage for one
/// `AtelierCollaborationBufferV1`. A successful buffer must be released with
/// `atelier_collaboration_buffer_free_v1` exactly once.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn atelier_collaboration_capabilities_v1(
    output: *mut AtelierCollaborationBufferV1,
) -> AtelierCollaborationStatusV1 {
    unsafe { export_output(output, || Ok(capabilities_v1_json().to_owned())) }
}

/// Validate and canonicalize one UTF-8 V1 envelope.
///
/// # Safety
///
/// `input` must point to `input_len` readable bytes for the duration of the
/// call. `output` follows the contract documented by
/// `atelier_collaboration_capabilities_v1`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn atelier_collaboration_canonicalize_envelope_v1(
    input: *const u8,
    input_len: usize,
    output: *mut AtelierCollaborationBufferV1,
) -> AtelierCollaborationStatusV1 {
    unsafe { export_input_output(input, input_len, output, canonicalize_envelope_v1) }
}

/// Validate and canonicalize one UTF-8 V1 checkpoint.
///
/// # Safety
///
/// `input` must point to `input_len` readable bytes for the duration of the
/// call. `output` follows the contract documented by
/// `atelier_collaboration_capabilities_v1`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn atelier_collaboration_canonicalize_checkpoint_v1(
    input: *const u8,
    input_len: usize,
    output: *mut AtelierCollaborationBufferV1,
) -> AtelierCollaborationStatusV1 {
    unsafe { export_input_output(input, input_len, output, canonicalize_checkpoint_v1) }
}

/// Release and zero an output buffer returned by this ABI.
///
/// # Safety
///
/// `buffer` must be null or a writable buffer value initialized by this ABI and
/// not already released. The function zeros the value to make repeated host-side
/// cleanup guards harmless.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn atelier_collaboration_buffer_free_v1(
    buffer: *mut AtelierCollaborationBufferV1,
) {
    if buffer.is_null() {
        return;
    }
    let owned = unsafe { ptr::read(buffer) };
    if !owned.data.is_null() {
        // SAFETY: the only non-null values returned by this ABI originate from
        // `Vec<u8>` with exactly these length and capacity fields.
        drop(unsafe { Vec::from_raw_parts(owned.data, owned.len, owned.capacity) });
    }
    unsafe { ptr::write(buffer, AtelierCollaborationBufferV1::empty()) };
}

unsafe fn export_input_output(
    input: *const u8,
    input_len: usize,
    output: *mut AtelierCollaborationBufferV1,
    transform: fn(&str) -> Result<String, CollaborationCoreError>,
) -> AtelierCollaborationStatusV1 {
    if input.is_null() || output.is_null() {
        return AtelierCollaborationStatusV1::NullPointer;
    }
    unsafe {
        export_output(output, || {
            // SAFETY: upheld by the exported function's caller contract.
            let bytes = slice::from_raw_parts(input, input_len);
            let text = str::from_utf8(bytes).map_err(|_| InputError::InvalidUtf8)?;
            transform(text).map_err(InputError::Core)
        })
    }
}

unsafe fn export_output<F>(
    output: *mut AtelierCollaborationBufferV1,
    operation: F,
) -> AtelierCollaborationStatusV1
where
    F: FnOnce() -> Result<String, InputError>,
{
    if output.is_null() {
        return AtelierCollaborationStatusV1::NullPointer;
    }
    unsafe { ptr::write(output, AtelierCollaborationBufferV1::empty()) };
    match catch_unwind(AssertUnwindSafe(operation)) {
        Ok(Ok(value)) => {
            let mut bytes = value.into_bytes();
            let result = AtelierCollaborationBufferV1 {
                data: bytes.as_mut_ptr(),
                len: bytes.len(),
                capacity: bytes.capacity(),
            };
            std::mem::forget(bytes);
            unsafe { ptr::write(output, result) };
            AtelierCollaborationStatusV1::Ok
        }
        Ok(Err(error)) => error.status(),
        Err(_) => AtelierCollaborationStatusV1::Panic,
    }
}

enum InputError {
    InvalidUtf8,
    Core(CollaborationCoreError),
}

impl InputError {
    const fn status(&self) -> AtelierCollaborationStatusV1 {
        match self {
            Self::InvalidUtf8 => AtelierCollaborationStatusV1::InvalidUtf8,
            Self::Core(CollaborationCoreError::InvalidEnvelope(_)) => {
                AtelierCollaborationStatusV1::InvalidEnvelope
            }
            Self::Core(CollaborationCoreError::InvalidCheckpoint(_)) => {
                AtelierCollaborationStatusV1::InvalidCheckpoint
            }
            Self::Core(CollaborationCoreError::InvalidUtf8) => {
                AtelierCollaborationStatusV1::InvalidUtf8
            }
        }
    }
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;

    const ENVELOPE: &str = include_str!("../fixtures/v1/envelope-presence.json");
    const CHECKPOINT: &str = include_str!("../fixtures/v1/checkpoint.json");

    fn fixture_bytes(value: &str) -> &str {
        value.strip_suffix('\n').unwrap_or(value)
    }

    #[test]
    fn c_abi_round_trips_and_releases_owned_bytes() {
        let expected = fixture_bytes(ENVELOPE);
        let mut output = AtelierCollaborationBufferV1::default();
        // SAFETY: both input and output storage remain valid for the call.
        let status = unsafe {
            atelier_collaboration_canonicalize_envelope_v1(
                expected.as_ptr(),
                expected.len(),
                &mut output,
            )
        };
        assert_eq!(status, AtelierCollaborationStatusV1::Ok);
        // SAFETY: a successful call initialized `output` for `output.len` bytes.
        let actual = unsafe { slice::from_raw_parts(output.data, output.len) };
        assert_eq!(actual, expected.as_bytes());

        // SAFETY: `output` came from this ABI and has not yet been released.
        unsafe { atelier_collaboration_buffer_free_v1(&mut output) };
        assert!(output.data.is_null());
        assert_eq!(output.len, 0);
        assert_eq!(output.capacity, 0);
    }

    #[test]
    fn c_abi_reports_invalid_utf8_without_allocating() {
        let input = [0xff_u8];
        let mut output = AtelierCollaborationBufferV1::default();
        // SAFETY: both input and output storage remain valid for the call.
        let status = unsafe {
            atelier_collaboration_canonicalize_envelope_v1(input.as_ptr(), input.len(), &mut output)
        };
        assert_eq!(status, AtelierCollaborationStatusV1::InvalidUtf8);
        assert!(output.data.is_null());
    }

    #[test]
    fn c_abi_capabilities_keep_transport_unavailable() {
        let mut output = AtelierCollaborationBufferV1::default();
        // SAFETY: output storage remains valid for the call and is released once.
        assert_eq!(
            unsafe { atelier_collaboration_capabilities_v1(&mut output) },
            AtelierCollaborationStatusV1::Ok
        );
        // SAFETY: a successful call initialized `output` for `output.len` bytes.
        let actual = unsafe { slice::from_raw_parts(output.data, output.len) };
        assert_eq!(actual, capabilities_v1_json().as_bytes());
        assert_eq!(atelier_collaboration_live_iroh_transport_available_v1(), 0);
        // SAFETY: `output` came from this ABI and has not yet been released.
        unsafe { atelier_collaboration_buffer_free_v1(&mut output) };
    }

    #[test]
    fn c_abi_exposes_version_and_rejects_null_pointers() {
        assert_eq!(
            atelier_collaboration_abi_version_v1(),
            BINDING_ABI_VERSION_V1
        );

        // SAFETY: null is explicitly supported as a no-op by the free contract.
        unsafe { atelier_collaboration_buffer_free_v1(ptr::null_mut()) };
        let mut empty = AtelierCollaborationBufferV1::default();
        // SAFETY: `empty` is a valid, writable ABI buffer with no allocation.
        unsafe { atelier_collaboration_buffer_free_v1(&mut empty) };
        assert!(empty.data.is_null());

        // SAFETY: these calls deliberately exercise documented null-pointer rejection.
        assert_eq!(
            unsafe { atelier_collaboration_capabilities_v1(ptr::null_mut()) },
            AtelierCollaborationStatusV1::NullPointer
        );
        assert_eq!(
            unsafe {
                atelier_collaboration_canonicalize_envelope_v1(
                    ENVELOPE.as_ptr(),
                    ENVELOPE.len(),
                    ptr::null_mut(),
                )
            },
            AtelierCollaborationStatusV1::NullPointer
        );
        let mut output = AtelierCollaborationBufferV1::default();
        assert_eq!(
            unsafe { atelier_collaboration_canonicalize_envelope_v1(ptr::null(), 0, &mut output,) },
            AtelierCollaborationStatusV1::NullPointer
        );
    }

    #[test]
    fn c_abi_canonicalizes_checkpoints_and_maps_protocol_errors() {
        let checkpoint = fixture_bytes(CHECKPOINT);
        let mut output = AtelierCollaborationBufferV1::default();
        // SAFETY: input and output storage remain valid for each call.
        assert_eq!(
            unsafe {
                atelier_collaboration_canonicalize_checkpoint_v1(
                    checkpoint.as_ptr(),
                    checkpoint.len(),
                    &mut output,
                )
            },
            AtelierCollaborationStatusV1::Ok
        );
        // SAFETY: the successful call initialized `output` for `output.len` bytes.
        let actual = unsafe { slice::from_raw_parts(output.data, output.len) };
        assert_eq!(actual, checkpoint.as_bytes());
        // SAFETY: `output` came from this ABI and has not yet been released.
        unsafe { atelier_collaboration_buffer_free_v1(&mut output) };

        let invalid_envelope = b"{}";
        assert_eq!(
            unsafe {
                atelier_collaboration_canonicalize_envelope_v1(
                    invalid_envelope.as_ptr(),
                    invalid_envelope.len(),
                    &mut output,
                )
            },
            AtelierCollaborationStatusV1::InvalidEnvelope
        );

        let corrupt_checkpoint = checkpoint.replace(
            "054edec1d0211f624fed0cbca9d4f9400b0e491c43742af2c5b0abebf0c990d8",
            "154edec1d0211f624fed0cbca9d4f9400b0e491c43742af2c5b0abebf0c990d8",
        );
        assert_eq!(
            unsafe {
                atelier_collaboration_canonicalize_checkpoint_v1(
                    corrupt_checkpoint.as_ptr(),
                    corrupt_checkpoint.len(),
                    &mut output,
                )
            },
            AtelierCollaborationStatusV1::InvalidCheckpoint
        );
    }

    #[test]
    fn c_abi_contains_panics_and_maps_internal_utf8_errors() {
        let mut output = AtelierCollaborationBufferV1::default();
        // SAFETY: output storage remains valid while the deliberately panicking operation runs.
        assert_eq!(
            unsafe {
                export_output(&mut output, || -> Result<String, InputError> {
                    panic!("contained at the ABI boundary")
                })
            },
            AtelierCollaborationStatusV1::Panic
        );
        assert!(output.data.is_null());
        assert_eq!(
            InputError::Core(CollaborationCoreError::InvalidUtf8).status(),
            AtelierCollaborationStatusV1::InvalidUtf8
        );
    }
}
