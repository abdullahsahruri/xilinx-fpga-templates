/**
 * Vector Addition Kernel
 *
 * Simple example that adds two vectors element-by-element.
 * This demonstrates basic HLS kernel structure and memory interfaces.
 */

extern "C" {

void vadd(
    const unsigned int* in1,  // Read-Only Vector 1
    const unsigned int* in2,  // Read-Only Vector 2
    unsigned int* out,        // Output Result
    int size                  // Size of the vectors
) {
    // HLS interface pragmas define how the kernel communicates with host
    #pragma HLS INTERFACE m_axi port=in1 bundle=gmem0 depth=4096
    #pragma HLS INTERFACE m_axi port=in2 bundle=gmem1 depth=4096
    #pragma HLS INTERFACE m_axi port=out bundle=gmem0 depth=4096
    #pragma HLS INTERFACE s_axilite port=in1
    #pragma HLS INTERFACE s_axilite port=in2
    #pragma HLS INTERFACE s_axilite port=out
    #pragma HLS INTERFACE s_axilite port=size
    #pragma HLS INTERFACE s_axilite port=return

    // Main computation loop - add vectors element by element
    for (int i = 0; i < size; i++) {
        #pragma HLS PIPELINE II=1  // Pipeline for performance
        out[i] = in1[i] + in2[i];
    }
}

} // extern "C"