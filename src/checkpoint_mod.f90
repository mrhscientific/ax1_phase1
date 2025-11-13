module checkpoint_mod
  use kinds
  use types
  implicit none
contains

  subroutine write_checkpoint(st, ctrl, filename, iostat)
    ! Write checkpoint file with current state
    type(State), intent(in) :: st
    type(Control), intent(in) :: ctrl
    character(len=*), intent(in) :: filename
    integer, intent(out) :: iostat
    
    integer :: iu, i, g, j
    
    iostat = 0
    open(newunit=iu, file=filename, status='replace', action='write', form='unformatted', iostat=iostat)
    if (iostat /= 0) return
    
    ! Write header
    write(iu, iostat=iostat) 'AX1_CHECKPOINT_V1'
    
    ! Write Control type
    write(iu, iostat=iostat) ctrl%eigmode
    write(iu, iostat=iostat) ctrl%dt, ctrl%dt_max, ctrl%dt_min
    write(iu, iostat=iostat) ctrl%hydro_per_neut, ctrl%hydro_per_neut_max
    write(iu, iostat=iostat) ctrl%w_limit, ctrl%alpha_delta_limit, ctrl%power_delta_limit
    write(iu, iostat=iostat) ctrl%cfl
    write(iu, iostat=iostat) ctrl%Sn_order, ctrl%use_dsa
    write(iu, iostat=iostat) ctrl%upscatter, ctrl%upscatter_scale
    write(iu, iostat=iostat) ctrl%rho_insert, ctrl%rho_profile, ctrl%use_rho_profile
    write(iu, iostat=iostat) ctrl%t_end, ctrl%output_freq, ctrl%output_file
    
    ! Write State type
    write(iu, iostat=iostat) st%Nshell, st%G, st%nmat, st%Nmu
    write(iu, iostat=iostat) st%vbar, st%k_eff, st%alpha, st%time, st%total_power
    write(iu, iostat=iostat) st%transport_iterations, st%dsa_iterations
    write(iu, iostat=iostat) st%reactivity, st%rho_doppler, st%rho_expansion, st%rho_void, st%rho_inserted
    
    ! Write ReactivityFeedback
    write(iu, iostat=iostat) st%feedback%doppler_coef, st%feedback%expansion_coef, st%feedback%void_coef
    write(iu, iostat=iostat) st%feedback%enable_doppler, st%feedback%enable_expansion, st%feedback%enable_void
    write(iu, iostat=iostat) st%feedback%T_ref, st%feedback%rho_ref
    
    ! Write shells
    if (allocated(st%sh)) then
      write(iu, iostat=iostat) .true.
      do i=1, st%Nshell
        write(iu, iostat=iostat) st%sh(i)%r_in, st%sh(i)%r_out, st%sh(i)%rbar
        write(iu, iostat=iostat) st%sh(i)%vel, st%sh(i)%mass, st%sh(i)%rho
        write(iu, iostat=iostat) st%sh(i)%eint, st%sh(i)%temp
        write(iu, iostat=iostat) st%sh(i)%p_hyd, st%sh(i)%p_visc, st%sh(i)%p
        write(iu, iostat=iostat) st%sh(i)%mat
      end do
    else
      write(iu, iostat=iostat) .false.
    end if
    
    ! Write EOS
    if (allocated(st%eos)) then
      write(iu, iostat=iostat) .true.
      do i=1, st%Nshell
        write(iu, iostat=iostat) st%eos(i)%a, st%eos(i)%b, st%eos(i)%c
        write(iu, iostat=iostat) st%eos(i)%Acv, st%eos(i)%Bcv
        write(iu, iostat=iostat) st%eos(i)%tabular, st%eos(i)%table_path
      end do
    else
      write(iu, iostat=iostat) .false.
    end if
    
    ! Write materials
    if (allocated(st%mat_of_shell)) then
      write(iu, iostat=iostat) .true.
      write(iu, iostat=iostat) st%mat_of_shell
    else
      write(iu, iostat=iostat) .false.
    end if
    
    ! Write materials
    if (allocated(st%mat)) then
      write(iu, iostat=iostat) .true.
      write(iu, iostat=iostat) st%nmat
      do i=1, st%nmat
        write(iu, iostat=iostat) st%mat(i)%num_groups
        do g=1, st%mat(i)%num_groups
          write(iu, iostat=iostat) st%mat(i)%groups(g)%sig_t, st%mat(i)%groups(g)%nu_sig_f, st%mat(i)%groups(g)%chi
        end do
        do g=1, st%G
          do j=1, st%G
            write(iu, iostat=iostat) st%mat(i)%sig_s(g,j)
          end do
        end do
        write(iu, iostat=iostat) st%mat(i)%beta
        write(iu, iostat=iostat) st%mat(i)%lambda
        write(iu, iostat=iostat) st%mat(i)%temperature_dependent, st%mat(i)%T_ref, st%mat(i)%doppler_exponent
        write(iu, iostat=iostat) st%mat(i)%reference_stored
        ! Write reference cross sections if stored
        if (st%mat(i)%reference_stored) then
          do g=1, st%mat(i)%num_groups
            write(iu, iostat=iostat) st%mat(i)%groups_ref(g)%sig_t, st%mat(i)%groups_ref(g)%nu_sig_f, st%mat(i)%groups_ref(g)%chi
          end do
          do g=1, st%G
            do j=1, st%G
              write(iu, iostat=iostat) st%mat(i)%sig_s_ref(g,j)
            end do
          end do
        end if
      end do
    else
      write(iu, iostat=iostat) .false.
    end if
    
    ! Write neutronics arrays
    if (allocated(st%mu)) then
      write(iu, iostat=iostat) .true.
      write(iu, iostat=iostat) st%mu, st%w
    else
      write(iu, iostat=iostat) .false.
    end if
    
    if (allocated(st%phi)) then
      write(iu, iostat=iostat) .true.
      write(iu, iostat=iostat) st%phi, st%q_scatter, st%q_fiss, st%q_delay, st%power_frac
    else
      write(iu, iostat=iostat) .false.
    end if
    
    if (allocated(st%C)) then
      write(iu, iostat=iostat) .true.
      write(iu, iostat=iostat) st%C
    else
      write(iu, iostat=iostat) .false.
    end if
    
    ! Write time history (optional, may be large)
    write(iu, iostat=iostat) st%history_count
    if (st%history_count > 0 .and. allocated(st%time_history)) then
      write(iu, iostat=iostat) .true.
      write(iu, iostat=iostat) st%history_size
      write(iu, iostat=iostat) st%time_history(1:st%history_count)
      write(iu, iostat=iostat) st%power_history(1:st%history_count)
      write(iu, iostat=iostat) st%alpha_history(1:st%history_count)
      write(iu, iostat=iostat) st%keff_history(1:st%history_count)
      write(iu, iostat=iostat) st%reactivity_history(1:st%history_count)
      write(iu, iostat=iostat) st%radius_history(:, 1:st%history_count)
      write(iu, iostat=iostat) st%velocity_history(:, 1:st%history_count)
      write(iu, iostat=iostat) st%pressure_history(:, 1:st%history_count)
      write(iu, iostat=iostat) st%temp_history(:, 1:st%history_count)
    else
      write(iu, iostat=iostat) .false.
    end if
    
    close(iu)
  end subroutine

  subroutine read_checkpoint(st, ctrl, filename, iostat)
    ! Read checkpoint file and restore state
    type(State), intent(inout) :: st
    type(Control), intent(inout) :: ctrl
    character(len=*), intent(in) :: filename
    integer, intent(out) :: iostat
    
    integer :: iu, i, g, j
    character(len=20) :: header
    logical :: allocated_flag
    integer :: nshell_check, g_check, nmat_check, nmu_check
    integer :: history_count_check, history_size_check
    
    iostat = 0
    open(newunit=iu, file=filename, status='old', action='read', form='unformatted', iostat=iostat)
    if (iostat /= 0) return
    
    ! Read header
    read(iu, iostat=iostat) header
    if (header /= 'AX1_CHECKPOINT_V1') then
      iostat = -1
      close(iu)
      return
    end if
    
    ! Read Control type
    read(iu, iostat=iostat) ctrl%eigmode
    read(iu, iostat=iostat) ctrl%dt, ctrl%dt_max, ctrl%dt_min
    read(iu, iostat=iostat) ctrl%hydro_per_neut, ctrl%hydro_per_neut_max
    read(iu, iostat=iostat) ctrl%w_limit, ctrl%alpha_delta_limit, ctrl%power_delta_limit
    read(iu, iostat=iostat) ctrl%cfl
    read(iu, iostat=iostat) ctrl%Sn_order, ctrl%use_dsa
    read(iu, iostat=iostat) ctrl%upscatter, ctrl%upscatter_scale
    read(iu, iostat=iostat) ctrl%rho_insert, ctrl%rho_profile, ctrl%use_rho_profile
    read(iu, iostat=iostat) ctrl%t_end, ctrl%output_freq, ctrl%output_file
    
    ! Read State type dimensions
    read(iu, iostat=iostat) nshell_check, g_check, nmat_check, nmu_check
    st%Nshell = nshell_check
    st%G = g_check
    st%nmat = nmat_check
    st%Nmu = nmu_check
    
    read(iu, iostat=iostat) st%vbar, st%k_eff, st%alpha, st%time, st%total_power
    read(iu, iostat=iostat) st%transport_iterations, st%dsa_iterations
    read(iu, iostat=iostat) st%reactivity, st%rho_doppler, st%rho_expansion, st%rho_void, st%rho_inserted
    
    ! Read ReactivityFeedback
    read(iu, iostat=iostat) st%feedback%doppler_coef, st%feedback%expansion_coef, st%feedback%void_coef
    read(iu, iostat=iostat) st%feedback%enable_doppler, st%feedback%enable_expansion, st%feedback%enable_void
    read(iu, iostat=iostat) st%feedback%T_ref, st%feedback%rho_ref
    
    ! Read shells
    read(iu, iostat=iostat) allocated_flag
    if (allocated_flag) then
      if (.not. allocated(st%sh)) allocate(st%sh(st%Nshell))
      do i=1, st%Nshell
        read(iu, iostat=iostat) st%sh(i)%r_in, st%sh(i)%r_out, st%sh(i)%rbar
        read(iu, iostat=iostat) st%sh(i)%vel, st%sh(i)%mass, st%sh(i)%rho
        read(iu, iostat=iostat) st%sh(i)%eint, st%sh(i)%temp
        read(iu, iostat=iostat) st%sh(i)%p_hyd, st%sh(i)%p_visc, st%sh(i)%p
        read(iu, iostat=iostat) st%sh(i)%mat
      end do
    end if
    
    ! Read EOS
    read(iu, iostat=iostat) allocated_flag
    if (allocated_flag) then
      if (.not. allocated(st%eos)) allocate(st%eos(st%Nshell))
      do i=1, st%Nshell
        read(iu, iostat=iostat) st%eos(i)%a, st%eos(i)%b, st%eos(i)%c
        read(iu, iostat=iostat) st%eos(i)%Acv, st%eos(i)%Bcv
        read(iu, iostat=iostat) st%eos(i)%tabular, st%eos(i)%table_path
      end do
    end if
    
    ! Read materials mapping
    read(iu, iostat=iostat) allocated_flag
    if (allocated_flag) then
      if (.not. allocated(st%mat_of_shell)) allocate(st%mat_of_shell(st%Nshell))
      read(iu, iostat=iostat) st%mat_of_shell
    end if
    
    ! Read materials
    read(iu, iostat=iostat) allocated_flag
    if (allocated_flag) then
      read(iu, iostat=iostat) st%nmat
      if (.not. allocated(st%mat)) allocate(st%mat(st%nmat))
      do i=1, st%nmat
        read(iu, iostat=iostat) st%mat(i)%num_groups
        do g=1, st%mat(i)%num_groups
          read(iu, iostat=iostat) st%mat(i)%groups(g)%sig_t, st%mat(i)%groups(g)%nu_sig_f, st%mat(i)%groups(g)%chi
        end do
        do g=1, st%G
          do j=1, st%G
            read(iu, iostat=iostat) st%mat(i)%sig_s(g,j)
          end do
        end do
        read(iu, iostat=iostat) st%mat(i)%beta
        read(iu, iostat=iostat) st%mat(i)%lambda
        read(iu, iostat=iostat) st%mat(i)%temperature_dependent, st%mat(i)%T_ref, st%mat(i)%doppler_exponent
        read(iu, iostat=iostat) st%mat(i)%reference_stored
        ! Read reference cross sections if stored
        if (st%mat(i)%reference_stored) then
          do g=1, st%mat(i)%num_groups
            read(iu, iostat=iostat) st%mat(i)%groups_ref(g)%sig_t, st%mat(i)%groups_ref(g)%nu_sig_f, st%mat(i)%groups_ref(g)%chi
          end do
          do g=1, st%G
            do j=1, st%G
              read(iu, iostat=iostat) st%mat(i)%sig_s_ref(g,j)
            end do
          end do
        end if
      end do
    end if
    
    ! Read neutronics arrays
    read(iu, iostat=iostat) allocated_flag
    if (allocated_flag) then
      if (.not. allocated(st%mu)) allocate(st%mu(st%Nmu))
      if (.not. allocated(st%w)) allocate(st%w(st%Nmu))
      read(iu, iostat=iostat) st%mu, st%w
    end if
    
    read(iu, iostat=iostat) allocated_flag
    if (allocated_flag) then
      if (.not. allocated(st%phi)) allocate(st%phi(st%G, st%Nshell))
      if (.not. allocated(st%q_scatter)) allocate(st%q_scatter(st%G, st%Nshell))
      if (.not. allocated(st%q_fiss)) allocate(st%q_fiss(st%G, st%Nshell))
      if (.not. allocated(st%q_delay)) allocate(st%q_delay(st%G, st%Nshell))
      if (.not. allocated(st%power_frac)) allocate(st%power_frac(st%Nshell))
      read(iu, iostat=iostat) st%phi, st%q_scatter, st%q_fiss, st%q_delay, st%power_frac
    end if
    
    read(iu, iostat=iostat) allocated_flag
    if (allocated_flag) then
      if (.not. allocated(st%C)) allocate(st%C(DGRP, st%G, st%Nshell))
      read(iu, iostat=iostat) st%C
    end if
    
    ! Read time history (optional)
    read(iu, iostat=iostat) history_count_check
    st%history_count = history_count_check
    read(iu, iostat=iostat) allocated_flag
    if (allocated_flag .and. st%history_count > 0) then
      read(iu, iostat=iostat) history_size_check
      st%history_size = history_size_check
      if (.not. allocated(st%time_history)) allocate(st%time_history(st%history_size))
      if (.not. allocated(st%power_history)) allocate(st%power_history(st%history_size))
      if (.not. allocated(st%alpha_history)) allocate(st%alpha_history(st%history_size))
      if (.not. allocated(st%keff_history)) allocate(st%keff_history(st%history_size))
      if (.not. allocated(st%reactivity_history)) allocate(st%reactivity_history(st%history_size))
      if (.not. allocated(st%radius_history)) allocate(st%radius_history(st%Nshell, st%history_size))
      if (.not. allocated(st%velocity_history)) allocate(st%velocity_history(st%Nshell, st%history_size))
      if (.not. allocated(st%pressure_history)) allocate(st%pressure_history(st%Nshell, st%history_size))
      if (.not. allocated(st%temp_history)) allocate(st%temp_history(st%Nshell, st%history_size))
      read(iu, iostat=iostat) st%time_history(1:st%history_count)
      read(iu, iostat=iostat) st%power_history(1:st%history_count)
      read(iu, iostat=iostat) st%alpha_history(1:st%history_count)
      read(iu, iostat=iostat) st%keff_history(1:st%history_count)
      read(iu, iostat=iostat) st%reactivity_history(1:st%history_count)
      read(iu, iostat=iostat) st%radius_history(:, 1:st%history_count)
      read(iu, iostat=iostat) st%velocity_history(:, 1:st%history_count)
      read(iu, iostat=iostat) st%pressure_history(:, 1:st%history_count)
      read(iu, iostat=iostat) st%temp_history(:, 1:st%history_count)
    end if
    
    close(iu)
  end subroutine

end module checkpoint_mod

