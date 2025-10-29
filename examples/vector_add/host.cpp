/**
 * Vector Addition Host Application
 *
 * This host application uses XRT Native API to:
 * 1. Load the FPGA binary (xclbin)
 * 2. Allocate buffers and transfer data to FPGA
 * 3. Execute the kernel
 * 4. Retrieve results and verify correctness
 */

#include <iostream>
#include <vector>
#include <cstdlib>
#include <cstring>

// XRT includes
#include "xrt/xrt_device.h"
#include "xrt/xrt_kernel.h"
#include "xrt/xrt_bo.h"

#define DATA_SIZE 4096

int main(int argc, char** argv) {
    // Check command line arguments
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <xclbin_file>" << std::endl;
        return EXIT_FAILURE;
    }

    std::string xclbin_file = argv[1];
    std::cout << "=== Vector Addition Example ===" << std::endl;
    std::cout << "XCLBIN File: " << xclbin_file << std::endl;
    std::cout << "Vector Size: " << DATA_SIZE << " elements" << std::endl;

    try {
        // Step 1: Initialize device and load xclbin
        std::cout << "\n[1/5] Loading FPGA device..." << std::endl;
        auto device = xrt::device(0);
        std::cout << "      Device found!" << std::endl;

        std::cout << "[2/5] Loading xclbin..." << std::endl;
        auto uuid = device.load_xclbin(xclbin_file);
        std::cout << "      xclbin loaded!" << std::endl;

        // Step 2: Create kernel handle
        std::cout << "[3/5] Creating kernel..." << std::endl;
        auto kernel = xrt::kernel(device, uuid, "vadd");
        std::cout << "      Kernel created!" << std::endl;

        // Step 3: Allocate buffers and initialize input data
        std::cout << "[4/5] Allocating buffers and preparing data..." << std::endl;
        size_t size_bytes = DATA_SIZE * sizeof(unsigned int);

        auto bo_in1 = xrt::bo(device, size_bytes, kernel.group_id(0));
        auto bo_in2 = xrt::bo(device, size_bytes, kernel.group_id(1));
        auto bo_out = xrt::bo(device, size_bytes, kernel.group_id(2));

        // Map buffers to host memory
        auto in1_map = bo_in1.map<unsigned int*>();
        auto in2_map = bo_in2.map<unsigned int*>();
        auto out_map = bo_out.map<unsigned int*>();

        // Initialize input data
        for (int i = 0; i < DATA_SIZE; i++) {
            in1_map[i] = i;
            in2_map[i] = i * 2;
            out_map[i] = 0;
        }

        // Sync input data to device
        bo_in1.sync(XCL_BO_SYNC_BO_TO_DEVICE);
        bo_in2.sync(XCL_BO_SYNC_BO_TO_DEVICE);
        std::cout << "      Data prepared and transferred to FPGA!" << std::endl;

        // Step 4: Execute kernel
        std::cout << "[5/5] Executing kernel..." << std::endl;
        auto run = kernel(bo_in1, bo_in2, bo_out, DATA_SIZE);
        run.wait();
        std::cout << "      Kernel execution complete!" << std::endl;

        // Step 5: Read results back
        std::cout << "\nRetrieving results..." << std::endl;
        bo_out.sync(XCL_BO_SYNC_BO_FROM_DEVICE);

        // Verify results
        std::cout << "Verifying results..." << std::endl;
        int errors = 0;
        for (int i = 0; i < DATA_SIZE; i++) {
            unsigned int expected = in1_map[i] + in2_map[i];
            if (out_map[i] != expected) {
                std::cerr << "ERROR: Result mismatch at index " << i
                          << " - Expected: " << expected
                          << ", Got: " << out_map[i] << std::endl;
                errors++;
                if (errors > 10) {
                    std::cerr << "Too many errors, stopping verification..." << std::endl;
                    break;
                }
            }
        }

        // Print results
        std::cout << "\n=== Results ===" << std::endl;
        if (errors == 0) {
            std::cout << "TEST PASSED! All " << DATA_SIZE << " elements verified." << std::endl;
            std::cout << "\nSample results (first 10 elements):" << std::endl;
            for (int i = 0; i < 10; i++) {
                std::cout << "  " << in1_map[i] << " + " << in2_map[i]
                          << " = " << out_map[i] << std::endl;
            }
            return EXIT_SUCCESS;
        } else {
            std::cerr << "TEST FAILED with " << errors << " errors!" << std::endl;
            return EXIT_FAILURE;
        }

    } catch (const std::exception& e) {
        std::cerr << "ERROR: " << e.what() << std::endl;
        return EXIT_FAILURE;
    }
}