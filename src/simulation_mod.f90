module simulation_mod
  use kinds
  use types
  use neutronics_s4_alpha
  use thermo
  use hydro
  use controls
  use reactivity_feedback
  use history_mod
  use checkpoint_mod
  use temperature_xs
  implicit none
  
contains

  subroutine run_transient_simulation(st, ctrl, quiet_mode)
    ! Run a full transient simulation
    ! This is extracted from main.f90 to allow reuse in UQ/sensitivity analysis
    type(State), intent(inout) :: st
    type(Control), intent(inout) :: ctrl
    logical, intent(in), optional :: quiet_mode
    
    integer :: step, i, j, nh
    real(rk) :: alpha_prev, power_prev
    real(rk) :: dtE, dE_spec, W, c_vp
    real(rk) :: k, alpha
    logical :: quiet
    
    quiet = .false.
    if (present(quiet_mode)) quiet = quiet_mode
    
    ! Initialize simulation
    c_vp = 1.0_rk
    k = 1.0_rk
    alpha = 0.0_rk
    alpha_prev = 0.0_rk
    power_prev = 0.0_rk
    step = 0
    
    ! Reset time to start (for UQ/sensitivity, we want fresh start)
    st%time = 0.0_rk
    st%history_count = 0  ! Reset history counter
    
    ! Main simulation loop
    do while (st%time < ctrl%t_end)
      step = step + 1

      ! Phase 3: Calculate reactivity feedback before neutronics
      if (st%feedback%enable_doppler .or. st%feedback%enable_expansion .or. st%feedback%enable_void) then
        call calculate_reactivity_feedback(st, ctrl)
      end if

      if (trim(ctrl%eigmode) == "alpha") then
        call solve_alpha_by_root(st, alpha, k, use_dsa=ctrl%use_dsa)
        st%alpha = alpha
        call finalize_power_and_alpha(st, k, include_delayed=.true.)
      else
        call sweep_spherical_k(st, k, alpha=0._rk, tol=1.0e-5_rk, itmax=200, use_dsa=ctrl%use_dsa)
        call finalize_power_and_alpha(st, k, include_delayed=.false.)
      end if

      ! Phase 3: Update reactivity from k_eff
      call update_reactivity_from_k(st)

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
      end do

      ! Phase 3: Record time history
      if (mod(step, ctrl%output_freq) == 0) then
        call record_history(st, ctrl)
      end if

      call compute_W_metric(st, W)
      call adapt(st, ctrl, alpha_prev, power_prev, W)
      alpha_prev = st%alpha
      power_prev = st%total_power
    end do

    ! Phase 3: Record final state
    call record_history(st, ctrl)
  end subroutine


  subroutine save_simulation_state(st, ctrl, state_backup, ctrl_backup)
    ! Save simulation state for restoration
    ! This is used in UQ/sensitivity to restore state between samples
    type(State), intent(in) :: st
    type(Control), intent(in) :: ctrl
    type(State), intent(out) :: state_backup
    type(Control), intent(out) :: ctrl_backup
    
    ! Copy state (simplified - just copy key fields)
    ! For full state save, use checkpoint functionality
    state_backup = st
    ctrl_backup = ctrl
  end subroutine

  subroutine restore_simulation_state(st, ctrl, state_backup, ctrl_backup)
    ! Restore simulation state from backup
    ! This is used in UQ/sensitivity to restore state between samples
    type(State), intent(inout) :: st
    type(Control), intent(inout) :: ctrl
    type(State), intent(in) :: state_backup
    type(Control), intent(in) :: ctrl_backup
    
    ! Restore state (simplified - just restore key fields)
    st = state_backup
    ctrl = ctrl_backup
    
    ! Re-initialize arrays if needed
    call ensure_neutronics_arrays(st)
  end subroutine

end module simulation_mod

