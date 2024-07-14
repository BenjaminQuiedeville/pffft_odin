package main 

import "core:fmt"
import pffft "../../pffft_odin"
import "core:math/cmplx"
import "core:math"

main :: proc() {

    test_frequency := 0.25
    fftSize :: 64
    
    setup : ^pffft.Setup = pffft.new_setup(fftSize, pffft.TransformType.real)
    signal   := transmute([^]f32)pffft.aligned_malloc(fftSize * size_of(f32))
    spectrum := transmute([^]f32)pffft.aligned_malloc(fftSize * size_of(f32))
    defer pffft.aligned_free(signal)
    defer pffft.aligned_free(spectrum)
    defer pffft.destroy_setup(setup)
    
    for i in 0..<fftSize {
        signal[i] = cast(f32)math.sin(math.PI * 2.0 * test_frequency * f64(i))
    }
    
    pffft.transform_ordered(setup, signal, spectrum, nil, pffft.Direction.forward)
    
    module := make([]f32, fftSize)
    
    for index := 0; index < fftSize-1; index+=2 {    
        module[index] = cmplx.abs(complex(spectrum[index], spectrum[index +1]))
        fmt.println(module[index])
    }
}