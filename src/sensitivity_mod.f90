module sensitivity_mod
  use kinds
  use types
  use neutronics_s4_alpha
  use simulation_mod
  use checkpoint_mod
  use history_mod
  use input_parser
  implicit none

  type :: SensitivityResults
     real(rk), allocatable :: dk_dxs(:)      ! Sensitivity of k to cross sections (G)
     real(rk), allocatable :: dk_deos(:)     ! Sensitivity of k to EOS (Nshell)
     real(rk), allocatable :: dk_dbeta(:)    ! Sensitivity of k to beta (DGRP)
     real(rk), allocatable :: dalpha_dxs(:)  ! Sensitivity of alpha to cross sections (G)
     real(rk), allocatable :: dalpha_deos(:) ! Sensitivity of alpha to EOS (Nshell)
     real(rk), allocatable :: dpower_dxs(:)  ! Sensitivity of power to cross sections (G)
     real(rk) :: xs_perturbation = 0.01_rk     ! Perturbation for finite difference (1%)
     real(rk) :: eos_perturbation = 0.01_rk    ! Perturbation for EOS (1%)
     real(rk) :: beta_perturbation = 0.01_rk   ! Perturbation for beta (1%)
     ! Transient sensitivity: Time-dependent sensitivity coefficients
     logical :: transient_sensitivity = .false.  ! Flag for transient sensitivity
     integer :: n_time_points = 0       ! Number of time points
     real(rk), allocatable :: time_points(:)  ! Time points
     real(rk), allocatable :: dpower_dxs_t(:,:)  ! Sensitivity of power to XS vs time (G, n_time_points)
     real(rk), allocatable :: dalpha_dxs_t(:,:)  ! Sensitivity of alpha to XS vs time (G, n_time_points)
     real(rk), allocatable :: dkeff_dxs_t(:,:)   ! Sensitivity of keff to XS vs time (G, n_time_points)
  end type

