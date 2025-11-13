module history_mod
  use kinds
  use types
  implicit none
contains

  subroutine initialize_history(st)
    ! Initialize time history arrays
    type(State), intent(inout) :: st
    
    if (allocated(st%time_history)) deallocate(st%time_history)
    if (allocated(st%power_history)) deallocate(st%power_history)
    if (allocated(st%alpha_history)) deallocate(st%alpha_history)
    if (allocated(st%keff_history)) deallocate(st%keff_history)
    if (allocated(st%reactivity_history)) deallocate(st%reactivity_history)
    if (allocated(st%radius_history)) deallocate(st%radius_history)
    if (allocated(st%velocity_history)) deallocate(st%velocity_history)
    if (allocated(st%pressure_history)) deallocate(st%pressure_history)
    if (allocated(st%temp_history)) deallocate(st%temp_history)
    
    allocate(st%time_history(st%history_size))
    allocate(st%power_history(st%history_size))
    allocate(st%alpha_history(st%history_size))
    allocate(st%keff_history(st%history_size))
    allocate(st%reactivity_history(st%history_size))
    allocate(st%radius_history(st%Nshell, st%history_size))
    allocate(st%velocity_history(st%Nshell, st%history_size))
    allocate(st%pressure_history(st%Nshell, st%history_size))
    allocate(st%temp_history(st%Nshell, st%history_size))
    
    st%time_history = 0.0_rk
    st%power_history = 0.0_rk
    st%alpha_history = 0.0_rk
    st%keff_history = 0.0_rk
    st%reactivity_history = 0.0_rk
    st%radius_history = 0.0_rk
    st%velocity_history = 0.0_rk
    st%pressure_history = 0.0_rk
    st%temp_history = 0.0_rk
    
    st%history_count = 0
  end subroutine

  subroutine record_history(st, ctrl)
    ! Record current state to history
    type(State), intent(inout) :: st
    type(Control), intent(in)  :: ctrl
    ! Note: ctrl is kept for future use (output frequency control)
    ! Currently unused but may be needed for adaptive output
    
    integer :: i, n
    
    n = st%history_count + 1
    if (n > st%history_size) then
      ! Resize history arrays if needed
      call resize_history(st)
      n = st%history_count + 1
    end if
    
    st%time_history(n) = st%time
    st%power_history(n) = st%total_power
    st%alpha_history(n) = st%alpha
    st%keff_history(n) = st%k_eff
    st%reactivity_history(n) = st%reactivity
    
    do i=1, st%Nshell
      st%radius_history(i, n) = st%sh(i)%rbar
      st%velocity_history(i, n) = st%sh(i)%vel
      st%pressure_history(i, n) = st%sh(i)%p
      st%temp_history(i, n) = st%sh(i)%temp
    end do
    
    st%history_count = n
  end subroutine

  subroutine resize_history(st)
    ! Resize history arrays (double size)
    type(State), intent(inout) :: st
    
    integer :: old_size, new_size, i
    real(rk), allocatable :: temp_time(:), temp_power(:), temp_alpha(:), temp_keff(:), temp_reactivity(:)
    real(rk), allocatable :: temp_radius(:,:), temp_velocity(:,:), temp_pressure(:,:), temp_temp(:,:)
    
    old_size = st%history_size
    new_size = old_size * 2
    
    ! Save existing data
    if (allocated(st%time_history)) then
      allocate(temp_time(old_size))
      allocate(temp_power(old_size))
      allocate(temp_alpha(old_size))
      allocate(temp_keff(old_size))
      allocate(temp_reactivity(old_size))
      allocate(temp_radius(st%Nshell, old_size))
      allocate(temp_velocity(st%Nshell, old_size))
      allocate(temp_pressure(st%Nshell, old_size))
      allocate(temp_temp(st%Nshell, old_size))
      
      temp_time = st%time_history
      temp_power = st%power_history
      temp_alpha = st%alpha_history
      temp_keff = st%keff_history
      temp_reactivity = st%reactivity_history
      temp_radius = st%radius_history
      temp_velocity = st%velocity_history
      temp_pressure = st%pressure_history
      temp_temp = st%temp_history
    end if
    
    ! Resize arrays
    deallocate(st%time_history, st%power_history, st%alpha_history, st%keff_history, st%reactivity_history)
    deallocate(st%radius_history, st%velocity_history, st%pressure_history, st%temp_history)
    
    st%history_size = new_size
    allocate(st%time_history(new_size))
    allocate(st%power_history(new_size))
    allocate(st%alpha_history(new_size))
    allocate(st%keff_history(new_size))
    allocate(st%reactivity_history(new_size))
    allocate(st%radius_history(st%Nshell, new_size))
    allocate(st%velocity_history(st%Nshell, new_size))
    allocate(st%pressure_history(st%Nshell, new_size))
    allocate(st%temp_history(st%Nshell, new_size))
    
    ! Restore existing data
    if (allocated(temp_time)) then
      do i=1, old_size
        st%time_history(i) = temp_time(i)
        st%power_history(i) = temp_power(i)
        st%alpha_history(i) = temp_alpha(i)
        st%keff_history(i) = temp_keff(i)
        st%reactivity_history(i) = temp_reactivity(i)
        st%radius_history(:, i) = temp_radius(:, i)
        st%velocity_history(:, i) = temp_velocity(:, i)
        st%pressure_history(:, i) = temp_pressure(:, i)
        st%temp_history(:, i) = temp_temp(:, i)
      end do
      deallocate(temp_time, temp_power, temp_alpha, temp_keff, temp_reactivity)
      deallocate(temp_radius, temp_velocity, temp_pressure, temp_temp)
    end if
  end subroutine

  subroutine write_time_history(st, filename)
    ! Write time history to CSV file
    type(State), intent(in) :: st
    character(len=*), intent(in) :: filename
    
    integer :: iu, i
    integer :: ios
    
    open(newunit=iu, file=filename, status='replace', action='write', iostat=ios)
    if (ios /= 0) then
      print *, "Error opening output file: ", trim(filename)
      return
    end if
    
    ! Write header
    write(iu, '(A)') "# Time history output"
    write(iu, '(A)') "# Columns: time, power, alpha, keff, reactivity"
    write(iu, '(A)') "# time (s), power (W), alpha (1/s), keff, reactivity (pcm)"
    
    ! Write data
    do i=1, st%history_count
      write(iu, '(5(E15.7,1X))') &
        st%time_history(i), &
        st%power_history(i), &
        st%alpha_history(i), &
        st%keff_history(i), &
        st%reactivity_history(i)
    end do
    
    close(iu)
  end subroutine

  subroutine write_spatial_history(st, filename)
    ! Write spatial history (radius, velocity, pressure, temperature) to file
    type(State), intent(in) :: st
    character(len=*), intent(in) :: filename
    
    integer :: iu, i, j
    integer :: ios
    
    open(newunit=iu, file=filename, status='replace', action='write', iostat=ios)
    if (ios /= 0) then
      print *, "Error opening output file: ", trim(filename)
      return
    end if
    
    ! Write header
    write(iu, '(A)') "# Spatial history output"
    write(iu, '(A)') "# Columns: time, shell_index, radius, velocity, pressure, temperature"
    write(iu, '(A)') "# time (s), shell, radius (m), velocity (m/s), pressure (Pa), temperature (K)"
    
    ! Write data
    do i=1, st%history_count
      do j=1, st%Nshell
        write(iu, '(I6,1X,F12.6,1X,I4,1X,4(E15.7,1X))') &
          i, &
          st%time_history(i), &
          j, &
          st%radius_history(j, i), &
          st%velocity_history(j, i), &
          st%pressure_history(j, i), &
          st%temp_history(j, i)
      end do
    end do
    
    close(iu)
  end subroutine

end module history_mod

