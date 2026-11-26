# PFFFT_ODIN

A simple wrapper around Julien Pommier's [Pretty Fast Fast Fourier Transform](https://bitbucket.org/jpommier/pffft/src/master/) with cutsom Setup initialization procedures to leverage Odin's allocator mechanisms.

You should be able to clone the repo in your porject and import it in your Odin source code. An example usage is show in the test directory.

To compile the pffft static lib, in the pffft directory:
```gcc -c -o pffft.o pffft.c -O3 && ar -r -o libpffft.a pffft.o``` on Unix Systems 
```cl /nologo /Tc /c /Fo:pffft.obj pffft.c /O2 && lib /nologo /out:pffft.lib pffft.obj``` on in a Windows Developper Prompt
