#!/usr/bin/env bash
# Benchmark runner script for AX-1 Phase 2
# Runs all benchmark problems and generates summary report

set -euo pipefail

BENCH_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$BENCH_DIR")"

cd "$PROJECT_ROOT" || exit 1

echo "======================================================================"
echo "AX-1 Phase 2 Benchmark Suite"
echo "======================================================================"
echo ""

# Ensure the code is built
if [ ! -f ax1 ]; then
    echo "Building AX-1..."
    make -s
fi

# Create results directory
RESULTS_DIR="benchmarks/results"
mkdir -p "$RESULTS_DIR"
timestamp=$(date +%Y%m%d_%H%M%S)
results_file="$RESULTS_DIR/benchmark_results_$timestamp.txt"

{
    echo "AX-1 Phase 2 Benchmark Results"
    echo "Generated: $(date)"
    echo "======================================================================"
    echo ""
} | tee "$results_file"

# Run benchmarks
run_benchmark() {
    local name=$1
    local deck=$2
    local expected_feature=$3
    
    echo "Running benchmark: $name"
    echo "  Deck: $deck"
    echo "  Feature: $expected_feature"
    
    local output_file="$RESULTS_DIR/${name// /_}.out"
    local start_time=$(date +%s)
    
    ./ax1 "benchmarks/$deck" > "$output_file" 2>&1 || {
        echo "  ERROR: Benchmark failed"
        return 1
    }
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Extract key metrics
    local final_time=$(grep "^t=" "$output_file" | tail -1 | awk '{print $1}' | tr -d 't=')
    local final_keff=$(grep "^t=" "$output_file" | tail -1 | awk '{print $5}' | tr -d 'keff=')
    local transport_iters=$(grep "Total transport iterations" "$output_file" | awk '{print $4}')
    local dsa_iters=$(grep "DSA iterations" "$output_file" | awk '{print $4}')
    
    {
        echo "  Duration: ${duration}s"
        echo "  Final time: $final_time"
        echo "  Final keff: $final_keff"
        echo "  Transport iterations: $transport_iters"
        echo "  DSA iterations: $dsa_iters"
        echo ""
    } | tee -a "$results_file"
}

# Run all benchmarks
run_benchmark "Godiva Criticality" \
    "godiva_criticality.deck" \
    "S8 quadrature, DSA, alpha-eigenvalue"

run_benchmark "SOD Shock Tube" \
    "sod_shock_tube.deck" \
    "HLLC Riemann solver, slope limiting"

run_benchmark "Upscatter Treatment" \
    "upscatter_treatment.deck" \
    "Upscatter control (allow mode)"

run_benchmark "DSA Convergence" \
    "dsa_convergence.deck" \
    "DSA acceleration"

echo "======================================================================"
echo "All benchmarks completed"
echo "======================================================================"
echo ""
echo "Results saved to: $results_file"
echo "Individual outputs in: $RESULTS_DIR/"
echo ""
echo "To compare DSA effectiveness, run:"
echo "  ./ax1 benchmarks/dsa_convergence.deck"
echo ""
echo "Then edit the deck to set use_dsa false and run again."
echo ""
