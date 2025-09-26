module controls
  use kinds
  use types
  implicit none
contains
  subroutine compute_W_metric(st, W)
    type(State), intent(in) :: st
    real(rk),    intent(out):: W
    integer :: i
    real(rk) :: sumv
    sumv = 0._rk; W=0._rk
    do i=1, st%Nshell
      sumv = sumv + abs(st%sh(i)%vel)
      W = max(W, abs(st%sh(i)%vel))
    end do
    W = W / max(1.0_rk, sumv/max(1,st%Nshell))
  end subroutine

  subroutine enforce_CFL(st, ctrl)
    type(State),   intent(in)    :: st
    type(Control), intent(inout) :: ctrl
    integer :: i
    real(rk) :: c, u, dr, dt_cfl, dt_new
    dt_new = ctrl%dt
    do i=1, st%Nshell
      dr = max(st%sh(i)%r_out - st%sh(i)%r_in, 1.0e-12_rk)
      ! sound speed proxy: c = sqrt(max(a, eps))
      c = sqrt(max(st%eos(i)%a, 1.0e-8_rk))
      u = abs(st%sh(i)%vel)
      dt_cfl = ctrl%cfl * dr / max(c + u, 1.0e-12_rk)
      dt_new = min(dt_new, dt_cfl)
    end do
    ctrl%dt = max(min(dt_new, ctrl%dt_max), ctrl%dt_min)
  end subroutine

  subroutine adapt(st, ctrl, alpha_prev, power_prev, W)
    type(State),   intent(in)    :: st
    type(Control), intent(inout) :: ctrl
    real(rk),      intent(in)    :: alpha_prev, power_prev, W
    real(rk) :: da, dp
    da = 0._rk; if (abs(alpha_prev)>0._rk) da = abs(st%alpha-alpha_prev)/max(abs(alpha_prev),1.0e-30_rk)
    dp = 0._rk; if (abs(power_prev)>0._rk) dp = abs(st%total_power-power_prev)/max(abs(power_prev),1.0e-30_rk)

    if (da>ctrl%alpha_delta_limit .or. dp>ctrl%power_delta_limit .or. W>ctrl%w_limit) then
      ctrl%hydro_per_neut = max(1, ctrl%hydro_per_neut/2)
    else
      ctrl%hydro_per_neut = min(ctrl%hydro_per_neut+1, ctrl%hydro_per_neut_max)
    end if
    call enforce_CFL(st, ctrl)
  end subroutine
end module controls
