package pffft

import "base:runtime"
import "core:c"
import "core:simd"
import "core:math"

when ODIN_OS == .Windows {
    foreign import pffft "pffft/pffft.lib"
} else {
    foreign import pffft "pffft/libpffft.a"
}

/*
   PFFFT : a Pretty Fast FFT.

   This is basically an adaptation of the single precision fftpack
   (v4) as found on netlib taking advantage of SIMD instruction found
   on cpus such as intel x86 (SSE1), powerpc (Altivec), and arm (NEON).

   For architectures where no SIMD instruction is available, the code
   falls back to a scalar version.

   Restrictions:

   - 1D transforms only, with 32-bit single precision.

   - supports only transforms for inputs of length N of the form
   N=(2^a)*(3^b)*(5^c), a >= 5, b >=0, c >= 0 (32, 48, 64, 96, 128,
   144, 160, etc are all acceptable lengths). Performance is best for
   128<=N<=8192.

   - all (float*) pointers in the functions below are expected to
   have an "simd-compatible" alignment, that is 16 bytes on x86 and
   powerpc CPUs.

   You can allocate such buffers with the functions
   pffft_aligned_malloc / pffft_aligned_free (or with stuff like
   posix_memalign..)

*/


when simd.HAS_HARDWARE_SIMD {
    SIMD_SZ :: 4
} else {
    SIMD_SZ :: 1
}

// allocate slices alogned to 64 bytes boundary
alignment :: 64

// struct holding internal stuff (precomputed twiddle factors)
// this struct can be shared by many threads as it contains only
// read-only data.
Setup :: struct {
    N: i32,
    Ncvec: i32, // nb of complex simd vectors (N/4 if PFFFT_COMPLEX, N/8 if PFFFT_REAL)
    ifac: [15]i32,
    transform: TransformType,
    data: [^]simd.f32x4, // allocated room for twiddle coefs
    e: [^]f32,    // points into 'data' , N/4*3 elements
    twiddle: [^]f32, // points into 'data', N/4 elements
}

// direction of the transform
Direction :: enum c.int {
    forward = 0,
    backward,
}

// type of transform
TransformType :: enum c.int {
    real = 0,
    complex,
}


// theses reimplementation give more freedom for allocation and uses Odin's allocator mechanisms
// N: nfft, number of samples for the fft
// transform: see TransformType

new_setup :: proc(N: i32, transform: TransformType, allocator := context.allocator) -> ^Setup {
    setup := new(Setup, allocator=context.allocator)

    init_setup(setup, N, transform, allocator)

    return setup
}

init_setup :: proc(setup: ^Setup, N: i32, transform: TransformType, allocator := context.allocator) {

    /* unfortunately, the fft size must be a multiple of 16 for complex FFTs
     and 32 for real FFTs -- a lot of stuff would need to be rewritten to
     handle other cases (or maybe just switch to a scalar fft, I don't know..) */
    if transform == .real { assert((N%(2*SIMD_SZ*SIMD_SZ))==0 && N>0) }
    if transform == .complex { assert((N%(SIMD_SZ*SIMD_SZ))==0 && N>0) }
    //assert((N % 32) == 0);
    setup.N = N
    setup.transform = transform
    /* nb of complex simd vectors */
    setup.Ncvec = (transform == .real ? N/2 : N)/SIMD_SZ
    setup.data = raw_data(runtime.make_aligned([]simd.f32x4, 2*setup.Ncvec * size_of(simd.f32x4), alignment))
    setup.e = cast([^]f32)setup.data
    setup.twiddle = cast([^]f32)(setup.data[(2*setup.Ncvec*(SIMD_SZ-1))/SIMD_SZ:])

    m: i32
    if (transform == .real) {
        for k in 0..<setup.Ncvec {
            i: i32 = k/SIMD_SZ
            j: i32 = k%SIMD_SZ
            for m in 0..<(SIMD_SZ-1) {
                A := -2*f32(math.PI)*f32(m+1)*f32(k) / f32(N)
                setup.e[(2*(i*3 + i32(m)) + 0) * SIMD_SZ + j] = math.cos_f32(A)
                setup.e[(2*(i*3 + i32(m)) + 1) * SIMD_SZ + j] = math.sin_f32(A)
            }
        }
        rffti1_ps(N/SIMD_SZ, setup.twiddle, raw_data(setup.ifac[:]))
    } else {
        for k in 0..<setup.Ncvec {
            i: i32 = k/SIMD_SZ
            j: i32 = k%SIMD_SZ
            for m in 0..<(SIMD_SZ-1) {
                A := -2*f32(math.PI)*f32(m+1)*f32(k) / f32(N)
                setup.e[(2*(i*3 + i32(m)) + 0)*SIMD_SZ + j] = math.cos_f32(A)
                setup.e[(2*(i*3 + i32(m)) + 1)*SIMD_SZ + j] = math.sin_f32(A)
            }
        }
        cffti1_ps(N/SIMD_SZ, setup.twiddle, raw_data(setup.ifac[:]))
    }

    /* check that N is decomposable with allowed prime factors */
    m = 1
    for k in 0..<setup.ifac[1] { m *= setup.ifac[2+k] }
    if m != N/SIMD_SZ {
        panic("init setup, fft size is not decomposable with allowed prime factor")
    }
}

