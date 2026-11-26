package main

import "core:fmt"
import pffft "../../pffft_odin"
import "core:math/cmplx"
import "core:math"
import "base:runtime"

main :: proc() {

    test_frequency := 0.25
    fftSize :: 128

    setup: pffft.Setup
    pffft.init_setup(&setup, fftSize, pffft.TransformType.real)

    signal := pffft.make_slice(fftSize)
    spectrum := pffft.make_slice(fftSize)
    work := pffft.make_slice(fftSize)
    defer {
        delete(signal)
        delete(spectrum)
        delete(work)
    }

    defer pffft.deinit_setup(&setup)

    fmt.println("pffft alignment:  ", pffft.alignment)
    fmt.println("simd size: ", pffft.simd_size())

    for i in 0..<fftSize {
        signal[i] = cast(f32)math.sin(math.PI * 2.0 * test_frequency * f64(i))
        signal[i] += cast(f32)math.sin(math.PI * 2.0 * 0.5*test_frequency * f64(i))
    }

    pffft.transform_ordered(&setup, raw_data(signal), raw_data(spectrum), raw_data(work), .forward)
    module := make([]f32, fftSize)

    for index := 0; index < fftSize-1; index+=2 {
        module[index] = cmplx.abs(complex(spectrum[index], spectrum[index +1]))
        fmt.println(module[index])
    }
}