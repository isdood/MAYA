@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-17 16:17:59",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./scripts/run_load_tests.sh",
    "type": "sh",
    "hash": "07e9a6ea63504f57acd766a98671cab809567b21"
  }
}
@pattern_meta@

#!/bin/bash
#
# Run MAYA load tests and generate reports
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
RESULTS_DIR="tests/results/load_tests"
mkdir -p "$RESULTS_DIR"

# Run load tests
echo -e "\n🚀 Starting MAYA Load Testing Suite"
echo "="*50

PYTHONPATH="$PROJECT_ROOT" python -m tests.benchmarks.test_under_load

# Generate visualizations
echo -e "\n🖌️  Generating visualizations..."
PYTHONPATH="$PROJECT_ROOT" python tests/visualize_load_tests.py

# Print summary
echo -e "\n✅ Load testing complete!"
echo -e "📊 Results saved to: $RESULTS_DIR"
echo -e "📈 Visualizations saved to: docs/performance/load_test_plots/"
echo -e "🌐 Open docs/performance/load_test_plots/load_test_report.html to view the full report"

# Open the report in the default browser
if command -v xdg-open &> /dev/null; then
    xdg-open "docs/performance/load_test_plots/load_test_report.html"
elif command -v open &> /dev/null; then
    open "docs/performance/load_test_plots/load_test_report.html"
fi
