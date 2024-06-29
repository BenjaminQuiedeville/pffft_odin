package main

import "core:fmt"
import "core:c"
foreign import pffft "pffft/pffft.lib"


PFFFT_Setup :: struct {}

pffft_direction :: enum c.int {
    forward = 0, 
    backward,
}

pffft_transform_type :: enum c.int {
    real = 0,
    complex,
}
 

@(default_calling_convention="c")
foreign pffft {
    
    pffft_new_setup :: proc(N : c.int, transform : pffft_transform_type) -> ^PFFFT_Setup ---
    pffft_destroy_setup :: proc(setup : ^PFFFT_Setup) ---

    pffft_transform :: proc(setup : ^PFFFT_Setup, 
                            input : ^f32, 
                            output : ^f32, 
                            work : ^f32, 
                            direction : pffft_direction) ---

    pffft_transform_ordered :: proc(setup : ^PFFFT_Setup, 
                                    input : ^f32, 
                                    output : ^f32, 
                                    work : ^f32, 
                                    direction : pffft_direction) ---

    pffft_zreorder :: proc(setup : ^PFFFT_Setup, 
                           input : ^f32, 
                           output : ^f32, 
                           direction : pffft_direction) ---

    pffft_zconvolve_accumulate ::proc(setup : ^PFFFT_Setup, 
                                      dft_a : ^f32,
                                      dft_b : ^f32,
                                      dft_ab : ^f32,
                                      scaling : f32) ---

    pffft_aligned_malloc :: proc(nb_bytes : u64) -> rawptr ---
    pffft_aligned_free :: proc(ptr : rawptr) ---
    
    pffft_simd_size :: proc() -> c.int ---
}



main :: proc() {
    
    fftSize : u64 : 64
    
    signal := transmute(^f32)pffft_aligned_malloc(fftSize * size_of(f32))
    output := transmute(^f32)pffft_aligned_malloc(fftSize * size_of(f32))
    fmt.println("buffer properly allocated")

    for i in 0..<fftSize {
        
        signal^[i] = 0
        output^[i] = 0
    }


    setup := pffft_new_setup(64, pffft_transform_type.real)

    pffft_transform(setup, transmute(^f32)signal, transmute(^f32)output, transmute(^f32)c.NULL, pffft_direction.forward) 

    pffft_destroy_setup(setup)

}