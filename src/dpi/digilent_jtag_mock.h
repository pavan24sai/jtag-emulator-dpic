// digilent_jtag_mock.h
// Generic Digilent JTAG API mock implementation

#ifndef DIGILENT_JTAG_MOCK_H
#define DIGILENT_JTAG_MOCK_H

#include <iostream>
#include <vector>
#include <map>
#include <chrono>
#include <thread>
#include <bitset>
#include <random>

// DPI-C includes
#include "svdpi.h"

// Cross-platform export macro
#ifdef _WIN32
#define DJTG_EXPORT __declspec(dllexport)
#else
#define DJTG_EXPORT
#endif

// Constants
#define TRUE 1
#define FALSE 0

// Device handle type
typedef int HIF;

// JtagDevice class
class JtagDevice {
public:
    bool enabled;
    int clock_freq;
    bool tck_state, tms_state, tdi_state, tdo_state;
    uint32_t device_id;
    int timeout_ms;
    
    JtagDevice();
};

// Utility functions
std::vector<bool> bytes_to_bits(const std::vector<uint8_t>& bytes, int bit_count);
std::vector<uint8_t> bits_to_bytes(const std::vector<bool>& bits);
bool simulate_communication_error(double failure_rate = 0.01);
bool simulate_timeout(int operation_time_ms, int timeout_ms);

// TAP navigation helpers
void tap_reset();
void navigate_to_shift_ir();
void navigate_to_shift_dr();
void navigate_to_shift_dr_with_idle();
void exit_to_run_test_idle();

// Internal pin-drive helpers used by tests (defined in .cpp)
void drive_jtag_pins(svBit tck_val, svBit tms_val, svBit tdi_val);
void read_jtag_pins(svBit* tdo_val);
void wait_cycles(int cycles);

// SV-exported DPI functions/tasks implemented in SystemVerilog TB
extern "C" {
    void sv_drive_jtag_pins(svBit tck_val, svBit tms_val, svBit tdi_val);
    svBit sv_get_tdo();
    void sv_wait_cycles(int cycles);
    void sv_jtag_step(svBit tms, svBit tdi, svBit is_last, svBit* tdo_out);
}

// Core Digilent JTAG API implementation
extern "C" {
    DJTG_EXPORT int djtg_enable(int hif);
    DJTG_EXPORT int djtg_disable(int hif);
    DJTG_EXPORT int djtg_put_tms_tdi_bits(int hif, const svOpenArrayHandle tms_data,
                          const svOpenArrayHandle tdi_data,
                          const svOpenArrayHandle tdo_data,
                          int cbit, svBit overlap);
    DJTG_EXPORT int djtg_get_tms_tdi_tdo_bits(int hif, const svOpenArrayHandle tms_data,
                              const svOpenArrayHandle tdi_data,
                              const svOpenArrayHandle tdo_data,
                              int cbit, svBit overlap);
    DJTG_EXPORT int djtg_set_tms_tdi_tck(int hif, svBit tms, svBit tdi, svBit tck);
    DJTG_EXPORT int djtg_get_tms_tdi_tdo_tck(int hif, svBit* tms, svBit* tdi, svBit* tdo, svBit* tck);
    DJTG_EXPORT int djtg_set_speed(int hif, int freq_req, int* freq_set);
    DJTG_EXPORT int djtg_get_speed(int hif, int* freq_cur);
	
	// Tests
    DJTG_EXPORT int test_counter_idcode(int hif);
    DJTG_EXPORT int test_boundary_scan_sample(int hif);
    DJTG_EXPORT int test_boundary_scan_extest(int hif);
    DJTG_EXPORT int test_bypass(int hif);
    DJTG_EXPORT int test_preload_instruction(int hif);
    DJTG_EXPORT int test_unknown_instruction(int hif);
    DJTG_EXPORT int test_instruction_register_capture(int hif);
    DJTG_EXPORT int test_complex_instruction_sequence(int hif);
    DJTG_EXPORT int test_tap_state_transitions(int hif);
    
    // Main test runner
    DJTG_EXPORT void run_counter_jtag_tests();
}

#endif // DIGILENT_JTAG_MOCK_H
