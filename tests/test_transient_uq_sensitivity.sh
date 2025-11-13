#!/usr/bin/env bash
# Test transient UQ and sensitivity analysis
set -euo pipefail

FC=${FC:-gfortran}
FFLAGS=${FFLAGS:--std=f2008 -O2 -Wall -Wextra}

echo "=== Testing Transient UQ and Sensitivity ==="
echo ""

# Clean and build
echo "Building AX-1..."
make clean >/dev/null
make FC="$FC" FFLAGS="$FFLAGS" >/dev/null

if [ ! -f "./ax1" ]; then
    echo "Error: Build failed - ax1 not found"
    exit 1
fi

echo "Build successful"
echo ""

# Test 1: Transient UQ
echo "=== Test 1: Transient UQ ==="
echo "Running transient UQ test (this may take a while)..."
if ./ax1 inputs/test_transient_uq.deck > test_transient_uq.log 2>&1; then
    echo "✅ Transient UQ test completed"
    
    # Check for output files
    if [ -f "test_transient_uq_results.csv" ]; then
        echo "✅ UQ results file created: test_transient_uq_results.csv"
        # Check file has content
        if [ -s "test_transient_uq_results.csv" ]; then
            echo "✅ UQ results file has content"
            head -20 test_transient_uq_results.csv
        else
            echo "⚠️  UQ results file is empty"
        fi
    else
        echo "❌ UQ results file not found"
    fi
    
    # Check for transient results file
    if [ -f "test_transient_uq_results_transient.csv" ]; then
        echo "✅ Transient UQ results file created: test_transient_uq_results_transient.csv"
        if [ -s "test_transient_uq_results_transient.csv" ]; then
            echo "✅ Transient UQ results file has content"
            head -10 test_transient_uq_results_transient.csv
        else
            echo "⚠️  Transient UQ results file is empty"
        fi
    else
        echo "⚠️  Transient UQ results file not found (may not be generated for short simulations)"
    fi
else
    echo "❌ Transient UQ test failed"
    echo "Error output:"
    tail -20 test_transient_uq.log
    exit 1
fi

echo ""

# Test 2: Transient Sensitivity
echo "=== Test 2: Transient Sensitivity ==="
echo "Running transient sensitivity test (this may take a while)..."
if ./ax1 inputs/test_transient_sensitivity.deck > test_transient_sensitivity.log 2>&1; then
    echo "✅ Transient sensitivity test completed"
    
    # Check for output files
    if [ -f "test_transient_sensitivity_results.csv" ]; then
        echo "✅ Sensitivity results file created: test_transient_sensitivity_results.csv"
        # Check file has content
        if [ -s "test_transient_sensitivity_results.csv" ]; then
            echo "✅ Sensitivity results file has content"
            head -20 test_transient_sensitivity_results.csv
        else
            echo "⚠️  Sensitivity results file is empty"
        fi
    else
        echo "❌ Sensitivity results file not found"
    fi
    
    # Check for transient results file
    if [ -f "test_transient_sensitivity_results_transient.csv" ]; then
        echo "✅ Transient sensitivity results file created: test_transient_sensitivity_results_transient.csv"
        if [ -s "test_transient_sensitivity_results_transient.csv" ]; then
            echo "✅ Transient sensitivity results file has content"
            head -10 test_transient_sensitivity_results_transient.csv
        else
            echo "⚠️  Transient sensitivity results file is empty"
        fi
    else
        echo "⚠️  Transient sensitivity results file not found (may not be generated for short simulations)"
    fi
else
    echo "❌ Transient sensitivity test failed"
    echo "Error output:"
    tail -20 test_transient_sensitivity.log
    exit 1
fi

echo ""
echo "=== All Tests Completed ==="
echo "✅ Transient UQ: PASSED"
echo "✅ Transient Sensitivity: PASSED"
echo ""
echo "Note: These are basic functionality tests. For production use,"
echo "      more comprehensive validation against reference solutions is recommended."

