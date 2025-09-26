module hydro
  use kinds
  use types
  use utils, only: shell_volume, safe_div
  use thermo, only: visc_pressure
  implicit none
contains
  subroutine hydro_step(st, ctrl, c_vp)
    type(State),   intent(inout) :: st
    type(Control), intent(inout) :: ctrl
    real(rk),      intent(in)    :: c_vp
    integer :: i
    real(rk) :: dt, dr, pL, pR, acc, vol
    dt = ctrl%dt

    do i=1, st%Nshell
      dr = max(st%sh(i)%r_out - st%sh(i)%r_in, 1.0e-12_rk)
      call visc_pressure(st, i, dr, dt, c_vp)
      st%sh(i)%p = st%sh(i)%p_hyd + st%sh(i)%p_visc
    end do

    do i=1, st%Nshell
      if (i==1) then
        pL = st%sh(i)%p
      else
        pL = st%sh(i-1)%p
      end if
      if (i<st%Nshell) then
        pR = st%sh(i+1)%p
      else
        pR = st%sh(i)%p
      end if
      dr  = max(st%sh(i)%r_out - st%sh(i)%r_in, 1.0e-12_rk)
      acc = - (pR - pL) / dr / max(st%sh(i)%rho, 1.0e-30_rk)
      st%sh(i)%vel = st%sh(i)%vel + acc*dt
    end do

    do i=1, st%Nshell
      st%sh(i)%r_in  = st%sh(i)%r_in  + st%sh(i)%vel*dt
      st%sh(i)%r_out = st%sh(i)%r_out + st%sh(i)%vel*dt
      vol = shell_volume(st%sh(i)%r_in, st%sh(i)%r_out)
      st%sh(i)%rho = safe_div(st%sh(i)%mass, vol, st%sh(i)%rho)
      st%sh(i)%rbar = 0.5_rk*(st%sh(i)%r_in + st%sh(i)%r_out)
    end do
  end subroutine hydro_step
end module hydro
