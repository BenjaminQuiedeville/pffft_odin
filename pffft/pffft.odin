package pffft

import "core:c"
foreign import "pffft.lib"


Setup :: struct {}

Direction :: enum c.int {
    forward = 0, 
    backward,
}

TransformType :: enum c.int {
    real = 0,
    complex,
}

@(link_prefix = "pffft_")
foreign pffft {
    
    new_setup :: proc(N : c.int, transform : TransformType) -> ^Setup ---
    destroy_setup :: proc(setup : ^Setup) ---

    transform :: proc(setup     : ^Setup, 
                      input     : ^c.float, 
                      output    : ^c.float, 
                      work      : ^c.float, 
                      direction : Direction) ---

    transform_ordered :: proc(setup     : ^Setup, 
                              input     : ^c.float, 
                              output    : ^c.float, 
                              work      : ^c.float, 
                              direction : Direction) ---

    zreorder :: proc(setup     : ^Setup, 
                     input     : ^c.float, 
                     output    : ^c.float, 
                     direction : Direction) ---

    zconvolve_accumulate ::proc(setup   : ^Setup, 
                                dft_a   : ^c.float,
                                dft_b   : ^c.float,
                                dft_ab  : ^c.float,
                                scaling : c.float) ---
    
    aligned_malloc :: proc(nb_bytes : u64) -> rawptr ---
    aligned_free :: proc(ptr : rawptr) ---
    
    simd_size :: proc() -> c.int ---
}

to_complex :: proc(source : [^]f32, size : int) -> []complex64 {
    result := make([]complex64, int(size/2))
    
    for &element, index in result {
        element = source[index] + source[index+size/2]
    }
    return result
}
