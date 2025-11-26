#!/usr/bin/env python3
"""
Compare AX-1 Geneva 10 simulation results with 1959 ANL-5977 reference data.
Generates comparison plots and tables.
"""

import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
from pathlib import Path

# Set up matplotlib for LaTeX-style fonts
plt.rcParams.update({
    'text.usetex': False,  # Use mathtext instead of full LaTeX
    'font.family': 'serif',
    'font.serif': ['Times New Roman', 'Times', 'DejaVu Serif'],
    'mathtext.fontset': 'cm',  # Computer Modern (LaTeX-like)
    'axes.labelsize': 11,
    'axes.titlesize': 12,
    'xtick.labelsize': 10,
    'ytick.labelsize': 10,
    'legend.fontsize': 9,
    'figure.titlesize': 13,
})

# =============================================================================
# Reference data from ANL-5977 (1959) Geneva 10 problem
# =============================================================================

ref_1959_time = np.array([
    0.0, 132.0, 210.0, 240.0, 262.0, 270.0, 274.0, 280.0, 282.0, 284.0,
    286.0, 288.0, 290.0, 292.0, 294.0, 295.0, 295.5, 296.0, 296.5, 297.0,
    297.5, 298.0, 298.5, 299.0, 299.5, 300.0,
])

ref_1959_QP = np.array([
    3484.515, 3842.258, 4614.118, 5194.141, 5790.050, 6052.932, 6194.982,
    6422.045, 6501.495, 6582.751, 6665.751, 6750.404, 6836.587, 6924.139,
    7012.855, 7057.554, 7079.975, 7102.438, 7124.940, 7147.474, 7170.036,
    7192.619, 7215.218, 7237.827, 7260.439, 7283.048,
])

ref_1959_power = np.array([
    1.0, 5.617822, 15.58345, 23.07269, 30.76770, 34.16063, 35.97139,
    38.80450, 39.72579, 40.62824, 41.50012, 42.32701, 43.09212, 43.77629,
    44.35807, 44.69970, 44.84325, 44.92919, 45.00503, 45.07040, 45.12488,
    45.16808, 45.19958, 45.21895, 45.22577, 45.21964,
])

ref_1959_alpha = np.array([
    0.013084, 0.01307967, 0.01308135, 0.01308255, 0.01307606, 0.01291253,
    0.01263538, 0.01173227, 0.01123132, 0.01061646, 0.00986464, 0.00895733,
    0.00787613, 0.00660121, 0.00511474, 0.00427507, 0.00382939, 0.00337305,
    0.00290279, 0.00241626, 0.00191396, 0.00139451, 0.00085673, 0.00030183,
    -0.00027106, -0.00086276,
])

ref_1959_W = np.array([
    0.0, 0.03390, 0.07019, 0.09746, 0.13505, 0.15616, 0.16737, 0.19287,
    0.19803, 0.19194, 0.19578, 0.19961, 0.21781, 0.22937, 0.21921, 0.08428,
    0.03102, 0.02742, 0.03258, 0.03735, 0.04068, 0.04233, 0.04214, 0.04009,
    0.03625, 0.03206,
])

# =============================================================================
# Load simulation data
# =============================================================================

def load_simulation_data(csv_file):
    """Load simulation data from CSV file."""
    df = pd.read_csv(csv_file)
    df.columns = df.columns.str.strip()
    return df

# =============================================================================
# Plotting functions
# =============================================================================

