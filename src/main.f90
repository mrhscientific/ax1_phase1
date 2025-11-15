program ax1
  use kinds
  use types
  use io_mod
  use input_parser
  use neutronics_s4_alpha
  use thermo
  use hydro
  use controls
  use reactivity_feedback
  use history_mod
  use checkpoint_mod
  use uq_mod
  use sensitivity_mod
  use temperature_xs
  implicit none

  type(State)   :: st
  type(Control) :: ctrl
  integer :: step, i, j, nh, iostat
  real(rk) :: alpha_prev=0._rk, power_prev=0._rk
  real(rk) :: dtE, dE_spec, W, c_vp
  real(rk) :: k, alpha

  character(len=256) :: deck
  if (command_argument_count()>=1) then
    call get_command_argument(1, deck)
  else
    deck = "inputs/sample_phase1.deck"
  end if

  call banner()
  
  ! Load deck first to get all parameters (including restart file if specified)
  call load_deck(deck, st, ctrl)
  
  ! Set up neutronics (needed before restart or normal run)
  call set_Sn_quadrature(st, ctrl%Sn_order)
  call neutronics_set_controls(ctrl)
  call ensure_neutronics_arrays(st)
  
  ! Phase 3: Restart from checkpoint if specified
  if (ctrl%use_restart .and. len_trim(ctrl%restart_file) > 0) then
    iostat = 0
    call read_checkpoint(st, ctrl, trim(ctrl%restart_file), iostat)
    if (iostat == 0) then
      print *, "Restarted from checkpoint: ", trim(ctrl%restart_file)
      print *, "  Time: ", st%time
      print *, "  keff: ", st%k_eff
      ! Reference cross sections should be restored from checkpoint
      ! But if not, store them now (for materials that weren't in checkpoint)
      call store_reference_xs(st)
    else
      print *, "Error reading checkpoint file: ", trim(ctrl%restart_file), " iostat=", iostat
      stop
    end if
  else
    ! Phase 3: Store reference cross sections for temperature-dependent materials
    call store_reference_xs(st)
    
    ! Phase 3: Initialize history arrays
    call initialize_history(st)
    
    ! Phase 3: Set reference density if not set
    if (st%feedback%rho_ref <= 0.0_rk) then
      st%feedback%rho_ref = 0.0_rk
      do i=1, st%Nshell
        st%feedback%rho_ref = st%feedback%rho_ref + st%sh(i)%rho
      end do
      st%feedback%rho_ref = st%feedback%rho_ref / max(st%Nshell, 1)
    end if
  end if
  
  c_vp = 1.0_rk
  k = 1.0_rk

  step = 0
  do while (st%time < ctrl%t_end)   ! Phase 3: Use configurable end time
    step = step + 1

    ! Phase 3: Calculate reactivity feedback before neutronics
    if (st%feedback%enable_doppler .or. st%feedback%enable_expansion .or. st%feedback%enable_void) then
      call calculate_reactivity_feedback(st, ctrl)
    end if

    if (.not. ctrl%skip_neutronics) then
      if (trim(ctrl%eigmode) == "alpha") then
        call solve_alpha_by_root(st, alpha, k, use_dsa=ctrl%use_dsa)
        st%alpha = alpha
        call finalize_power_and_alpha(st, k, include_delayed=.true.)
      else
        call sweep_spherical_k(st, k, alpha=0._rk, tol=1.0e-5_rk, itmax=200, use_dsa=ctrl%use_dsa)
        call finalize_power_and_alpha(st, k, include_delayed=.false.)
        ! alpha via prompt Λ (optional): left out; alpha remains from previous or zero
      end if

      ! Phase 3: Update reactivity from k_eff
      call update_reactivity_from_k(st)
    else
      ! Neutronics skipped (hydro-only run); maintain neutral defaults
      if (.not. allocated(st%power_frac)) allocate(st%power_frac(st%Nshell))
      st%power_frac = 1._rk/real(max(1, st%Nshell), rk)
      st%total_power = 0._rk
      st%alpha = 0._rk
      st%k_eff = 1._rk
      st%reactivity = ctrl%rho_insert
    end if

    if (ctrl%skip_neutronics) then
      call step_line(st, ctrl, "[neutronics skipped]")
    else
      call step_line(st, ctrl, "[neutronics]")
    end if

    ! THERMO + HYDRO for Ns4 sub-steps
    nh = ctrl%hydro_per_neut
    dtE = st%total_power * ctrl%dt
    do i=1, nh
       ! update delayed precursors
       call update_precursors(st, ctrl%dt)
       do j=1, st%Nshell
         dE_spec = dtE * st%power_frac(j) / max(st%sh(j)%mass, 1.0e-30_rk)
         call update_thermo(st, j, dE_spec)
       end do
       call hydro_step(st, ctrl, c_vp)
       st%time = st%time + ctrl%dt
       call step_line(st, ctrl, "[hydro]")
    end do

    ! Phase 3: Record time history
    if (mod(step, ctrl%output_freq) == 0) then
      call record_history(st, ctrl)
    end if

      ! Phase 3: Write checkpoint
    if (ctrl%write_checkpoint .and. len_trim(ctrl%checkpoint_file) > 0) then
      if (mod(step, ctrl%checkpoint_freq) == 0) then
        iostat = 0
        call write_checkpoint(st, ctrl, trim(ctrl%checkpoint_file), iostat)
        if (iostat == 0) then
          print *, "Checkpoint written: ", trim(ctrl%checkpoint_file), " at step ", step
        end if
      end if
    end if

    call compute_W_metric(st, W)
    call adapt(st, ctrl, alpha_prev, power_prev, W)
    alpha_prev = st%alpha
    power_prev = st%total_power
  end do

  ! Phase 3: Record final state
  call record_history(st, ctrl)

  ! Phase 3: Write output files
  if (len_trim(ctrl%output_file) > 0) then
    call write_time_history(st, trim(ctrl%output_file)//"_time.csv")
    call write_spatial_history(st, trim(ctrl%output_file)//"_spatial.csv")
    print *, "Output files written:"
    print *, "  Time history: ", trim(ctrl%output_file)//"_time.csv"
    print *, "  Spatial history: ", trim(ctrl%output_file)//"_spatial.csv"
  end if

  ! Phase 3: Run UQ if requested
  if (ctrl%run_uq) then
    print *, ""
    print *, "=== Running Uncertainty Quantification ==="
    if (len_trim(ctrl%uq_output_file) > 0) then
      ! Run transient UQ (use deck file and transient mode)
      call run_uq_analysis(st, ctrl, trim(ctrl%uq_output_file), deck_file=deck, transient_mode=.true.)
    else
      call run_uq_analysis(st, ctrl, "uq_results.csv", deck_file=deck, transient_mode=.true.)
    end if
    print *, "UQ analysis complete"
  end if

  ! Phase 3: Run sensitivity analysis if requested
  if (ctrl%run_sensitivity) then
    print *, ""
    print *, "=== Running Sensitivity Analysis ==="
    if (len_trim(ctrl%sensitivity_output_file) > 0) then
      ! Run transient sensitivity (use deck file and transient mode)
      call run_sensitivity_analysis(st, ctrl, trim(ctrl%sensitivity_output_file), deck_file=deck, transient_mode=.true.)
    else
      call run_sensitivity_analysis(st, ctrl, "sensitivity_results.csv", deck_file=deck, transient_mode=.true.)
    end if
    print *, "Sensitivity analysis complete"
  end if

  call print_perf_summary(st)
  print *, "Done."
end program ax1
