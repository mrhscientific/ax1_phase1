module types
  use kinds
  implicit none
  integer, parameter :: GMAX=7, MUMAX=4, SHELLMAX=256, DGRP=6

  type :: Shell
     real(rk) :: r_in=0._rk, r_out=0._rk, rbar=0._rk
     real(rk) :: vel=0._rk, mass=0._rk, rho=0._rk
     real(rk) :: eint=0._rk, temp=0._rk
     real(rk) :: p_hyd=0._rk, p_visc=0._rk, p=0._rk
     integer  :: mat=1
  end type
  type :: EOS
     real(rk) :: a=0._rk, b=0._rk, c=1._rk
     real(rk) :: Acv=1._rk, Bcv=0._rk
     logical  :: tabular = .false.
     character(len=256) :: table_path = ""
  end type
  type :: ReactivityFeedback
     real(rk) :: doppler_coef = 0.0_rk      ! Doppler coefficient (pcm/K)
     real(rk) :: expansion_coef = 0.0_rk    ! Fuel expansion coefficient (pcm/K)
     real(rk) :: void_coef = 0.0_rk         ! Void coefficient (pcm/%void)
     logical  :: enable_doppler = .false.
     logical  :: enable_expansion = .false.
     logical  :: enable_void = .false.
     real(rk) :: T_ref = 300.0_rk           ! Reference temperature (K)
     real(rk) :: rho_ref = 0.0_rk           ! Reference density
  end type

  type :: Control
     character(len=8) :: eigmode="k"  ! "k" or "alpha"
     real(rk) :: dt=1.0e-3_rk, dt_max=1.0e-1_rk, dt_min=1.0e-6_rk
     integer  :: hydro_per_neut=1, hydro_per_neut_max=200
     real(rk) :: w_limit=0.3_rk, alpha_delta_limit=0.2_rk, power_delta_limit=0.2_rk
     real(rk) :: cfl = 0.8_rk
     integer  :: Sn_order = 4          ! 4, 6, 8 supported
     logical  :: use_dsa = .false.
     character(len=16) :: upscatter = "allow"  ! allow|neglect|scale
     real(rk) :: upscatter_scale = 1.0_rk
     ! Phase 3: Reactivity insertion
     real(rk) :: rho_insert = 0.0_rk        ! Reactivity insertion (pcm)
     character(len=256) :: rho_profile = "" ! File with rho(t) profile
     logical  :: use_rho_profile = .false.
     ! Phase 3: Time-dependent control
     real(rk) :: t_end = 0.2_rk             ! End time (replaces hardcoded 0.2)
     integer  :: output_freq = 10           ! Output frequency (every N steps)
     character(len=256) :: output_file = "" ! Output file for time histories
     ! Phase 3: Restart/checkpoint
     character(len=256) :: checkpoint_file = "" ! Checkpoint file path
     character(len=256) :: restart_file = ""    ! Restart from file
     logical  :: use_restart = .false.
     integer  :: checkpoint_freq = 100        ! Write checkpoint every N steps
     logical  :: write_checkpoint = .false.
     ! Phase 3: UQ and sensitivity
     logical  :: run_uq = .false.            ! Run uncertainty quantification
     logical  :: run_sensitivity = .false.   ! Run sensitivity analysis
     character(len=256) :: uq_output_file = "" ! UQ output file
     character(len=256) :: sensitivity_output_file = "" ! Sensitivity output file
  end type
  type :: XSecGroup
     real(rk) :: sig_t=0._rk
     real(rk) :: nu_sig_f=0._rk
     real(rk) :: chi=0._rk
  end type
  type :: Material
     integer :: num_groups=1
     type(XSecGroup) :: groups(GMAX)
     real(rk) :: sig_s(GMAX, GMAX) = 0._rk  ! from g'->g
     ! delayed neutrons:
     real(rk) :: beta(DGRP) = 0._rk
     real(rk) :: lambda(DGRP) = 0._rk
     ! Phase 3: Temperature-dependent cross sections
     logical  :: temperature_dependent = .false.
     real(rk) :: T_ref = 300.0_rk           ! Reference temperature (K)
     real(rk) :: doppler_exponent = 0.5_rk  ! Doppler exponent (typically 0.5)
     ! Phase 3: Store original cross sections at reference temperature
     type(XSecGroup) :: groups_ref(GMAX)    ! Reference cross sections at T_ref
     real(rk) :: sig_s_ref(GMAX, GMAX) = 0._rk  ! Reference scattering at T_ref
     logical  :: reference_stored = .false. ! Flag to indicate if reference is stored
  end type
  type :: State
     integer :: Nshell=1
     type(Shell), allocatable :: sh(:)
     type(EOS),   allocatable :: eos(:)
     integer :: G=1
     integer, allocatable :: mat_of_shell(:)
     integer :: nmat=0
     type(Material), allocatable :: mat(:)
     ! neutronics quadrature
     real(rk), allocatable :: mu(:), w(:)
     integer :: Nmu=0
     real(rk) :: vbar=1._rk
     real(rk) :: k_eff=1._rk, alpha=0._rk, time=0._rk, total_power=0._rk

     real(rk), allocatable :: phi(:,:)       ! (G,Nshell)
     real(rk), allocatable :: q_scatter(:,:) ! (G,Nshell)
     real(rk), allocatable :: q_fiss(:,:)    ! (G,Nshell) prompt
     real(rk), allocatable :: q_delay(:,:)   ! (G,Nshell) delayed source
     real(rk), allocatable :: power_frac(:)  ! per shell

    ! delayed precursors per shell and delayed group
    real(rk), allocatable :: C(:,:,:) ! (DGRP, G, Nshell) lumped per energy group for now
    
    ! performance counters
    integer :: transport_iterations = 0
    integer :: dsa_iterations = 0
    
    ! Phase 3: Reactivity feedback
    type(ReactivityFeedback) :: feedback
    real(rk) :: reactivity = 0.0_rk           ! Total reactivity (pcm)
    real(rk) :: rho_doppler = 0.0_rk          ! Doppler reactivity (pcm)
    real(rk) :: rho_expansion = 0.0_rk        ! Expansion reactivity (pcm)
    real(rk) :: rho_void = 0.0_rk             ! Void reactivity (pcm)
    real(rk) :: rho_inserted = 0.0_rk         ! Inserted reactivity (pcm)
    
    ! Phase 3: Time history storage
    integer :: history_size = 10000
    integer :: history_count = 0
    real(rk), allocatable :: time_history(:)      ! Time points
    real(rk), allocatable :: power_history(:)     ! Power vs time
    real(rk), allocatable :: alpha_history(:)     ! Alpha vs time
    real(rk), allocatable :: keff_history(:)      ! keff vs time
    real(rk), allocatable :: reactivity_history(:) ! Reactivity vs time
    real(rk), allocatable :: radius_history(:,:)   ! Radius vs time (Nshell, nsteps)
    real(rk), allocatable :: velocity_history(:,:) ! Velocity vs time (Nshell, nsteps)
    real(rk), allocatable :: pressure_history(:,:) ! Pressure vs time (Nshell, nsteps)
    real(rk), allocatable :: temp_history(:,:)     ! Temperature vs time (Nshell, nsteps)
  end type
end module types
