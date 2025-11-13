module uq_mod
  use kinds
  use types
  use neutronics_s4_alpha
  use simulation_mod
  use checkpoint_mod
  use history_mod
  use input_parser
  implicit none
  
  type :: UncertaintyParameters
     real(rk) :: xs_uncertainty = 0.05_rk   ! 5% uncertainty in cross sections
     real(rk) :: eos_uncertainty = 0.02_rk  ! 2% uncertainty in EOS
     real(rk) :: beta_uncertainty = 0.10_rk ! 10% uncertainty in delayed neutron fractions
     integer :: n_samples = 100             ! Number of Monte Carlo samples
     logical :: enable_xs_uq = .false.
     logical :: enable_eos_uq = .false.
     logical :: enable_beta_uq = .false.
     character(len=256) :: uq_output_file = "" ! Output file for UQ results
  end type

  type :: UQResults
     real(rk), allocatable :: k_samples(:)      ! k_eff samples (final values)
     real(rk), allocatable :: alpha_samples(:)  ! alpha samples (final values)
     real(rk), allocatable :: power_samples(:)  ! Power samples (final values)
     real(rk) :: k_mean = 0.0_rk
     real(rk) :: k_std = 0.0_rk
     real(rk) :: k_min = 0.0_rk
     real(rk) :: k_max = 0.0_rk
     real(rk) :: alpha_mean = 0.0_rk
     real(rk) :: alpha_std = 0.0_rk
     real(rk) :: power_mean = 0.0_rk
     real(rk) :: power_std = 0.0_rk
     real(rk) :: k_ci_lower = 0.0_rk  ! 95% confidence interval
     real(rk) :: k_ci_upper = 0.0_rk
     ! Transient UQ: Time-dependent statistics
     logical :: transient_uq = .false.  ! Flag for transient UQ
     integer :: n_time_points = 0       ! Number of time points
     real(rk), allocatable :: time_points(:)  ! Time points
     real(rk), allocatable :: power_mean_t(:)  ! Mean power vs time
     real(rk), allocatable :: power_std_t(:)   ! Std power vs time
     real(rk), allocatable :: alpha_mean_t(:)  ! Mean alpha vs time
     real(rk), allocatable :: alpha_std_t(:)   ! Std alpha vs time
     real(rk), allocatable :: keff_mean_t(:)   ! Mean keff vs time
     real(rk), allocatable :: keff_std_t(:)    ! Std keff vs time
  end type

