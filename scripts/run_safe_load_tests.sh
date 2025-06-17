#!/bin/bash
#
# Safe Load Testing Script for MAYA
# 
# This script runs load tests with memory constraints and automatic cleanup
# to prevent system crashes.

set -euo pipefail

# Configuration
MAX_MEMORY_PERCENT=80  # Maximum memory usage percentage
TEST_DURATION=30       # Duration per test in seconds
MEMORY_CHECK_INTERVAL=5 # Check memory every N seconds

# Get the project root directory
PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$PROJECT_ROOT"

# Log file for test output
LOG_FILE="tests/results/load_tests_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$(dirname "$LOG_FILE")"

# Function to log messages
log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $*" | tee -a "$LOG_FILE"
}

# Function to check available memory
check_memory() {
    local total_mem available_mem used_percent
    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    available_mem=$(free -m | awk '/^Mem:/{print $7}')
    used_percent=$(( (total_mem - available_mem) * 100 / total_mem ))
    
    echo "Memory: ${used_percent}% used (${available_mem}MB free)"
    
    if [ "$used_percent" -gt "$MAX_MEMORY_PERCENT" ]; then
        log "WARNING: Memory usage exceeds ${MAX_MEMORY_PERCENT}%"
        return 1
    fi
    return 0
}

# Function to run a single test with memory monitoring
run_safe_test() {
    local test_name=$1
    shift
    local test_cmd=("$@")
    
    log "Starting test: ${test_name}"
    log "Command: ${test_cmd[*]}"
    
    # Start the test in the background
    "${test_cmd[@]}" >> "$LOG_FILE" 2>&1 &
    local test_pid=$!
    
    # Monitor memory usage
    local start_time=$SECONDS
    local elapsed=0
    
    while kill -0 $test_pid 2>/dev/null; do
        elapsed=$((SECONDS - start_time))
        
        # Check memory usage
        if ! check_memory >> "$LOG_FILE" 2>&1; then
            log "Memory limit exceeded, terminating test..."
            kill -TERM $test_pid 2>/dev/null || true
            wait $test_pid 2>/dev/null || true
            return 1
        fi
        
        # Check if test duration exceeded
        if [ "$elapsed" -gt "$TEST_DURATION" ]; then
            log "Test duration (${TEST_DURATION}s) exceeded, terminating..."
            kill -TERM $test_pid 2>/dev/null || true
            wait $test_pid 2>/dev/null || true
            return 0
        fi
        
        sleep $MEMORY_CHECK_INTERVAL
    done
    
    # Get exit status
    wait $test_pid
    local status=$?
    
    if [ $status -eq 0 ]; then
        log "Test completed successfully"
    else
        log "Test failed with status $status"
    fi
    
    return $status
}

# Main execution
main() {
    log "=== Starting MAYA Safe Load Tests ==="
    log "Max memory usage: ${MAX_MEMORY_PERCENT}%"
    log "Test duration: ${TEST_DURATION} seconds per test"
    log "Log file: ${LOG_FILE}"
    
    # Check Python environment
    if [ -z "$VIRTUAL_ENV" ]; then
        if [ -d ".venv" ]; then
            log "Activating virtual environment..."
            source .venv/bin/activate
        else
            log "Error: Virtual environment not found"
            exit 1
        fi
    fi
    
    # Install test dependencies
    log "Installing test dependencies..."
    pip install -q -r requirements-learn.txt
    
    # Run the load tests with memory safety
    log "Starting load tests..."
    
    # Run CPU load tests
    for load in 25 50 75; do
        run_safe_test "CPU Load ${load}%" \
            python -c "while True: [i*i for i in range(1000000)]"
    done
    
    # Run memory load tests (with smaller chunks)
    for load in 25 50; do
        run_safe_test "Memory Load ${load}%" \
            python -c "
import time
chunk_size = 10 * 1024 * 1024  # 10MB chunks
total_mb = $(($(free -m | awk '/^Mem:/{print int($2*'$load'/100)}') / 2))  # Half of target to be safe
chunks = []
print(f'Allocating {total_mb}MB...')
try:
    for _ in range(total_mb // 10):
        chunks.append(' ' * chunk_size)
        print(f'Allocated {(len(chunks)*10)}MB', end='\r')
        time.sleep(0.1)
    print('\nHolding memory...')
    time.sleep(30)
except MemoryError:
    print('\nMemory limit reached!')
"
    done
    
    log "All tests completed"
    log "Test results saved to: ${LOG_FILE}"
}

# Run the main function
main "$@"
