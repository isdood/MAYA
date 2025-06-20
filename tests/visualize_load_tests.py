
#!/usr/bin/env python3
"""
Visualize load test results.

This script generates visualizations from the load test results.
"""

import json
import glob
from pathlib import Path
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns
from typing import List, Dict, Any
import numpy as np
import os

# Configure matplotlib
plt.style.use('seaborn')
sns.set_palette("husl")

def load_results(results_dir: str = "tests/results/load_tests") -> List[Dict]:
    """Load all load test results."""
    results = []
    for result_file in glob.glob(f"{results_dir}/load_test_results_*.json"):
        try:
            with open(result_file, 'r') as f:
                data = json.load(f)
                data["file"] = result_file
                results.append(data)
        except (json.JSONDecodeError, FileNotFoundError) as e:
            print(f"Error loading {result_file}: {e}")
    return results

def create_metric_plots(results: List[Dict], output_dir: str = "docs/performance/load_test_plots"):
    """Create plots for different metrics."""
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    # Extract all test results
    all_tests = []
    for result in results:
        for test in result.get("results", []):
            test["timestamp"] = result.get("timestamp")
            test["system_info"] = result.get("system_info", {})
            all_tests.append(test)
    
    if not all_tests:
        print("No test results found!")
        return
    
    # Convert to DataFrame
    df = pd.DataFrame(all_tests)
    
    # Plot CPU Usage vs Load
    plot_metric_vs_load(
        df[df['test_name'].str.startswith('cpu_')], 
        'load_level', 
        'metrics.avg_cpu_usage', 
        'CPU Load (%)', 
        'Average CPU Usage (%)',
        f"{output_dir}/cpu_usage_vs_load.png"
    )
    
    # Plot Memory Usage vs Load
    plot_metric_vs_load(
        df[df['test_name'].str.startswith('memory_')], 
        'load_level', 
        'metrics.avg_memory_usage', 
        'Memory Load (%)', 
        'Average Memory Usage (%)',
        f"{output_dir}/memory_usage_vs_load.png"
    )
    
    # Plot Response Time vs Load
    plot_metric_vs_load(
        df, 
        'load_level', 
        'metrics.avg_response_time_ms', 
        'Load Level', 
        'Average Response Time (ms)',
        f"{output_dir}/response_time_vs_load.png"
    )
    
    # Plot I/O Throughput
    plot_io_throughput(df, f"{output_dir}/io_throughput.png")
    
    # Plot Network Throughput
    plot_network_throughput(df, f"{output_dir}/network_throughput.png")
    
    # Generate HTML report
    generate_html_report(df, output_dir)

def plot_metric_vs_load(df: pd.DataFrame, x_col: str, y_col: str, 
                       x_label: str, y_label: str, output_file: str):
    """Plot a metric vs load level."""
    if df.empty:
        print(f"No data to plot for {output_file}")
        return
    
    plt.figure(figsize=(12, 6))
    
    # Group by test type
    for test_type in df['test_name'].unique():
        test_df = df[df['test_name'] == test_type].copy()
        test_df.sort_values(x_col, inplace=True)
        
        # Plot mean and std
        plt.plot(
            test_df[x_col] * 100,  # Convert to percentage
            test_df[y_col],
            'o-',
            label=test_type.replace('_', ' ').title()
        )
    
    plt.xlabel(x_label)
    plt.ylabel(y_label)
    plt.title(f'{y_label} vs {x_label}')
    plt.grid(True)
    plt.legend()
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Saved plot: {output_file}")

def plot_io_throughput(df: pd.DataFrame, output_file: str):
    """Plot I/O throughput metrics."""
    io_tests = df[df['test_name'].str.startswith('io_')]
    if io_tests.empty:
        print("No I/O test data available")
        return
    
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))
    
    # Plot read throughput
    ax1.plot(
        io_tests['load_level'] * 100,
        io_tests['system_metrics'].apply(lambda x: x.get('io_read_mb', 0)),
        'o-',
        label='Read Throughput'
    )
    ax1.set_xlabel('I/O Load Level (%)')
    ax1.set_ylabel('Read Throughput (MB)')
    ax1.set_title('Read Throughput vs I/O Load')
    ax1.grid(True)
    
    # Plot write throughput
    ax2.plot(
        io_tests['load_level'] * 100,
        io_tests['system_metrics'].apply(lambda x: x.get('io_write_mb', 0)),
        'o-',
        color='orange',
        label='Write Throughput'
    )
    ax2.set_xlabel('I/O Load Level (%)')
    ax2.set_ylabel('Write Throughput (MB)')
    ax2.set_title('Write Throughput vs I/O Load')
    ax2.grid(True)
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Saved plot: {output_file}")