def plot_combined_comparison(ref_time, ref_QP, ref_power, ref_alpha, ref_W,
                             sim_time, sim_QP, sim_power, sim_alpha, sim_W,
                             output_file):
    """Create a 2x2 subplot with all comparisons - publication quality."""
    
    # Smaller figure for larger relative fonts
    fig, axes = plt.subplots(2, 2, figsize=(6.5, 5.5))
    
    # Colors
    ref_color = '#1f77b4'  # Blue
    sim_color = '#d62728'  # Red
    
    # (a) QP - Total Energy
    ax = axes[0, 0]
    ax.plot(ref_time, ref_QP, 'o', color=ref_color, markersize=4, 
            label='1959 Reference', markerfacecolor='none', markeredgewidth=1)
    ax.plot(sim_time, sim_QP, '-', color=sim_color, linewidth=1, label='Simulation')
    ax.set_xlabel(r'Time ($\mu$s)')
    ax.set_ylabel(r'$Q_P$ ($10^{12}$ erg)')
    ax.set_title('(a) Total Energy', fontsize=11, loc='left')
    ax.legend(loc='upper left', framealpha=0.9)
    ax.set_xlim(0, 300)
    
    # (b) Power
    ax = axes[0, 1]
    ax.semilogy(ref_time[1:], ref_power[1:], 'o', color=ref_color, markersize=4,
                label='1959 Reference', markerfacecolor='none', markeredgewidth=1)
    ax.semilogy(sim_time, sim_power, '-', color=sim_color, linewidth=1, label='Simulation')
    ax.set_xlabel(r'Time ($\mu$s)')
    ax.set_ylabel(r'Relative Power')
    ax.set_title('(b) Power', fontsize=11, loc='left')
    ax.legend(loc='upper left', framealpha=0.9)
    ax.set_xlim(0, 300)
    
    # (c) Alpha
    ax = axes[1, 0]
    ax.plot(ref_time, ref_alpha * 1000, 'o', color=ref_color, markersize=4,
            label='1959 Reference', markerfacecolor='none', markeredgewidth=1)
    ax.plot(sim_time, sim_alpha * 1000, '-', color=sim_color, linewidth=1, label='Simulation')
    ax.axhline(y=0, color='gray', linestyle='-', linewidth=0.5)
    ax.set_xlabel(r'Time ($\mu$s)')
    ax.set_ylabel(r'$\alpha$ ($10^{-3}$ $\mu$s$^{-1}$)')
    ax.set_title(r'(c) Inverse Period $\alpha$', fontsize=11, loc='left')
    ax.legend(loc='upper right', framealpha=0.9)
    ax.set_xlim(0, 300)
    
    # (d) W - skip initial jump by filtering sim_time > 50
    ax = axes[1, 1]
    ax.plot(ref_time, ref_W, 'o', color=ref_color, markersize=4,
            label='1959 Reference', markerfacecolor='none', markeredgewidth=1)
    # Filter W data to skip initial jump
    W_mask = sim_time > 50
    ax.plot(sim_time[W_mask], sim_W[W_mask], '-', color=sim_color, linewidth=1, label='Simulation')
    ax.axhline(y=0.3, color='orange', linestyle='--', linewidth=1, label=r'$W$ limit')
    ax.set_xlabel(r'Time ($\mu$s)')
    ax.set_ylabel(r'$W$')
    ax.set_title('(d) Stability Parameter', fontsize=11, loc='left')
    ax.legend(loc='upper left', framealpha=0.9, fontsize=8)
    ax.set_ylim(0, 0.35)
    ax.set_xlim(0, 300)
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Saved: {output_file}")

def plot_QP_comparison(ref_time, ref_QP, sim_time, sim_QP, output_file):
    """Plot total energy QP comparison."""
    fig, ax = plt.subplots(figsize=(5, 4))
    
    ax.plot(ref_time, ref_QP, 'o', color='#1f77b4', markersize=5, 
            label='1959 Reference', markerfacecolor='none', markeredgewidth=1.2)
    ax.plot(sim_time, sim_QP, '-', color='#d62728', linewidth=1.2, label='Simulation')
    
    ax.set_xlabel(r'Time ($\mu$s)')
    ax.set_ylabel(r'$Q_P$ ($10^{12}$ erg)')
    ax.legend(loc='upper left')
    ax.set_xlim(0, 300)
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Saved: {output_file}")

def plot_power_comparison(ref_time, ref_power, sim_time, sim_power, output_file):
    """Plot power comparison."""
    fig, ax = plt.subplots(figsize=(5, 4))
    
    ax.semilogy(ref_time[1:], ref_power[1:], 'o', color='#1f77b4', markersize=5,
                label='1959 Reference', markerfacecolor='none', markeredgewidth=1.2)
    ax.semilogy(sim_time, sim_power, '-', color='#d62728', linewidth=1.2, label='Simulation')
    
    ax.set_xlabel(r'Time ($\mu$s)')
    ax.set_ylabel(r'Relative Power')
    ax.legend(loc='upper left')
    ax.set_xlim(0, 300)
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Saved: {output_file}")

def plot_alpha_comparison(ref_time, ref_alpha, sim_time, sim_alpha, output_file):
    """Plot alpha comparison."""
    fig, ax = plt.subplots(figsize=(5, 4))
    
    ax.plot(ref_time, ref_alpha * 1000, 'o', color='#1f77b4', markersize=5,
            label='1959 Reference', markerfacecolor='none', markeredgewidth=1.2)
    ax.plot(sim_time, sim_alpha * 1000, '-', color='#d62728', linewidth=1.2, label='Simulation')
    ax.axhline(y=0, color='gray', linestyle='-', linewidth=0.5)
    
    ax.set_xlabel(r'Time ($\mu$s)')
    ax.set_ylabel(r'$\alpha$ ($10^{-3}$ $\mu$s$^{-1}$)')
    ax.legend(loc='upper right')
    ax.set_xlim(0, 300)
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Saved: {output_file}")

