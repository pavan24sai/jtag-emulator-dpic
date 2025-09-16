// digilent_jtag_mock.cpp
// Generic Digilent JTAG API mock implementation

#include <iostream>
#include <vector>
#include <map>
#include <chrono>
#include <thread>
#include <bitset>
#include <random>
#include <cstdio>
#include "digilent_jtag_mock.h"
#include "svdpi.h"

// Device registry
static std::map<HIF, JtagDevice> device_registry;
static std::random_device rd;
static std::mt19937 gen(rd());

// JtagDevice constructor
JtagDevice::JtagDevice() : enabled(false), clock_freq(1000000),
                           tck_state(false), tms_state(false),
                           tdi_state(false), tdo_state(false),
                           device_id(0x12345678), timeout_ms(1000) {}

// Utility functions
std::vector<bool> bytes_to_bits(const std::vector<uint8_t>& bytes, int bit_count) {
    std::vector<bool> bits;
    for (int i = 0; i < bit_count; i++) {
        bool bit_val = (bytes[i/8] >> (i % 8)) & 1;
        bits.push_back(bit_val);
    }
    return bits;
}

std::vector<uint8_t> bits_to_bytes(const std::vector<bool>& bits) {
    std::vector<uint8_t> bytes((bits.size() + 7) / 8, 0);
    for (size_t i = 0; i < bits.size(); i++) {
        if (bits[i]) {
            bytes[i/8] |= (1 << (i % 8));
        }
    }
    return bytes;
}

bool simulate_communication_error(double failure_rate) {
    std::uniform_real_distribution<> dis(0.0, 1.0);
    return dis(gen) < failure_rate;
}

bool simulate_timeout(int operation_time_ms, int timeout_ms) {
    return operation_time_ms > timeout_ms;
}

// Direct signal access functions
void drive_jtag_pins(svBit tck_val, svBit tms_val, svBit tdi_val) {
    printf("C++ DEBUG: drive_jtag_pins - TCK=%d, TMS=%d, TDI=%d\n", (int)tck_val, (int)tms_val, (int)tdi_val);
    fflush(stdout);
    sv_drive_jtag_pins(tck_val, tms_val, tdi_val);
}

void read_jtag_pins(svBit* tdo_val) {
    *tdo_val = sv_get_tdo();
    printf("C++ DEBUG: read_jtag_pins - TDO=%d\n", (int)*tdo_val);
    fflush(stdout);
}

void wait_cycles(int cycles) {
    printf("C++ DEBUG: wait_cycles - %d cycles\n", cycles);
    fflush(stdout);
    sv_wait_cycles(cycles);
}

// TAP navigation helpers
void tap_reset() {
    printf("TAP_RESET: Starting TAP reset sequence\n");
    fflush(stdout);
    // Send 5 TMS=1 to ensure Test-Logic-Reset state
    for (int i = 0; i < 5; i++) {
        svBit tdo_bit = 0;
        sv_jtag_step(1, 0, 0, &tdo_bit);  // TMS=1, TDI=0
    }
    
    // Go to Run-Test-Idle
    svBit tdo_bit = 0;
    sv_jtag_step(0, 0, 0, &tdo_bit);  // TMS=0, TDI=0
    printf("TAP_RESET: Reset sequence completed\n");
    fflush(stdout);
}

void navigate_to_shift_ir() {
    printf("NAV_IR: Navigating to Shift-IR\n");
    fflush(stdout);
    // From Run-Test-Idle to Shift-IR: TMS sequence = 1,1,0,0
    std::vector<bool> tms_sequence = {1, 1, 0, 0};
    
    for (bool tms_val : tms_sequence) {
        svBit tdo_bit = 0;
        sv_jtag_step(tms_val, 0, 0, &tdo_bit);
    }
    printf("NAV_IR: Shift-IR navigation completed\n");
    fflush(stdout);
}

void navigate_to_shift_dr() {
    printf("NAV_DR: Navigating to Shift-DR\n");
    fflush(stdout);
    // From Run-Test-Idle to Shift-DR: TMS sequence = 1,0,0
    std::vector<bool> tms_sequence = {1, 0, 0};
    
    for (bool tms_val : tms_sequence) {
        svBit tdo_bit = 0;
        sv_jtag_step(tms_val, 0, 0, &tdo_bit);
    }
    printf("NAV_DR: Shift-DR navigation completed\n");
    fflush(stdout);
}

void navigate_to_shift_dr_with_idle() {
    printf("NAV_DR_IDLE: Navigating to Shift-DR with extra idle cycle\n");
    fflush(stdout);
    
    // From Run-Test-Idle: TMS=1 -> Select-DR-Scan -> TMS=1 -> Capture-DR -> TMS=0 -> Shift-DR
    // But first, ensure we're in Run-Test-Idle with one extra cycle for IR to settle
    svBit tdo_bit = 0;
    sv_jtag_step(0, 0, 0, &tdo_bit);  // Extra idle cycle after Update-IR
    
    std::vector<bool> tms_sequence = {1, 0, 0};
    
    for (bool tms_val : tms_sequence) {
        sv_jtag_step(tms_val, 0, 0, &tdo_bit);
    }
    printf("NAV_DR_IDLE: Shift-DR navigation with idle completed\n");
    fflush(stdout);
}

void exit_to_run_test_idle() {
    printf("EXIT_IDLE: Exiting to Run-Test-Idle\n");
    fflush(stdout);
    // From Exit1-* -> Update-* (TMS=1), then -> Run-Test/Idle (TMS=0)
    svBit tdo_bit = 0;
    sv_jtag_step(1, 0, 0, &tdo_bit);
    sv_jtag_step(0, 0, 0, &tdo_bit);
    printf("EXIT_IDLE: Exit to Run-Test-Idle completed\n");
    fflush(stdout);
}