def plot_network_throughput(df: pd.DataFrame, output_file: str):
    """Plot network throughput metrics."""
    net_tests = df[df['test_name'].str.startswith('network_')]
    if net_tests.empty:
        print("No network test data available")
        return
    
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))
    
    # Plot sent data
    ax1.plot(
        net_tests['load_level'] * 100,
        net_tests['system_metrics'].apply(lambda x: x.get('network_sent_mb', 0)),
        'o-',
        label='Data Sent'
    )
    ax1.set_xlabel('Network Load Level (%)')
    ax1.set_ylabel('Data Sent (MB)')
    ax1.set_title('Data Sent vs Network Load')
    ax1.grid(True)
    
    # Plot received data
    ax2.plot(
        net_tests['load_level'] * 100,
        net_tests['system_metrics'].apply(lambda x: x.get('network_recv_mb', 0)),
        'o-',
        color='green',
        label='Data Received'
    )
    ax2.set_xlabel('Network Load Level (%)')
    ax2.set_ylabel('Data Received (MB)')
    ax2.set_title('Data Received vs Network Load')
    ax2.grid(True)
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Saved plot: {output_file}")

def generate_html_report(df: pd.DataFrame, output_dir: str):
    """Generate an HTML report with all visualizations."""
    html = f"""<!DOCTYPE html>
    <html>
    <head>
        <title>MAYA Load Test Report</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 20px; }}
            h1, h2 {{ color: #2c3e50; }}
            .plot {{ margin: 20px 0; }}
            .plot img {{ max-width: 100%; height: auto; border: 1px solid #ddd; }}
            .summary {{ 
                background-color: #f8f9fa; 
                padding: 15px; 
                border-radius: 5px;
                margin-bottom: 20px;
            }}
            .test-results {{ 
                margin-top: 30px;
                overflow-x: auto;
            }}
            table {{
                width: 100%;
                border-collapse: collapse;
                margin: 20px 0;
            }}
            th, td {{
                border: 1px solid #ddd;
                padding: 8px;
                text-align: left;
            }}
            th {{
                background-color: #f2f2f2;
            }}
            tr:nth-child(even) {{
                background-color: #f9f9f9;
            }}
        </style>
    </head>
    <body>
        <h1>MAYA Load Test Report</h1>
        <div class="summary">
            <h2>Summary</h2>
            <p><strong>Total Tests:</strong> {total_tests}</p>
            <p><strong>Test Types:</strong> {test_types}</p>
            <p><strong>Date Range:</strong> {date_range}</p>
        </div>
        
        <h2>Performance Plots</h2>
        <div class="plot">
            <h3>CPU Usage</h3>
            <img src="cpu_usage_vs_load.png" alt="CPU Usage vs Load">
        </div>
        
        <div class="plot">
            <h3>Memory Usage</h3>
            <img src="memory_usage_vs_load.png" alt="Memory Usage vs Load">
        </div>
        
        <div class="plot">
            <h3>Response Time</h3>
            <img src="response_time_vs_load.png" alt="Response Time vs Load">
        </div>
        
        <div class="plot">
            <h3>I/O Throughput</h3>
            <img src="io_throughput.png" alt="I/O Throughput">
        </div>
        
        <div class="plot">
            <h3>Network Throughput</h3>
            <img src="network_throughput.png" alt="Network Throughput">
        </div>
        
        <div class="test-results">
            <h2>Detailed Test Results</h2>
            {results_table}
        </div>
    </body>
    </html>
    """
    
    # Generate results table
    if not df.empty:
        # Create a simplified view of the results
        simple_df = df.copy()
        simple_df['avg_response_ms'] = simple_df['metrics'].apply(lambda x: x.get('avg_response_time_ms', 0))
        simple_df['avg_cpu'] = simple_df['metrics'].apply(lambda x: x.get('avg_cpu_usage', 0))
        simple_df['avg_memory'] = simple_df['metrics'].apply(lambda x: x.get('avg_memory_usage', 0))
        
        # Format the table
        table = simple_df[[
            'test_name', 'load_level', 'avg_response_ms', 'avg_cpu', 'avg_memory'
        ]].to_html(
            index=False,
            float_format='%.2f',
            columns=['test_name', 'load_level', 'avg_response_ms', 'avg_cpu', 'avg_memory'],
            header=['Test', 'Load Level', 'Avg Response (ms)', 'Avg CPU %', 'Avg Memory %']
        )
    else:
        table = "<p>No test results available.</p>"
    
    # Fill in the template
    html = html.format(
        total_tests=len(df),
        test_types=", ".join(df['test_name'].unique()),
        date_range="N/A",  # Could be extracted from timestamps
        results_table=table
    )
    
    # Write the HTML file
    with open(f"{output_dir}/load_test_report.html", 'w') as f:
        f.write(html)
    
    print(f"Generated HTML report: {output_dir}/load_test_report.html")

def main():
    """Main function to generate visualizations."""
    print("🔍 Loading test results...")
    results = load_results()
    
    if not results:
        print("❌ No test results found. Run the load tests first.")
        return
    
    print(f"📊 Found {len(results)} test result files")
    print("🖌️  Generating visualizations...")
    
    create_metric_plots(results)
    
    print("\n🎉 Visualizations generated successfully!")
    print(f"📂 Open docs/performance/load_test_plots/load_test_report.html to view the report")

if __name__ == "__main__":
    main()
