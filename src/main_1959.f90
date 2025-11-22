! ##############################################################################
! main_1959.f90
!
! 1959 AX-1 Main Program - Big G Loop
!
! Based on: ANL-5977, "Detailed Flow Diagram" pages 27-52
!           Order Numbers 8000-9300
!
! Program structure follows 1959 EXACTLY:
!   BIG G LOOP (Order 8000):
!     1. Neutronics calculation (S4 transport, alpha or k eigenvalue)
!     2. Hydro sub-loop (NS4 cycles)
!        - Update velocities, positions, density
!        - Compute viscous pressure
!        - Solve EOS for temperature
!        - Add fission energy
!     3. Controls and diagnostics
!        - Compute W stability
!        - Adjust time step
!        - VJ-OK-1 test
!        - Output results
!     4. Check termination
!
! ##############################################################################

program ax1_1959
  use kinds
  use types_1959
  use io_1959
  use neutronics_s4_1959
  use hydro_vnr_1959
  use time_control_1959
  implicit none

  type(State_1959) :: state
  type(Control_1959) :: control
  integer :: output_unit
  integer :: big_g_iter, hydro_iter
  logical :: terminate, halve_dt, double_dt, increase_ns4
  character(len=256) :: term_reason, input_file
  real(rk) :: alpha_out, k_out
  
  ! ============================================================================
  ! Initialization
  ! ============================================================================
  print *, "========================================="
  print *, "1959 AX-1 PROMPT NEUTRON CODE"
  print *, "ANL-5977 Faithful Reproduction"
  print *, "========================================="
  print *
  
  ! Get input filename from command line
  if (command_argument_count() < 1) then
    print *, "Usage: ax1_1959 <input_file>"
    stop
  end if
  call get_command_argument(1, input_file)
  
  ! Read input deck
  call read_input_1959(trim(input_file), state, control)
  
  ! Initialize time control
  call init_time_control(control)
  
  ! Open output file
  output_unit = 20
  open(unit=output_unit, file=trim(control%output_file), status='replace', action='write')
  
  ! Echo input
  if (control%print_input) then
    call echo_input(state, control, output_unit)
  end if
  
  ! Write output header
  call write_output_header(output_unit)
  
  ! Initialize Lagrangian coordinates
  call compute_lagrangian_coords(state)
  
  ! ============================================================================
  ! BIG G LOOP (ANL-5977 Order 8000)
  ! ============================================================================
  big_g_iter = 0
  terminate = .false.
  
  print *, "========================================="
  print *, "STARTING BIG G LOOP"
  print *, "========================================="
  
  do while (.not. terminate)
    big_g_iter = big_g_iter + 1
    
    if (mod(big_g_iter, 10) == 0) then
      print *, "Big G iteration", big_g_iter, ", time =", state%TIME, " μsec"
    end if
    
    ! ==========================================================================
    ! STEP 1: NEUTRONICS CALCULATION (Order 8000-8800)
    ! ==========================================================================
    if (.not. control%skip_neutronics) then
      if (trim(control%eigmode) == "alpha") then
        call solve_alpha_eigenvalue_1959(state, control, alpha_out, k_out)
        state%ALPHA = alpha_out
        state%AKEFF = k_out
      else
        call solve_k_eigenvalue_1959(state, control, k_out)
        state%AKEFF = k_out
        state%ALPHA = 0._rk  ! No alpha in k-mode
      end if
      
      ! Compute total power (fission rate)
      state%TOTAL_POWER = state%FBAR
      if (big_g_iter == 1) state%POWER_PREV = state%TOTAL_POWER
    end if
    
    ! ==========================================================================
    ! STEP 2: HYDRO SUB-LOOP (Order 9050-9200, NS4 times)
    ! ==========================================================================
    do hydro_iter = 1, control%NS4
      state%NH = state%NH + 1
      
      ! Update hydrodynamics
      call hydro_step_1959(state, control)
      
      ! Add fission energy (distributed to zones)
      if (state%TOTAL_POWER > 1.0e-30_rk) then
        call add_fission_energy(state, control, state%TOTAL_POWER, state%FBAR)
      end if
      
      ! Update Lagrangian coordinates
      call compute_lagrangian_coords(state)
    end do
    
    ! Advance time
    state%TIME = state%TIME + control%DELT
    
    ! ==========================================================================
    ! STEP 3: CONTROLS AND DIAGNOSTICS (Order 9210-9290)
    ! ==========================================================================
    
    ! Compute W stability function
    call compute_w_stability(state, control)
    
    ! Compute total energy
    call compute_total_energy(state)
    
    ! Check VJ-OK-1 test for NS4 adjustment
    call check_vj_ok1_test(state, control, increase_ns4)
    if (increase_ns4) then
      control%NS4 = min(control%NS4 + 1, control%HYDRO_PER_NEUT_MAX)
    end if
    
    ! Adjust time step based on stability
    call adjust_timestep_1959(state, control, halve_dt, double_dt)
    if (halve_dt) then
      control%DELT = control%DELT * 0.5_rk
      control%DELT = max(control%DELT, control%DELT_min)
    else if (double_dt) then
      control%DELT = min(control%DELT * 2.0_rk, control%DT_MAX)
    end if
    
    ! ==========================================================================
    ! STEP 4: OUTPUT (Order 9250)
    ! ==========================================================================
    if (mod(big_g_iter, control%output_freq) == 0) then
      call write_output_step(state, control, output_unit)
      flush(output_unit)
    end if
    
    ! Save previous values
    state%QPRIME = state%Q
    state%POWER_PREV = state%TOTAL_POWER
    state%ALPHAP = state%ALPHA
    
    ! ==========================================================================
    ! STEP 5: CHECK TERMINATION (Order 9295-9300)
    ! ==========================================================================
    terminate = check_termination(state, control, term_reason)
    
    if (terminate) then
      print *, "========================================="
      print *, "TERMINATION: ", trim(term_reason)
      print *, "========================================="
      exit
    end if
    
    ! Safety check for runaway iterations
    if (big_g_iter > 1000000) then
      print *, "WARNING: Maximum iterations exceeded!"
      terminate = .true.
      term_reason = "Maximum iterations (safety)"
      exit
    end if
    
  end do  ! End Big G loop
  
  ! ============================================================================
  ! FINALIZATION
  ! ============================================================================
  
  ! Write final output
  call write_output_step(state, control, output_unit)
  
  ! Write summary
  call write_summary(state, control, output_unit)
  
  ! Close output
  close(output_unit)
  
  print *, "========================================="
  print *, "SIMULATION COMPLETE"
  print *, "Final time:    ", state%TIME, " μsec"
  print *, "Iterations:    ", big_g_iter
  print *, "Hydro cycles:  ", state%NH
  print *, "Output file:   ", trim(control%output_file)
  print *, "========================================="
  
end program ax1_1959

