package main

import "core:fmt"
import "core:math"
import "core:math/cmplx"
import ma "vendor:miniaudio"
import "pffft"



main :: proc() {
    
    result : ma.result
    filepath : cstring = "pffft_test.wav"
    encoder : ma.encoder
    device_config : ma.device_config
    device : ma.device
    encoder_config : ma.encoder_config
    
    encoder_config = ma.encoder_config_init(ma.encoding_format.wav, ma.format.f32, 1, 44100);
    

    result = ma.encoder_init_file(filepath, &encoder_config, &encoder)  
    if result != ma.result.SUCCESS {
        fmt.println("Failed to initialize output file.\n")
    }
    
    fftSize :: 1024
    
    signal   := transmute([^]f32)pffft.aligned_malloc(fftSize * size_of(f32))
    spectrum := transmute([^]f32)pffft.aligned_malloc(fftSize * size_of(f32))

    for i in 0..<fftSize {
        signal[i] = 0.0
    }    

    signal[0] = 1
    signal[1] = 1 
    signal[2] = 1  
    
    setup := pffft.new_setup(fftSize, pffft.TransformType.real)

    pffft.transform_ordered(setup, signal, spectrum, nil, pffft.Direction.forward) 
    pffft.transform_ordered(setup, spectrum, signal, nil, pffft.Direction.backward)
    pffft.destroy_setup(setup)

    spectrum_complex := pffft.to_complex(spectrum, fftSize)
    spectrum_abs := make([]f32, len(spectrum_complex))
    
    for &elem, index in spectrum_abs {
        elem = cmplx.abs(spectrum_complex[index])
    }
    
    for i in 0..<fftSize {
        
        signal[i] /= f32(fftSize)
        fmt.print(signal[i], " ")
    }

    result = ma.encoder_write_pcm_frames(&encoder, raw_data(spectrum_abs), fftSize/2, nil)

    ma.encoder_uninit(&encoder)
    
    delete(spectrum_complex)
    delete(spectrum_abs)

}