contains

  subroutine calculate_sensitivities(st, ctrl, results, iostat, deck_file, transient_mode)
    ! Calculate sensitivity coefficients using finite differences
    ! dk/dX = (k(X+ΔX) - k(X-ΔX)) / (2*ΔX)
    ! Now supports both steady-state and transient sensitivity
    type(State), intent(inout) :: st
    type(Control), intent(inout) :: ctrl  ! Changed to inout for checkpoint restore
    type(SensitivityResults), intent(out) :: results
    integer, intent(out) :: iostat
    character(len=*), intent(in), optional :: deck_file  ! Input deck file for transient sensitivity
    logical, intent(in), optional :: transient_mode      ! Flag for transient sensitivity
    
    integer :: i, g, j, imat, it
    real(rk) :: k_base, k_plus, k_minus
    real(rk) :: alpha_base, alpha_plus, alpha_minus
    real(rk) :: power_base, power_plus, power_minus
    real(rk) :: xs_orig, eos_orig, beta_orig
    real(rk) :: delta_xs, delta_eos, delta_beta
    logical :: do_transient
    character(len=256) :: checkpoint_file
    type(Control) :: ctrl_work
    ! For transient sensitivity: time-dependent results
    real(rk), allocatable :: power_base_t(:), power_plus_t(:), power_minus_t(:)
    real(rk), allocatable :: alpha_base_t(:), alpha_plus_t(:), alpha_minus_t(:)
    real(rk), allocatable :: keff_base_t(:), keff_plus_t(:), keff_minus_t(:)
    
    iostat = 0
    do_transient = .false.
    if (present(transient_mode)) do_transient = transient_mode
    results%transient_sensitivity = do_transient
    
    ! Initialize results
    if (.not. allocated(results%dk_dxs)) allocate(results%dk_dxs(st%G))
    if (.not. allocated(results%dk_deos)) allocate(results%dk_deos(st%Nshell))
    if (.not. allocated(results%dk_dbeta)) allocate(results%dk_dbeta(DGRP))
    if (.not. allocated(results%dalpha_dxs)) allocate(results%dalpha_dxs(st%G))
    if (.not. allocated(results%dalpha_deos)) allocate(results%dalpha_deos(st%Nshell))
    if (.not. allocated(results%dpower_dxs)) allocate(results%dpower_dxs(st%G))
    
    results%dk_dxs = 0.0_rk
    results%dk_deos = 0.0_rk
    results%dk_dbeta = 0.0_rk
    results%dalpha_dxs = 0.0_rk
    results%dalpha_deos = 0.0_rk
    results%dpower_dxs = 0.0_rk
    
    ! Save base state (for transient sensitivity)
    if (do_transient) then
      checkpoint_file = "/tmp/sensitivity_checkpoint_base.bin"
      iostat = 0
      call write_checkpoint(st, ctrl, checkpoint_file, iostat)
      if (iostat /= 0 .and. present(deck_file) .and. len_trim(deck_file) > 0) then
        ! Will reload from deck if checkpoint fails
      else if (iostat /= 0) then
        print *, "Warning: Could not save base state for sensitivity, falling back to steady-state"
        do_transient = .false.
      end if
    end if
    
    ! Calculate base case
    if (do_transient) then
      ! Run full transient simulation for base case
      ctrl_work = ctrl
      call run_transient_simulation(st, ctrl_work, quiet_mode=.true.)
      k_base = st%k_eff
      alpha_base = st%alpha
      power_base = st%total_power
      
      ! Store time-dependent base case
      if (st%history_count > 0) then
        results%n_time_points = st%history_count
        if (allocated(results%time_points)) deallocate(results%time_points)
        if (allocated(results%dpower_dxs_t)) deallocate(results%dpower_dxs_t)
        if (allocated(results%dalpha_dxs_t)) deallocate(results%dalpha_dxs_t)
        if (allocated(results%dkeff_dxs_t)) deallocate(results%dkeff_dxs_t)
        allocate(results%time_points(results%n_time_points))
        allocate(results%dpower_dxs_t(st%G, results%n_time_points))
        allocate(results%dalpha_dxs_t(st%G, results%n_time_points))
        allocate(results%dkeff_dxs_t(st%G, results%n_time_points))
        allocate(power_base_t(results%n_time_points))
        allocate(alpha_base_t(results%n_time_points))
        allocate(keff_base_t(results%n_time_points))
        allocate(power_plus_t(results%n_time_points))
        allocate(alpha_plus_t(results%n_time_points))
        allocate(keff_plus_t(results%n_time_points))
        allocate(power_minus_t(results%n_time_points))
        allocate(alpha_minus_t(results%n_time_points))
        allocate(keff_minus_t(results%n_time_points))
        
        ! Store base case time history
        do it=1, results%n_time_points
          results%time_points(it) = st%time_history(it)
          power_base_t(it) = st%power_history(it)
          alpha_base_t(it) = st%alpha_history(it)
          keff_base_t(it) = st%keff_history(it)
        end do
      end if
    else
      ! Run steady-state k-eigenvalue for base case
      k_base = 1.0_rk
      call sweep_spherical_k(st, k_base, alpha=0._rk, tol=1.0e-5_rk, itmax=50, use_dsa=ctrl%use_dsa)
      call finalize_power_and_alpha(st, k_base, include_delayed=.false.)
      alpha_base = st%alpha
      power_base = st%total_power
      results%n_time_points = 0
    end if
    
    ! Calculate sensitivities to cross sections
    do imat=1, st%nmat
      do g=1, st%mat(imat)%num_groups
        ! Restore base state (for transient sensitivity)
        if (do_transient) then
          iostat = 0
          ctrl_work = ctrl
          call read_checkpoint(st, ctrl_work, checkpoint_file, iostat)
          if (iostat /= 0) then
            ! If checkpoint fails, reload from deck
            if (present(deck_file) .and. len_trim(deck_file) > 0) then
              call load_deck(deck_file, st, ctrl_work)
              call set_Sn_quadrature(st, ctrl_work%Sn_order)
              call neutronics_set_controls(ctrl_work)
              call ensure_neutronics_arrays(st)
              call store_reference_xs(st)
              call initialize_history(st)
            else
              print *, "Error: Cannot restore state for sensitivity calculation"
              cycle
            end if
          else
            call store_reference_xs(st)
          end if
          st%time = 0.0_rk
          st%history_count = 0
        end if
        
        ! Perturb sig_t and nu_sig_f
        xs_orig = st%mat(imat)%groups(g)%sig_t
        delta_xs = results%xs_perturbation * xs_orig
        
        ! Forward difference
        st%mat(imat)%groups(g)%sig_t = xs_orig + delta_xs
        st%mat(imat)%groups(g)%nu_sig_f = st%mat(imat)%groups(g)%nu_sig_f * (1.0_rk + results%xs_perturbation)
        call store_reference_xs(st)  ! Update reference if temperature-dependent
        
        if (do_transient) then
          ! Run full transient simulation
          call run_transient_simulation(st, ctrl_work, quiet_mode=.true.)
          k_plus = st%k_eff
          alpha_plus = st%alpha
          power_plus = st%total_power
          ! Store time-dependent results
          if (st%history_count > 0) then
            do it=1, min(results%n_time_points, st%history_count)
              power_plus_t(it) = st%power_history(it)
              alpha_plus_t(it) = st%alpha_history(it)
              keff_plus_t(it) = st%keff_history(it)
            end do
          end if
        else
          k_plus = 1.0_rk
          call sweep_spherical_k(st, k_plus, alpha=0._rk, tol=1.0e-5_rk, itmax=50, use_dsa=ctrl%use_dsa)
          call finalize_power_and_alpha(st, k_plus, include_delayed=.false.)
          alpha_plus = st%alpha
          power_plus = st%total_power
        end if
        
        ! Restore base state for backward difference
        if (do_transient) then
          iostat = 0
          ctrl_work = ctrl
          call read_checkpoint(st, ctrl_work, checkpoint_file, iostat)
          if (iostat /= 0) then
            if (present(deck_file) .and. len_trim(deck_file) > 0) then
              call load_deck(deck_file, st, ctrl_work)
              call set_Sn_quadrature(st, ctrl_work%Sn_order)
              call neutronics_set_controls(ctrl_work)
              call ensure_neutronics_arrays(st)
              call store_reference_xs(st)
              call initialize_history(st)
            else
              cycle
            end if
          else
            call store_reference_xs(st)
          end if
          st%time = 0.0_rk
          st%history_count = 0
        end if
        
        ! Backward difference
        st%mat(imat)%groups(g)%sig_t = xs_orig - delta_xs
        st%mat(imat)%groups(g)%nu_sig_f = st%mat(imat)%groups(g)%nu_sig_f * (1.0_rk - results%xs_perturbation)
        call store_reference_xs(st)  ! Update reference if temperature-dependent
        
        if (do_transient) then
          ! Run full transient simulation
          call run_transient_simulation(st, ctrl_work, quiet_mode=.true.)
          k_minus = st%k_eff
          alpha_minus = st%alpha
          power_minus = st%total_power
          ! Store time-dependent results
          if (st%history_count > 0) then
            do it=1, min(results%n_time_points, st%history_count)
              power_minus_t(it) = st%power_history(it)
              alpha_minus_t(it) = st%alpha_history(it)
              keff_minus_t(it) = st%keff_history(it)
            end do
          end if
        else
          k_minus = 1.0_rk
          call sweep_spherical_k(st, k_minus, alpha=0._rk, tol=1.0e-5_rk, itmax=50, use_dsa=ctrl%use_dsa)
          call finalize_power_and_alpha(st, k_minus, include_delayed=.false.)
          alpha_minus = st%alpha
          power_minus = st%total_power
        end if
        
        ! Central difference
        if (abs(delta_xs) > 1.0e-30_rk) then
          results%dk_dxs(g) = (k_plus - k_minus) / (2.0_rk * delta_xs)
          results%dalpha_dxs(g) = (alpha_plus - alpha_minus) / (2.0_rk * delta_xs)
          results%dpower_dxs(g) = (power_plus - power_minus) / (2.0_rk * delta_xs)
        end if
        
        ! Transient sensitivity: Calculate time-dependent sensitivities
        if (do_transient .and. results%n_time_points > 0) then
          do it=1, results%n_time_points
            if (abs(delta_xs) > 1.0e-30_rk) then
              results%dpower_dxs_t(g, it) = (power_plus_t(it) - power_minus_t(it)) / (2.0_rk * delta_xs)
              results%dalpha_dxs_t(g, it) = (alpha_plus_t(it) - alpha_minus_t(it)) / (2.0_rk * delta_xs)
              results%dkeff_dxs_t(g, it) = (keff_plus_t(it) - keff_minus_t(it)) / (2.0_rk * delta_xs)
            end if
          end do
        end if
        
        ! Restore original
        if (do_transient) then
          iostat = 0
          ctrl_work = ctrl
          call read_checkpoint(st, ctrl_work, checkpoint_file, iostat)
          if (iostat == 0) then
            call store_reference_xs(st)
          end if
          st%time = 0.0_rk
          st%history_count = 0
        end if
        st%mat(imat)%groups(g)%sig_t = xs_orig
        ! Note: nu_sig_f restoration handled by checkpoint restore
      end do
    end do
    
    ! Calculate sensitivities to delayed neutron fractions (simplified - only steady-state for now)
    if (.not. do_transient) then
      do imat=1, st%nmat
        do j=1, DGRP
          beta_orig = st%mat(imat)%beta(j)
          delta_beta = results%beta_perturbation * beta_orig
          
          st%mat(imat)%beta(j) = beta_orig + delta_beta
          k_plus = 1.0_rk
          call sweep_spherical_k(st, k_plus, alpha=0._rk, tol=1.0e-5_rk, itmax=50, use_dsa=ctrl%use_dsa)
          
          st%mat(imat)%beta(j) = beta_orig - delta_beta
          k_minus = 1.0_rk
          call sweep_spherical_k(st, k_minus, alpha=0._rk, tol=1.0e-5_rk, itmax=50, use_dsa=ctrl%use_dsa)
          
          if (abs(delta_beta) > 1.0e-30_rk) then
            results%dk_dbeta(j) = (k_plus - k_minus) / (2.0_rk * delta_beta)
          end if
          
          st%mat(imat)%beta(j) = beta_orig
        end do
      end do
    end if
    
    ! Clean up transient arrays
    if (do_transient) then
      if (allocated(power_base_t)) deallocate(power_base_t, power_plus_t, power_minus_t)
      if (allocated(alpha_base_t)) deallocate(alpha_base_t, alpha_plus_t, alpha_minus_t)
      if (allocated(keff_base_t)) deallocate(keff_base_t, keff_plus_t, keff_minus_t)
      
      ! Restore base state
      iostat = 0
      ctrl_work = ctrl
      call read_checkpoint(st, ctrl_work, checkpoint_file, iostat)
      if (iostat == 0) then
        call store_reference_xs(st)
        ctrl = ctrl_work
      end if
    end if
  end subroutine

  subroutine write_sensitivity_results(results, filename, iostat)
    ! Write sensitivity results to file
    ! Now supports both steady-state and transient sensitivity
    type(SensitivityResults), intent(in) :: results
    character(len=*), intent(in) :: filename
    integer, intent(out) :: iostat
    
    integer :: iu, g, j, it
    character(len=256) :: transient_filename
    
    iostat = 0
    open(newunit=iu, file=filename, status='replace', action='write', iostat=iostat)
    if (iostat /= 0) return
    
    ! Write header
    write(iu, '(A)') "# Sensitivity Analysis Results"
    if (results%transient_sensitivity) then
      write(iu, '(A)') "# Mode: TRANSIENT"
      write(iu, '(A,I6)') "# Number of time points: ", results%n_time_points
    else
      write(iu, '(A)') "# Mode: STEADY-STATE"
    end if
    write(iu, '(A)') "#"
    write(iu, '(A)') "# Sensitivity coefficients: dk/dX"
    write(iu, '(A)') "#"
    
    ! Write sensitivities to cross sections
    if (allocated(results%dk_dxs)) then
      write(iu, '(A)') "# Sensitivity to cross sections (dk/dxs):"
      do g=1, size(results%dk_dxs)
        write(iu, '(A,I3,1X,E15.7)') "# Group ", g, results%dk_dxs(g)
      end do
    end if
    
    ! Write sensitivities to delayed neutron fractions
    if (allocated(results%dk_dbeta)) then
      write(iu, '(A)') "# Sensitivity to delayed neutron fractions (dk/dbeta):"
      do j=1, size(results%dk_dbeta)
        write(iu, '(A,I3,1X,E15.7)') "# Delayed group ", j, results%dk_dbeta(j)
      end do
    end if
    
    close(iu)
    
    ! Write transient sensitivity results if available
    if (results%transient_sensitivity .and. results%n_time_points > 0 .and. allocated(results%dpower_dxs_t)) then
      transient_filename = trim(filename) // "_transient.csv"
      open(newunit=iu, file=transient_filename, status='replace', action='write', iostat=iostat)
      if (iostat == 0) then
        ! Write header
        write(iu, '(A)') "# Transient Sensitivity Results"
        write(iu, '(A,I6)') "# Number of time points: ", results%n_time_points
        write(iu, '(A)') "#"
        write(iu, '(A)') "# Time-dependent sensitivity coefficients:"
        write(iu, '(A)') "# time, group, dpower_dxs, dalpha_dxs, dkeff_dxs"
        
        ! Write time-dependent sensitivities
        if (allocated(results%time_points)) then
          do it=1, results%n_time_points
            do g=1, size(results%dpower_dxs_t, 1)
              write(iu, '(E15.7,I3,3(1X,E15.7))') results%time_points(it), g, &
                  results%dpower_dxs_t(g, it), results%dalpha_dxs_t(g, it), results%dkeff_dxs_t(g, it)
            end do
          end do
        end if
        
        close(iu)
        print *, "Transient sensitivity results written to: ", trim(transient_filename)
      end if
    end if
  end subroutine

  subroutine run_sensitivity_analysis(st, ctrl, output_file, deck_file, transient_mode)
    ! Wrapper function to run sensitivity analysis from main program
    ! Now supports both steady-state and transient sensitivity
    type(State), intent(inout) :: st
    type(Control), intent(inout) :: ctrl  ! Changed to inout for checkpoint restore
    character(len=*), intent(in) :: output_file
    character(len=*), intent(in), optional :: deck_file  ! Input deck file for transient sensitivity
    logical, intent(in), optional :: transient_mode      ! Flag for transient sensitivity
    
    type(SensitivityResults) :: results
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
    
    print *, "Running sensitivity analysis"
    if (do_transient) then
      print *, "  Mode: TRANSIENT (full simulations)"
    else
      print *, "  Mode: STEADY-STATE (k-eigenvalue only)"
    end if
    
    ! Run sensitivity analysis
    if (do_transient .and. len_trim(deck_file_used) > 0) then
      call calculate_sensitivities(st, ctrl, results, iostat, deck_file=deck_file_used, transient_mode=.true.)
    else
      call calculate_sensitivities(st, ctrl, results, iostat)
    end if
    
    if (iostat == 0) then
      ! Write results
      call write_sensitivity_results(results, trim(output_file), iostat)
      if (iostat == 0) then
        print *, "Sensitivity results written to: ", trim(output_file)
        if (allocated(results%dk_dxs)) then
          print *, "  Sensitivity to cross sections (dk/dxs):"
          print *, "    Group 1: ", results%dk_dxs(1)
          if (size(results%dk_dxs) > 1) then
            print *, "    Group 2: ", results%dk_dxs(2)
          end if
        end if
        if (allocated(results%dk_dbeta)) then
          print *, "  Sensitivity to delayed neutrons (dk/dbeta):"
          print *, "    Group 1: ", results%dk_dbeta(1)
        end if
        if (do_transient .and. results%transient_sensitivity) then
          print *, "  Transient sensitivity: ", results%n_time_points, " time points"
        end if
      else
        print *, "Error writing sensitivity results"
      end if
    else
      print *, "Error running sensitivity analysis: iostat=", iostat
    end if
  end subroutine

end module sensitivity_mod