def plot_W_comparison(ref_time, ref_W, sim_time, sim_W, output_file):
    """Plot W comparison."""
    fig, ax = plt.subplots(figsize=(5, 4))
    
    ax.plot(ref_time, ref_W, 'o', color='#1f77b4', markersize=5,
            label='1959 Reference', markerfacecolor='none', markeredgewidth=1.2)
    # Skip initial jump
    W_mask = sim_time > 50
    ax.plot(sim_time[W_mask], sim_W[W_mask], '-', color='#d62728', linewidth=1.2, label='Simulation')
    ax.axhline(y=0.3, color='orange', linestyle='--', linewidth=1, label=r'$W$ limit')
    
    ax.set_xlabel(r'Time ($\mu$s)')
    ax.set_ylabel(r'$W$')
    ax.legend(loc='upper left')
    ax.set_ylim(0, 0.35)
    ax.set_xlim(0, 300)
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Saved: {output_file}")

def create_comparison_table(ref_time, ref_QP, ref_power, ref_alpha,
                            sim_time, sim_QP, sim_power, sim_alpha, output_file):
    """Create a comparison table at key time points."""
    key_times = [0, 50, 100, 150, 200, 250, 300]
    
    rows = []
    for t in key_times:
        ref_idx = np.argmin(np.abs(ref_time - t))
        sim_idx = np.argmin(np.abs(sim_time - t))
        
        if ref_idx < len(ref_time) and sim_idx < len(sim_time):
            row = {
                'Time': t,
                'Ref QP': f"{ref_QP[ref_idx]:.1f}",
                'Sim QP': f"{sim_QP[sim_idx]:.1f}",
                'Ref Power': f"{ref_power[ref_idx]:.2f}",
                'Sim Power': f"{sim_power[sim_idx]:.2f}",
                'Ref α': f"{ref_alpha[ref_idx]*1000:.3f}",
                'Sim α': f"{sim_alpha[sim_idx]*1000:.3f}",
            }
            rows.append(row)
    
    df = pd.DataFrame(rows)
    with open(output_file, 'w') as f:
        f.write("Geneva 10 Comparison: 1959 ANL-5977 vs Simulation\n")
        f.write("=" * 70 + "\n")
        f.write(df.to_string(index=False))
    print(f"Saved: {output_file}")
    return df


def plot_spatial_profiles(output_dir, output_file):
    """Plot spatial profiles at multiple times showing expansion."""
    # Load spatial data at different times
    times = [0, 100, 200, 250, 280]
    spatial_data = {}
    
    # Look in the project root (two levels up from analysis/figures)
    project_root = output_dir.parent.parent
    
    for t in times:
        csv_file = project_root / f'output_spatial_t{t}.csv'
        if csv_file.exists():
            df = pd.read_csv(csv_file)
            df.columns = df.columns.str.strip()
            spatial_data[t] = df
            print(f"Loaded spatial data for t={t}")
    
    if len(spatial_data) < 2:
        print(f"Not enough spatial data files found in {project_root}")
        return
    
    # Get initial state for computing changes
    df0 = spatial_data[0]
    
    # Create 2x2 subplot for spatial profiles
    fig, axes = plt.subplots(2, 2, figsize=(6.5, 5.5))
    
    # Color map for different times (skip t=0 for change plots)
    colors_all = plt.cm.plasma(np.linspace(0.1, 0.9, len(times)))
    colors_change = plt.cm.plasma(np.linspace(0.2, 0.9, len(times)-1))
    
    # (a) Radius change from initial (shows expansion more clearly)
    ax = axes[0, 0]
    for i, t in enumerate(times[1:]):  # Skip t=0
        if t in spatial_data:
            df = spatial_data[t]
            delta_r = df['radius_cm'].values - df0['radius_cm'].values
            ax.plot(df0['radius_cm'], delta_r, '-', color=colors_change[i], 
                    linewidth=1.5, label=f't = {t} $\\mu$s')
    ax.set_xlabel('Initial Radius (cm)')
    ax.set_ylabel(r'$\Delta R$ (cm)')
    ax.set_title('(a) Radial Expansion', fontsize=11, loc='left')
    ax.legend(loc='upper left', fontsize=7)
    ax.axhline(y=0, color='gray', linestyle='--', linewidth=0.5)
    
    # (b) Temperature vs radius - keep as is, it looks great
    ax = axes[0, 1]
    for i, t in enumerate(times):
        if t in spatial_data:
            df = spatial_data[t]
            ax.plot(df['radius_cm'], df['temperature_keV'] * 1000, '-', color=colors_all[i],
                    linewidth=1.5, label=f't = {t} $\\mu$s')
    ax.set_xlabel('Radius (cm)')
    ax.set_ylabel('Temperature (eV)')
    ax.set_title('(b) Temperature Profile', fontsize=11, loc='left')
    ax.legend(loc='upper right', fontsize=7)
    
    # (c) Density change from initial (shows compression/expansion)
    ax = axes[1, 0]
    for i, t in enumerate(times[1:]):  # Skip t=0
        if t in spatial_data:
            df = spatial_data[t]
            # Compute percent change in density
            delta_rho = 100 * (df['density_g_cm3'].values - df0['density_g_cm3'].values) / df0['density_g_cm3'].values
            ax.plot(df0['radius_cm'], delta_rho, '-', color=colors_change[i],
                    linewidth=1.5, label=f't = {t} $\\mu$s')
    ax.set_xlabel('Initial Radius (cm)')
    ax.set_ylabel(r'$\Delta\rho/\rho_0$ (%)')
    ax.set_title('(c) Density Change', fontsize=11, loc='left')
    ax.legend(loc='lower right', fontsize=7)
    ax.axhline(y=0, color='gray', linestyle='--', linewidth=0.5)
    
    # (d) Velocity vs initial radius
    ax = axes[1, 1]
    for i, t in enumerate(times[1:]):  # Skip t=0 (zero velocity)
        if t in spatial_data:
            df = spatial_data[t]
            ax.plot(df0['radius_cm'], df['velocity_cm_microsec'] * 1000, '-', color=colors_change[i],
                    linewidth=1.5, label=f't = {t} $\\mu$s')
    ax.set_xlabel('Initial Radius (cm)')
    ax.set_ylabel(r'Velocity ($10^{-3}$ cm/$\mu$s)')
    ax.set_title('(d) Velocity Profile', fontsize=11, loc='left')
    ax.legend(loc='upper left', fontsize=7)
    ax.axhline(y=0, color='gray', linestyle='--', linewidth=0.5)
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Saved: {output_file}")