contains

  subroutine sample_parameters(st, uq_params, sample_idx, iostat)
    ! Sample uncertain parameters for Monte Carlo run
    ! Simple uniform sampling (can be extended to normal, Latin Hypercube, etc.)
    type(State), intent(inout) :: st
    type(UncertaintyParameters), intent(in) :: uq_params
    integer, intent(in) :: sample_idx
    integer, intent(out) :: iostat
    
    integer :: i, g, j, imat
    real(rk) :: rand_factor
    real(rk) :: xs_factor, eos_factor, beta_factor
    
    iostat = 0
    
    ! Simple uniform sampling: [-uncertainty, +uncertainty]
    ! For sample_idx=0, use nominal values (no perturbation)
    if (sample_idx == 0) return
    
    ! Generate random factor (pseudo-random based on sample_idx)
    ! TODO: Use proper random number generator
    rand_factor = 2.0_rk * (real(sample_idx, rk) / real(uq_params%n_samples, rk) - 0.5_rk)
    
    ! Apply uncertainties to cross sections
    if (uq_params%enable_xs_uq) then
      xs_factor = 1.0_rk + rand_factor * uq_params%xs_uncertainty
      do imat=1, st%nmat
        do g=1, st%mat(imat)%num_groups
          st%mat(imat)%groups(g)%sig_t = st%mat(imat)%groups(g)%sig_t * xs_factor
          st%mat(imat)%groups(g)%nu_sig_f = st%mat(imat)%groups(g)%nu_sig_f * xs_factor
          do j=1, st%G
            st%mat(imat)%sig_s(g,j) = st%mat(imat)%sig_s(g,j) * xs_factor
          end do
        end do
      end do
    end if
    
    ! Apply uncertainties to delayed neutron fractions
    if (uq_params%enable_beta_uq) then
      beta_factor = 1.0_rk + rand_factor * uq_params%beta_uncertainty
      do imat=1, st%nmat
        do j=1, DGRP
          st%mat(imat)%beta(j) = st%mat(imat)%beta(j) * beta_factor
        end do
      end do
    end if
    
    ! Apply uncertainties to EOS (affect sound speed)
    if (uq_params%enable_eos_uq) then
      eos_factor = 1.0_rk + rand_factor * uq_params%eos_uncertainty
      do i=1, st%Nshell
        st%eos(i)%a = st%eos(i)%a * eos_factor
        st%eos(i)%Acv = st%eos(i)%Acv * eos_factor
      end do
    end if
  end subroutine

  subroutine propagate_uncertainties(st, ctrl, uq_params, results, iostat, deck_file, transient_mode)
    ! Propagate uncertainties through Monte Carlo sampling
    ! Now supports both steady-state and transient UQ
    type(State), intent(inout) :: st
    type(Control), intent(inout) :: ctrl  ! Changed to inout for checkpoint restore
    type(UncertaintyParameters), intent(in) :: uq_params
    type(UQResults), intent(out) :: results
    integer, intent(out) :: iostat
    character(len=*), intent(in), optional :: deck_file  ! Input deck file for transient UQ
    logical, intent(in), optional :: transient_mode      ! Flag for transient UQ
    
    integer :: i, n_samples, g, j, imat, it
    real(rk) :: k, alpha
    real(rk) :: sum_k, sum_k2, sum_alpha, sum_alpha2, sum_power, sum_power2
    real(rk) :: k_mean, k_std, alpha_mean, alpha_std, power_mean, power_std
    ! Save original parameters
    real(rk), allocatable :: orig_sig_t(:,:), orig_nu_sig_f(:,:), orig_sig_s(:,:,:)
    real(rk), allocatable :: orig_beta(:,:)
    real(rk), allocatable :: orig_eos_a(:), orig_eos_Acv(:)
    ! For transient UQ: save/restore state
    type(State) :: st_base
    type(Control) :: ctrl_base, ctrl_work
    character(len=256) :: checkpoint_file
    integer :: n_time_points
    logical :: do_transient
    ! Transient UQ: time-dependent statistics
    real(rk), allocatable :: power_samples_t(:,:)  ! (n_samples, n_time_points)
    real(rk), allocatable :: alpha_samples_t(:,:)  ! (n_samples, n_time_points)
    real(rk), allocatable :: keff_samples_t(:,:)   ! (n_samples, n_time_points)
    
    iostat = 0
    n_samples = uq_params%n_samples
    do_transient = .false.
    if (present(transient_mode)) do_transient = transient_mode
    if (do_transient .and. .not. present(deck_file)) then
      ! Transient mode requires deck file
      iostat = -1
      return
    end if
    
    ! Save original state (for transient UQ)
    if (do_transient) then
      ! For transient UQ, we need to re-initialize from deck file for each sample
      ! Save base state using checkpoint, or reload from deck
      checkpoint_file = "/tmp/uq_checkpoint_base.bin"
      iostat = 0
      call write_checkpoint(st, ctrl, checkpoint_file, iostat)
      if (iostat /= 0) then
        print *, "Warning: Could not save base state for UQ, will reload from deck"
        ! Will reload from deck file for each sample
      end if
    end if
    
    ! Save original parameters
    if (uq_params%enable_xs_uq .or. uq_params%enable_beta_uq) then
      allocate(orig_sig_t(st%nmat, st%G))
      allocate(orig_nu_sig_f(st%nmat, st%G))
      allocate(orig_sig_s(st%nmat, st%G, st%G))
      allocate(orig_beta(st%nmat, DGRP))
      do imat=1, st%nmat
        do g=1, st%mat(imat)%num_groups
          orig_sig_t(imat, g) = st%mat(imat)%groups(g)%sig_t
          orig_nu_sig_f(imat, g) = st%mat(imat)%groups(g)%nu_sig_f
          do j=1, st%G
            orig_sig_s(imat, g, j) = st%mat(imat)%sig_s(g,j)
          end do
        end do
        do j=1, DGRP
          orig_beta(imat, j) = st%mat(imat)%beta(j)
        end do
      end do
    end if
    
    if (uq_params%enable_eos_uq) then
      allocate(orig_eos_a(st%Nshell))
      allocate(orig_eos_Acv(st%Nshell))
      do i=1, st%Nshell
        orig_eos_a(i) = st%eos(i)%a
        orig_eos_Acv(i) = st%eos(i)%Acv
      end do
    end if
    
    ! Allocate results arrays
    if (allocated(results%k_samples)) deallocate(results%k_samples)
    if (allocated(results%alpha_samples)) deallocate(results%alpha_samples)
    if (allocated(results%power_samples)) deallocate(results%power_samples)
    allocate(results%k_samples(n_samples))
    allocate(results%alpha_samples(n_samples))
    allocate(results%power_samples(n_samples))
    
    ! Initialize transient UQ arrays if needed
    if (do_transient) then
      ! Estimate number of time points from output frequency
      n_time_points = int(ctrl%t_end / (ctrl%dt * ctrl%output_freq)) + 10
      results%transient_uq = .true.
      results%n_time_points = 0  ! Will be set after first simulation
      
      allocate(power_samples_t(n_samples, n_time_points))
      allocate(alpha_samples_t(n_samples, n_time_points))
      allocate(keff_samples_t(n_samples, n_time_points))
      power_samples_t = 0.0_rk
      alpha_samples_t = 0.0_rk
      keff_samples_t = 0.0_rk
    else
      results%transient_uq = .false.
      results%n_time_points = 0
    end if
    
    ! Initialize sums
    sum_k = 0.0_rk
    sum_k2 = 0.0_rk
    sum_alpha = 0.0_rk
    sum_alpha2 = 0.0_rk
    sum_power = 0.0_rk
    sum_power2 = 0.0_rk
    results%k_min = huge(1.0_rk)
    results%k_max = -huge(1.0_rk)
    
    ! Run Monte Carlo samples
    print *, "Running ", n_samples, " Monte Carlo samples..."
    if (do_transient) then
      print *, "  Mode: TRANSIENT (full simulations)"
    else
      print *, "  Mode: STEADY-STATE (k-eigenvalue only)"
    end if
    
    do i=1, n_samples
      if (mod(i, max(1, n_samples/10)) == 0) then
        print *, "  Sample ", i, " of ", n_samples
      end if
      
      ! Restore original state (for transient UQ)
      if (do_transient) then
        ! Try to restore from checkpoint first
        iostat = 0
        ctrl_work = ctrl  ! Work copy of control
        call read_checkpoint(st, ctrl_work, checkpoint_file, iostat)
        if (iostat /= 0) then
          ! If checkpoint fails, reload from deck file
          if (present(deck_file) .and. len_trim(deck_file) > 0) then
            call load_deck(deck_file, st, ctrl_work)
            call set_Sn_quadrature(st, ctrl_work%Sn_order)
            call neutronics_set_controls(ctrl_work)
            call ensure_neutronics_arrays(st)
            call store_reference_xs(st)
            call initialize_history(st)
          else
            print *, "Error: Cannot restore state for sample ", i, " (no deck file)"
            cycle
          end if
        else
          call store_reference_xs(st)
        end if
        ! Reset time and history for fresh simulation
        st%time = 0.0_rk
        st%history_count = 0
      else
        ! For steady-state, use original control
        ctrl_work = ctrl
      end if
      
      ! Restore original parameters before sampling
      if (uq_params%enable_xs_uq .or. uq_params%enable_beta_uq) then
        do imat=1, st%nmat
          do g=1, st%mat(imat)%num_groups
            st%mat(imat)%groups(g)%sig_t = orig_sig_t(imat, g)
            st%mat(imat)%groups(g)%nu_sig_f = orig_nu_sig_f(imat, g)
            do j=1, st%G
              st%mat(imat)%sig_s(g,j) = orig_sig_s(imat, g, j)
            end do
          end do
          do j=1, DGRP
            st%mat(imat)%beta(j) = orig_beta(imat, j)
          end do
        end do
      end if
      
      if (uq_params%enable_eos_uq) then
        do j=1, st%Nshell
          st%eos(j)%a = orig_eos_a(j)
          st%eos(j)%Acv = orig_eos_Acv(j)
        end do
      end if
      
      ! Sample parameters
      call sample_parameters(st, uq_params, i, iostat)
      if (iostat /= 0) cycle
      
      ! Update reference cross sections if temperature-dependent
      call store_reference_xs(st)
      
      ! Run simulation
      if (do_transient) then
        ! Run full transient simulation (use work copy of control)
        call run_transient_simulation(st, ctrl_work, quiet_mode=.true.)
        
        ! Store final results
        results%k_samples(i) = st%k_eff
        results%alpha_samples(i) = st%alpha
        results%power_samples(i) = st%total_power
        
        ! Store time-dependent results
        if (st%history_count > 0) then
          if (results%n_time_points == 0) then
            ! First sample: set time points and allocate arrays
            results%n_time_points = st%history_count
            if (allocated(results%time_points)) deallocate(results%time_points)
            if (allocated(results%power_mean_t)) deallocate(results%power_mean_t)
            if (allocated(results%power_std_t)) deallocate(results%power_std_t)
            if (allocated(results%alpha_mean_t)) deallocate(results%alpha_mean_t)
            if (allocated(results%alpha_std_t)) deallocate(results%alpha_std_t)
            if (allocated(results%keff_mean_t)) deallocate(results%keff_mean_t)
            if (allocated(results%keff_std_t)) deallocate(results%keff_std_t)
            allocate(results%time_points(results%n_time_points))
            allocate(results%power_mean_t(results%n_time_points))
            allocate(results%power_std_t(results%n_time_points))
            allocate(results%alpha_mean_t(results%n_time_points))
            allocate(results%alpha_std_t(results%n_time_points))
            allocate(results%keff_mean_t(results%n_time_points))
            allocate(results%keff_std_t(results%n_time_points))
            
            ! Set time points from first sample
            do it=1, results%n_time_points
              results%time_points(it) = st%time_history(it)
            end do
          end if
          
          ! Store time-dependent data (interpolate if needed)
          do it=1, min(results%n_time_points, st%history_count)
            power_samples_t(i, it) = st%power_history(it)
            alpha_samples_t(i, it) = st%alpha_history(it)
            keff_samples_t(i, it) = st%keff_history(it)
          end do
        end if
      else
        ! Run steady-state k-eigenvalue only
        k = 1.0_rk
        call sweep_spherical_k(st, k, alpha=0._rk, tol=1.0e-5_rk, itmax=50, use_dsa=ctrl_work%use_dsa)
        
        ! Store results
        results%k_samples(i) = k
        results%alpha_samples(i) = 0.0_rk
        results%power_samples(i) = st%total_power
      end if
      
      ! Accumulate statistics
      sum_k = sum_k + results%k_samples(i)
      sum_k2 = sum_k2 + results%k_samples(i)**2
      sum_alpha = sum_alpha + results%alpha_samples(i)
      sum_alpha2 = sum_alpha2 + results%alpha_samples(i)**2
      sum_power = sum_power + results%power_samples(i)
      sum_power2 = sum_power2 + results%power_samples(i)**2
      
      results%k_min = min(results%k_min, results%k_samples(i))
      results%k_max = max(results%k_max, results%k_samples(i))
    end do
    
    ! Restore original parameters
    if (uq_params%enable_xs_uq .or. uq_params%enable_beta_uq) then
      do imat=1, st%nmat
        do g=1, st%mat(imat)%num_groups
          st%mat(imat)%groups(g)%sig_t = orig_sig_t(imat, g)
          st%mat(imat)%groups(g)%nu_sig_f = orig_nu_sig_f(imat, g)
          do j=1, st%G
            st%mat(imat)%sig_s(g,j) = orig_sig_s(imat, g, j)
          end do
        end do
        do j=1, DGRP
          st%mat(imat)%beta(j) = orig_beta(imat, j)
        end do
      end do
      deallocate(orig_sig_t, orig_nu_sig_f, orig_sig_s, orig_beta)
    end if
    
    if (uq_params%enable_eos_uq) then
      do j=1, st%Nshell
        st%eos(j)%a = orig_eos_a(j)
        st%eos(j)%Acv = orig_eos_Acv(j)
      end do
      deallocate(orig_eos_a, orig_eos_Acv)
    end if
    
    ! Calculate statistics
    if (n_samples > 0) then
      results%k_mean = sum_k / real(n_samples, rk)
      results%k_std = sqrt(max((sum_k2 / real(n_samples, rk)) - results%k_mean**2, 0.0_rk))
      results%alpha_mean = sum_alpha / real(n_samples, rk)
      results%alpha_std = sqrt(max((sum_alpha2 / real(n_samples, rk)) - results%alpha_mean**2, 0.0_rk))
      results%power_mean = sum_power / real(n_samples, rk)
      results%power_std = sqrt(max((sum_power2 / real(n_samples, rk)) - results%power_mean**2, 0.0_rk))
      
      ! 95% confidence interval (approximate: mean ± 2*std)
      results%k_ci_lower = results%k_mean - 2.0_rk * results%k_std
      results%k_ci_upper = results%k_mean + 2.0_rk * results%k_std
    end if
    
    ! Calculate transient statistics if needed
    if (do_transient .and. results%n_time_points > 0 .and. allocated(power_samples_t)) then
      ! Calculate mean and std for each time point
      do it=1, results%n_time_points
        ! Calculate mean
        sum_power = 0.0_rk
        sum_alpha = 0.0_rk
        sum_k = 0.0_rk
        do i=1, n_samples
          sum_power = sum_power + power_samples_t(i, it)
          sum_alpha = sum_alpha + alpha_samples_t(i, it)
          sum_k = sum_k + keff_samples_t(i, it)
        end do
        results%power_mean_t(it) = sum_power / real(n_samples, rk)
        results%alpha_mean_t(it) = sum_alpha / real(n_samples, rk)
        results%keff_mean_t(it) = sum_k / real(n_samples, rk)
        
        ! Calculate std
        sum_power2 = 0.0_rk
        sum_alpha2 = 0.0_rk
        sum_k2 = 0.0_rk
        do i=1, n_samples
          sum_power2 = sum_power2 + (power_samples_t(i, it) - results%power_mean_t(it))**2
          sum_alpha2 = sum_alpha2 + (alpha_samples_t(i, it) - results%alpha_mean_t(it))**2
          sum_k2 = sum_k2 + (keff_samples_t(i, it) - results%keff_mean_t(it))**2
        end do
        results%power_std_t(it) = sqrt(max(sum_power2 / real(n_samples, rk), 0.0_rk))
        results%alpha_std_t(it) = sqrt(max(sum_alpha2 / real(n_samples, rk), 0.0_rk))
        results%keff_std_t(it) = sqrt(max(sum_k2 / real(n_samples, rk), 0.0_rk))
      end do
      
      ! Clean up temporary arrays
      deallocate(power_samples_t, alpha_samples_t, keff_samples_t)
    end if
    
    ! Restore original state (for transient UQ)
    if (do_transient) then
      ! Restore base state
      iostat = 0
      ctrl_work = ctrl  ! Work copy
      call read_checkpoint(st, ctrl_work, checkpoint_file, iostat)
      if (iostat == 0) then
        call store_reference_xs(st)
        ctrl = ctrl_work  ! Restore control
      end if
      ! Clean up checkpoint file
      ! (could delete it, but leave it for now)
    end if
  end subroutine

  subroutine write_uq_results(results, uq_params, filename, iostat)
    ! Write UQ results to file
    ! Now supports both steady-state and transient UQ
    type(UQResults), intent(in) :: results
    type(UncertaintyParameters), intent(in) :: uq_params
    character(len=*), intent(in) :: filename
    integer, intent(out) :: iostat
    
    integer :: iu, i, it
    character(len=256) :: transient_filename
    
    iostat = 0
    open(newunit=iu, file=filename, status='replace', action='write', iostat=iostat)
    if (iostat /= 0) return
    
    ! Write header
    write(iu, '(A)') "# Uncertainty Quantification Results"
    write(iu, '(A)') "# Number of samples: " // trim(adjustl(int2str(uq_params%n_samples)))
    if (results%transient_uq) then
      write(iu, '(A)') "# Mode: TRANSIENT"
      write(iu, '(A,I6)') "# Number of time points: ", results%n_time_points
    else
      write(iu, '(A)') "# Mode: STEADY-STATE"
    end if
    write(iu, '(A)') "#"
    write(iu, '(A)') "# Statistics (final values):"
    write(iu, '(A,F12.6)') "# k_eff mean: ", results%k_mean
    write(iu, '(A,F12.6)') "# k_eff std:  ", results%k_std
    write(iu, '(A,F12.6)') "# k_eff min:  ", results%k_min
    write(iu, '(A,F12.6)') "# k_eff max:  ", results%k_max
    write(iu, '(A,2F12.6)') "# k_eff CI (95%): ", results%k_ci_lower, results%k_ci_upper
    write(iu, '(A)') "#"
    write(iu, '(A)') "# Samples: sample_index, k_eff, alpha, power"
    
    ! Write samples
    if (allocated(results%k_samples)) then
      do i=1, size(results%k_samples)
        write(iu, '(I6,3(1X,E15.7))') i, results%k_samples(i), results%alpha_samples(i), results%power_samples(i)
      end do
    end if
    
    close(iu)
    
    ! Write transient results if available
    if (results%transient_uq .and. results%n_time_points > 0) then
      transient_filename = trim(filename) // "_transient.csv"
      open(newunit=iu, file=transient_filename, status='replace', action='write', iostat=iostat)
      if (iostat == 0) then
        ! Write header
        write(iu, '(A)') "# Transient UQ Results"
        write(iu, '(A,I6)') "# Number of samples: ", uq_params%n_samples
        write(iu, '(A,I6)') "# Number of time points: ", results%n_time_points
        write(iu, '(A)') "#"
        write(iu, '(A)') "# Time-dependent statistics:"
        write(iu, '(A)') "# time, power_mean, power_std, alpha_mean, alpha_std, keff_mean, keff_std"
        
        ! Write time-dependent statistics
        if (allocated(results%time_points) .and. allocated(results%power_mean_t)) then
          do it=1, results%n_time_points
            write(iu, '(7(1X,E15.7))') results%time_points(it), &
                results%power_mean_t(it), results%power_std_t(it), &
                results%alpha_mean_t(it), results%alpha_std_t(it), &
                results%keff_mean_t(it), results%keff_std_t(it)
          end do
        end if
        
        close(iu)
        print *, "Transient UQ results written to: ", trim(transient_filename)
      end if
    end if
  contains
    function int2str(i) result(s)
      integer, intent(in) :: i
      character(len=20) :: s
      write(s, '(I20)') i
      s = adjustl(s)
    end function
  end subroutine

  subroutine run_uq_analysis(st, ctrl, output_file, deck_file, transient_mode)
    ! Wrapper function to run UQ analysis from main program
    ! Now supports both steady-state and transient UQ
    type(State), intent(inout) :: st
    type(Control), intent(inout) :: ctrl  ! Changed to inout for checkpoint restore
    character(len=*), intent(in) :: output_file
    character(len=*), intent(in), optional :: deck_file  ! Input deck file for transient UQ
    logical, intent(in), optional :: transient_mode      ! Flag for transient UQ
    
    type(UncertaintyParameters) :: uq_params
    type(UQResults) :: results
    integer :: iostat
    logical :: do_transient
    character(len=256) :: deck_file_used
    
    do_transient = .false.
    if (present(transient_mode)) do_transient = transient_mode
    if (do_transient .and. present(deck_file)) then
      deck_file_used = deck_file
    else
      deck_file_used = ""  ! Not used for steady-state
    end if
    
    ! Set default UQ parameters
    uq_params%xs_uncertainty = 0.05_rk
    uq_params%eos_uncertainty = 0.02_rk
    uq_params%beta_uncertainty = 0.10_rk
    if (do_transient) then
      uq_params%n_samples = 3  ! Very reduced for transient testing (very slow - each sample runs full simulation)
    else
      uq_params%n_samples = 10  ! Reduced for faster testing
    end if
    uq_params%enable_xs_uq = .true.
    uq_params%enable_eos_uq = .false.
    uq_params%enable_beta_uq = .false.
    uq_params%uq_output_file = trim(output_file)
    
    print *, "Running UQ analysis with ", uq_params%n_samples, " samples"
    if (do_transient) then
      print *, "  Mode: TRANSIENT (full simulations)"
    else
      print *, "  Mode: STEADY-STATE (k-eigenvalue only)"
    end if
    print *, "  XS uncertainty: ", uq_params%xs_uncertainty * 100.0_rk, "%"
    
    ! Run UQ analysis
    if (do_transient .and. len_trim(deck_file_used) > 0) then
      call propagate_uncertainties(st, ctrl, uq_params, results, iostat, deck_file=deck_file_used, transient_mode=.true.)
    else
      call propagate_uncertainties(st, ctrl, uq_params, results, iostat)
    end if
    
    if (iostat == 0) then
      ! Write results
      call write_uq_results(results, uq_params, trim(output_file), iostat)
      if (iostat == 0) then
        print *, "UQ results written to: ", trim(output_file)
        print *, "  k_eff mean: ", results%k_mean
        print *, "  k_eff std:  ", results%k_std
        print *, "  k_eff CI (95%): [", results%k_ci_lower, ", ", results%k_ci_upper, "]"
        if (do_transient .and. results%transient_uq) then
          print *, "  Transient UQ: ", results%n_time_points, " time points"
        end if
      else
        print *, "Error writing UQ results"
      end if
    else
      print *, "Error running UQ analysis: iostat=", iostat
    end if
  end subroutine

end module uq_mod

