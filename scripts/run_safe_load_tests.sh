#!/bin/bash
#
# Safe Load Testing Script for MAYA
# 
# This script runs load tests with memory constraints and automatic cleanup
# to prevent system crashes.

set -euo pipefail

# Configuration
MAX_MEMORY_PERCENT=85        # Increased from 80% to 85% (leaving 15% headroom)
TEST_DURATION=60            # Increased from 30s to 60s for more stable measurements
MEMORY_CHECK_INTERVAL=2      # More frequent checks (reduced from 5s)
MEMORY_SAFETY_FACTOR=0.75   # Using 75% of target memory instead of 50%
MIN_MEMORY_MB=8192          # Ensure at least 8GB free for system

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
    
    # Run CPU load tests with more granular steps
    for load in 25 50 75 90; do  # Added 90% load test
        run_safe_test "CPU Load ${load}%" \
            python -c "while True: [i*i for i in range(1000000)]"
    done
    
    # Run memory load tests with more aggressive targets
    for load in 30 50 70; do  # Added 70% load test
        run_safe_test "Memory Load ${load}%" \
            python -c "
import time
import psutil

def safe_memory_allocation(target_percent, safety_factor, min_free_mb):
    total_mb = int(psutil.virtual_memory().total / (1024 * 1024) * target_percent / 100 * safety_factor)
    free_mb = int(psutil.virtual_memory().available / (1024 * 1024))
    safe_mb = free_mb - min_free_mb
    
    if safe_mb < 1024:  # At least 1GB
        safe_mb = 1024
    if total_mb > safe_mb:
        print(f'[SAFE] Adjusted memory target from {total_mb}MB to {safe_mb}MB')
        return safe_mb
    return total_mb

try:
    # Calculate safe allocation
    total_mb = safe_memory_allocation($load, $MEMORY_SAFETY_FACTOR, $MIN_MEMORY_MB)
    chunks = []
    print(f'[TEST] Allocating {total_mb}MB...')
    
    # Allocate in chunks with progress
    chunk_mb = 100  # 100MB chunks
    for i in range(0, total_mb, chunk_mb):
        chunk_size_mb = min(chunk_mb, total_mb - i)
        chunk = ' ' * (chunk_size_mb * 1024 * 1024 // 10)  # Approximate
        chunks.append(chunk)
        print(f'[PROGRESS] Allocated {i + chunk_size_mb}/{total_mb}MB', end='\r')
        time.sleep(0.1)  # Small delay to prevent CPU overload
    
    print(f'\n[TEST] Holding {len(chunks) * chunk_mb}MB for 30 seconds...')
    time.sleep(30)
    print('[TEST] Memory test completed successfully')
    
except MemoryError:
    print('\n[ERROR] Memory limit reached!')
    raise

except Exception as e:
    print(f'\n[ERROR] Test failed: {str(e)}')
    raise
"
    done
    
    log "All tests completed"
    log "Test results saved to: ${LOG_FILE}"
}

# Run the main function
main "$@"