# =============================================================================
# Main
# =============================================================================

if __name__ == "__main__":
    output_dir = Path(__file__).parent / "figures"
    output_dir.mkdir(parents=True, exist_ok=True)
    
    csv_file = Path(__file__).parent.parent / "output_time_series.csv"
    if csv_file.exists():
        sim_data = load_simulation_data(csv_file)
        print(f"Loaded simulation data: {len(sim_data)} time points")
        
        sim_time = sim_data['time_microsec'].values
        sim_QP = sim_data['QP_1e12_erg'].values
        sim_power = sim_data['power_relative'].values
        sim_alpha = sim_data['alpha_1_microsec'].values
        sim_W = sim_data['W_dimensionless'].values
        
        # Filter invalid points
        valid_mask = (sim_time > 1.0) & (sim_QP < 1e6) & (np.abs(sim_alpha) < 1.0) & (sim_W < 10)
        sim_time = sim_time[valid_mask]
        sim_QP = sim_QP[valid_mask]
        sim_power = sim_power[valid_mask]
        sim_alpha = sim_alpha[valid_mask]
        sim_W = sim_W[valid_mask]
        sim_W_plot = np.clip(sim_W, 0, 1.0)
        print(f"After filtering: {len(sim_time)} time points")
        
        # Generate plots
        plot_combined_comparison(ref_1959_time, ref_1959_QP, ref_1959_power, ref_1959_alpha, ref_1959_W,
                                sim_time, sim_QP, sim_power, sim_alpha, sim_W_plot,
                                output_dir / "geneva10_combined_comparison.png")
        
        plot_QP_comparison(ref_1959_time, ref_1959_QP, sim_time, sim_QP,
                          output_dir / "geneva10_QP_comparison.png")
        
        plot_power_comparison(ref_1959_time, ref_1959_power, sim_time, sim_power,
                             output_dir / "geneva10_power_comparison.png")
        
        plot_alpha_comparison(ref_1959_time, ref_1959_alpha, sim_time, sim_alpha,
                             output_dir / "geneva10_alpha_comparison.png")
        
        plot_W_comparison(ref_1959_time, ref_1959_W, sim_time, sim_W_plot,
                         output_dir / "geneva10_W_comparison.png")
        
        create_comparison_table(ref_1959_time, ref_1959_QP, ref_1959_power, ref_1959_alpha,
                               sim_time, sim_QP, sim_power, sim_alpha,
                               output_dir / "geneva10_comparison_table.txt")
        
        # Generate spatial profile plots
        plot_spatial_profiles(output_dir, output_dir / "geneva10_spatial_profiles.png")
        
        print("\nAll plots generated!")
    else:
        print(f"Error: Could not find {csv_file}")