deinit_setup :: proc(setup: ^Setup) {
    free(setup.data)
}

destroy_setup :: proc(setup: ^Setup) {
    deinit_setup(setup)
    free(setup)
}


to_complex :: proc(source : [^]f32, size : int) -> []complex64 {
    result := make([]complex64, int(size/2))

    for &element, index in result {
        element = complex(source[index], source[index+size/2])
    }
    return result
}


make_slice :: proc(#any_int size: int, allocator := context.allocator, loc := #caller_location) -> ([]f32, runtime.Allocator_Error) #optional_allocator_error {
    return runtime.make_aligned([]f32, size, alignment, allocator, loc)
}


@(link_prefix = "pffft_", default_calling_convention = "c")
foreign pffft {

    @(link_name = "pffft_new_setup")
    new_setup_internal :: proc(N : c.int, transform : TransformType) -> ^Setup ---
    @(link_name = "pffft_destroy_setup")
    destroy_setup_internal :: proc(setup: ^Setup) ---

    // Perform a Fourier transform , The z-domain data is stored in the
    // most efficient order for transforming it back, or using it for
    // convolution. If you need to have its content sorted in the
    // "usual" way, that is as an array of interleaved complex numbers,
    // either use pffft_transform_ordered , or call pffft_zreorder after
    // the forward fft, and before the backward fft.

    // Transforms are not scaled: PFFFT_BACKWARD(PFFFT_FORWARD(x)) = N*x.
    // Typically you will want to scale the backward transform by 1/N.

    // The 'work' pointer should point to an area of N (2*N for complex
    // fft) floats, properly aligned. If 'work' is NULL, then stack will
    // be used instead (this is probably the best strategy for small
    // FFTs, say for N < 16384).
    // input and output may alias.
    transform :: proc(setup: ^Setup, input: [^]f32, output: [^]f32, work: [^]f32, direction: Direction) ---

    // Similar to pffft_transform, but makes sure that the output is
    // ordered as expected (interleaved complex numbers).  This is
    // similar to calling pffft_transform and then pffft_zreorder.
    // input and output may alias.
    transform_ordered :: proc(setup: ^Setup, input: [^]f32, output: [^]f32, work: [^]f32, direction: Direction) ---

    // call pffft_zreorder(.., PFFFT_FORWARD) after pffft_transform(...,
    // PFFFT_FORWARD) if you want to have the frequency components in
    // the correct "canonical" order, as interleaved complex numbers.

    // (for real transforms, both 0-frequency and half frequency
    // components, which are real, are assembled in the first entry as
    // F(0)+i*F(n/2+1). Note that the original fftpack did place
    // F(n/2+1) at the end of the arrays).
    // input and output should not alias.
    zreorder :: proc(setup: ^Setup, input: [^]f32, output: [^]f32, direction: Direction) ---

    // Perform a multiplication of the frequency components of dft_a and
    // dft_b and accumulate them into dft_ab. The arrays should have
    // been obtained with pffft_transform(.., PFFFT_FORWARD) and should
    // *not* have been reordered with pffft_zreorder (otherwise just
    // perform the operation yourself as the dft coefs are stored as
    // interleaved complex numbers).
    // the operation performed is: dft_ab += (dft_a * fdt_b)*scaling
    // The dft_a, dft_b and dft_ab pointers may alias.
    zconvolve_accumulate :: proc(setup: ^Setup, dft_a: [^]f32, dft_b: [^]f32, dft_ab: [^]f32, scaling: c.float) ---


    // the float buffers must have the correct alignment (16-byte boundary
    // on intel and powerpc). This function may be used to obtain such
    // correctly aligned buffers.
    aligned_malloc :: proc(nb_bytes: u64) -> rawptr ---
    aligned_free :: proc(ptr: rawptr) ---

    // return 4 or 1 wether support SSE/Altivec instructions was enable when building pffft.c
    simd_size :: proc() -> c.int ---
}

@(default_calling_convention = "c")
foreign pffft {
    // internal procedures needed for new_setup reimplementation
    rffti1_ps :: proc(n: i32, wa: [^]f32, ifac: [^]i32) ---
    cffti1_ps :: proc(n: i32, wa: [^]f32, ifac: [^]i32) ---
}