// Core Digilent JTAG API implementation
extern "C" {

int djtg_enable(int hif) {
    // Simulate potential communication failure
    if (simulate_communication_error()) {
        std::cout << "MOCK: Communication error during enable" << std::endl;
        return FALSE;
    }
    
    device_registry[hif] = JtagDevice();
    device_registry[hif].enabled = true;
    
    printf("MOCK: Device %d enabled successfully\n", hif);
    fflush(stdout);
    return TRUE;
}

int djtg_disable(int hif) {
    auto it = device_registry.find(hif);
    if (it == device_registry.end() || !it->second.enabled) {
        printf("MOCK: Device %d not found or already disabled\n", hif);
        fflush(stdout);
        return FALSE;
    }
    
    it->second.enabled = false;
    printf("MOCK: Device %d disabled\n", hif);
    fflush(stdout);
    return TRUE;
}

int djtg_put_tms_tdi_bits(int hif, const svOpenArrayHandle tms_data,
                          const svOpenArrayHandle tdi_data,
                          const svOpenArrayHandle tdo_data,
                          int cbit, svBit overlap) {
    auto it = device_registry.find(hif);
    if (it == device_registry.end() || !it->second.enabled) {
        printf("MOCK: Device %d not enabled\n", hif);
        fflush(stdout);
        return FALSE;
    }
    
    // Simulate timeout for very large operations
    int operation_time = cbit / 1000;  // Rough time estimate
    if (simulate_timeout(operation_time, it->second.timeout_ms)) {
        printf("MOCK: Timeout during %d bit operation\n", cbit);
        fflush(stdout);
        return FALSE;
    }
    
    printf("MOCK: Processing %d JTAG bits\n", cbit);
    fflush(stdout);
    
    // Clear TDO data array
    int byte_count = (cbit + 7) / 8;
    char* tdo_ptr = (char*)svGetArrayPtr(tdo_data);
    for (int i = 0; i < byte_count; i++) {
        tdo_ptr[i] = 0;
    }
    
    // Process each bit via single SV step for correct timing
    for (int bit_idx = 0; bit_idx < cbit; bit_idx++) {
        int byte_idx = bit_idx / 8;
        int bit_pos = bit_idx % 8;
        svBit tms_bit = (((char*)svGetArrayPtr(tms_data))[byte_idx] >> bit_pos) & 1;
        svBit tdi_bit = (((char*)svGetArrayPtr(tdi_data))[byte_idx] >> bit_pos) & 1;
        svBit is_last = (bit_idx == cbit - 1) ? 1 : 0;
        svBit tdo_bit = 0;
        sv_jtag_step(tms_bit, tdi_bit, is_last, &tdo_bit);
        if (tdo_bit) {
            tdo_ptr[byte_idx] |= (1 << bit_pos);
        }
    }
    
    return TRUE;
}

int djtg_get_tms_tdi_tdo_bits(int hif, const svOpenArrayHandle tms_data,
                              const svOpenArrayHandle tdi_data,
                              const svOpenArrayHandle tdo_data,
                              int cbit, svBit overlap) {
    // For this mock, get and put operations are identical
    return djtg_put_tms_tdi_bits(hif, tms_data, tdi_data, tdo_data, cbit, overlap);
}

int djtg_set_tms_tdi_tck(int hif, svBit tms, svBit tdi, svBit tck) {
    auto it = device_registry.find(hif);
    if (it == device_registry.end() || !it->second.enabled) {
        return FALSE;
    }
    
    it->second.tms_state = tms;
    it->second.tdi_state = tdi;
    it->second.tck_state = tck;
    
    // Drive RTL directly
    drive_jtag_pins(tck, tms, tdi);
    
    return TRUE;
}

int djtg_get_tms_tdi_tdo_tck(int hif, svBit* tms, svBit* tdi, svBit* tdo, svBit* tck) {
    auto it = device_registry.find(hif);
    if (it == device_registry.end() || !it->second.enabled) {
        return FALSE;
    }
    
    *tms = it->second.tms_state;
    *tdi = it->second.tdi_state;
    *tck = it->second.tck_state;
    
    // Read TDO from RTL
    read_jtag_pins(tdo);
    it->second.tdo_state = *tdo;
    
    return TRUE;
}

int djtg_set_speed(int hif, int freq_req, int* freq_set) {
    auto it = device_registry.find(hif);
    if (it == device_registry.end() || !it->second.enabled) {
        return FALSE;
    }
    
    // Simulate frequency limitations of real hardware
    int max_freq = 50000000;  // 50 MHz realistic limit
    int min_freq = 1000;      // 1 kHz minimum
    
    int actual_freq = freq_req;
    if (freq_req > max_freq) {
        actual_freq = max_freq;
        printf("MOCK: Frequency limited to maximum: %d Hz\n", max_freq);
        fflush(stdout);
    } else if (freq_req < min_freq) {
        actual_freq = min_freq;
        printf("MOCK: Frequency raised to minimum: %d Hz\n", min_freq);
        fflush(stdout);
    }
    
    it->second.clock_freq = actual_freq;
    *freq_set = actual_freq;
    
    printf("MOCK: JTAG clock frequency set to %d Hz\n", actual_freq);
    fflush(stdout);
    return TRUE;
}

int djtg_get_speed(int hif, int* freq_cur) {
    auto it = device_registry.find(hif);
    if (it == device_registry.end() || !it->second.enabled) {
        return FALSE;
    }
    
    *freq_cur = it->second.clock_freq;
    return TRUE;
}

} // extern "C"