#!/bin/bash
#
# Run MAYA performance tests and generate a report
#

set -e

# Get the project root directory
PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$PROJECT_ROOT"

# Ensure virtual environment is activated
if [ -z "$VIRTUAL_ENV" ]; then
    if [ -d ".venv" ]; then
        echo "Activating virtual environment..."
        source .venv/bin/activate
    else
        echo "Error: Virtual environment not found. Please set up the project first."
        exit 1
    fi
fi

# Install test dependencies if needed
echo "Installing test dependencies..."
pip install -q -r requirements-learn.txt

# Create results directory
RESULTS_DIR="tests/results"
mkdir -p "$RESULTS_DIR"

# Run performance tests
echo "\nRunning performance tests..."
PYTHONPATH="$PROJECT_ROOT" python -m tests.benchmarks.test_monitoring_performance

# Generate report
echo -e "\nGenerating performance report..."
PYTHONPATH="$PROJECT_ROOT" python tests/generate_performance_report.py

# Print the location of the generated report
REPORT_FILE=$(find docs/performance -name "performance_report_*.md" | sort -r | head -1)
if [ -n "$REPORT_FILE" ]; then
    echo -e "\n✅ Performance report generated: $REPORT_FILE"
    echo -e "\nTo view the report, run:"
    echo "  cat $REPORT_FILE"
    echo -e "\nOr open it in your default markdown viewer."
else
    echo "Error: Failed to generate performance report."
    exit 1
fi
