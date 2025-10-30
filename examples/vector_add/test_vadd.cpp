/**
 * Standalone Testbench for Vector Addition
 *
 * Phase 1: Use with g++ for rapid algorithm development
 * Compile: g++ -std=c++14 -I. vector_add.cpp test_vadd.cpp -o test_vadd && ./test_vadd
 *
 * No Xilinx tools required - just standard C++ compiler!
 */

#include <iostream>
#include <iomanip>

// Kernel function prototype (without HLS pragmas for g++)
extern "C" {
void vadd(const unsigned int* in1, const unsigned int* in2, unsigned int* out, int size);
}

#define DATA_SIZE 4096

int main() {
    std::cout << "=== Vector Addition Testbench (g++) ===" << std::endl;
    std::cout << "Phase 1: Algorithm validation - Seconds per iteration" << std::endl;
    std::cout << std::endl;

    // Allocate test vectors
    unsigned int* in1 = new unsigned int[DATA_SIZE];
    unsigned int* in2 = new unsigned int[DATA_SIZE];
    unsigned int* out = new unsigned int[DATA_SIZE];

    // Initialize input data
    std::cout << "[1/4] Preparing test data..." << std::endl;
    for (int i = 0; i < DATA_SIZE; i++) {
        in1[i] = i;           // [0, 1, 2, 3, ...]
        in2[i] = i * 2;       // [0, 2, 4, 6, ...]
        out[i] = 0;
    }

    // Call kernel function directly (no XRT overhead!)
    std::cout << "[2/4] Executing kernel..." << std::endl;
    vadd(in1, in2, out, DATA_SIZE);

    // Verify results
    std::cout << "[3/4] Verifying results..." << std::endl;
    bool passed = true;
    int errors = 0;
    const int MAX_ERRORS_TO_SHOW = 5;

    for (int i = 0; i < DATA_SIZE; i++) {
        unsigned int expected = in1[i] + in2[i];
        if (out[i] != expected) {
            if (errors < MAX_ERRORS_TO_SHOW) {
                std::cout << "  ERROR at index " << i << ": "
                          << "expected " << expected
                          << ", got " << out[i] << std::endl;
            }
            errors++;
            passed = false;
        }
    }

    // Print results
    std::cout << "[4/4] Test complete" << std::endl;
    std::cout << std::endl;
    std::cout << "=== Results ===" << std::endl;

    if (passed) {
        std::cout << "TEST PASSED! All " << DATA_SIZE << " elements verified." << std::endl;
    } else {
        std::cout << "TEST FAILED! " << errors << " errors found";
        if (errors > MAX_ERRORS_TO_SHOW) {
            std::cout << " (showing first " << MAX_ERRORS_TO_SHOW << ")";
        }
        std::cout << std::endl;
    }

    // Sample output
    std::cout << std::endl;
    std::cout << "Sample values:" << std::endl;
    std::cout << "  in1[0] + in2[0] = " << in1[0] << " + " << in2[0] << " = " << out[0] << std::endl;
    std::cout << "  in1[10] + in2[10] = " << in1[10] << " + " << in2[10] << " = " << out[10] << std::endl;
    std::cout << "  in1[100] + in2[100] = " << in1[100] << " + " << in2[100] << " = " << out[100] << std::endl;

    // Cleanup
    delete[] in1;
    delete[] in2;
    delete[] out;

    return passed ? 0 : 1;
}