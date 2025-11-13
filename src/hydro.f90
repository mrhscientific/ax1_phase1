module hydro
  use kinds
  use types
  use utils, only: shell_volume, safe_div, minmod
  implicit none
contains
  subroutine hydro_step(st, ctrl, c_vp)
    type(State),   intent(inout) :: st
    type(Control), intent(inout) :: ctrl
    real(rk),      intent(in)    :: c_vp
    integer :: i
    real(rk) :: dt, dr, acc, vol
    real(rk), allocatable :: piface(:), uiface(:)
    real(rk) :: pL, pR, uL, uR, cL, cR, pPVRS
    real(rk) :: dpL, dpR, duL, duR  ! gradients for slope limiting
    real(rk) :: drL, drR  ! distances for reconstruction
    dt = ctrl%dt

    do i=1, st%Nshell
      st%sh(i)%p_visc = 0._rk
      st%sh(i)%p = st%sh(i)%p_hyd
    end do

    if (.not. allocated(piface)) allocate(piface(st%Nshell+1))
    if (.not. allocated(uiface)) allocate(uiface(st%Nshell+1))
    
    ! boundary interfaces: simple reflective
    piface(1) = st%sh(1)%p
    piface(st%Nshell+1) = st%sh(st%Nshell)%p
    uiface(1) = st%sh(1)%vel
    uiface(st%Nshell+1) = st%sh(st%Nshell)%vel
    
    do i=1, st%Nshell-1
      ! Compute gradients (limited slopes) using minmod limiter
      if (i > 1) then
        dpL = (st%sh(i)%p - st%sh(i-1)%p) / max(st%sh(i)%rbar - st%sh(i-1)%rbar, 1.0e-12_rk)
        duL = (st%sh(i)%vel - st%sh(i-1)%vel) / max(st%sh(i)%rbar - st%sh(i-1)%rbar, 1.0e-12_rk)
      else
        dpL = 0._rk
        duL = 0._rk
      end if
      if (i+1 < st%Nshell) then
        dpR = (st%sh(i+2)%p - st%sh(i+1)%p) / max(st%sh(i+2)%rbar - st%sh(i+1)%rbar, 1.0e-12_rk)
        duR = (st%sh(i+2)%vel - st%sh(i+1)%vel) / max(st%sh(i+2)%rbar - st%sh(i+1)%rbar, 1.0e-12_rk)
      else
        dpR = 0._rk
        duR = 0._rk
      end if
      
      ! Reconstruct interface values from left and right
      drL = max(st%sh(i+1)%rbar - st%sh(i)%rbar, 1.0e-12_rk)
      drR = max(st%sh(i+1)%rbar - st%sh(i)%rbar, 1.0e-12_rk)
      
      pL = st%sh(i)%p + 0.5_rk * minmod(dpL, (st%sh(i+1)%p - st%sh(i)%p) / drL) * drL
      uL = st%sh(i)%vel + 0.5_rk * minmod(duL, (st%sh(i+1)%vel - st%sh(i)%vel) / drL) * drL
      
      pR = st%sh(i+1)%p - 0.5_rk * minmod(dpR, (st%sh(i+1)%p - st%sh(i)%p) / drR) * drR
      uR = st%sh(i+1)%vel - 0.5_rk * minmod(duR, (st%sh(i+1)%vel - st%sh(i)%vel) / drR) * drR
      
      cL = sqrt(max(st%eos(i)%a, 1.0e-8_rk))
      cR = sqrt(max(st%eos(i+1)%a, 1.0e-8_rk))
      
      ! HLLC Riemann solver with limited states
      pPVRS = 0.5_rk*(pL+pR) - 0.5_rk*(uR-uL)*0.5_rk*(cL+cR)
      piface(i+1) = max(0._rk, pPVRS)
      
      ! Interface velocity
      uiface(i+1) = 0.5_rk*(uL + uR)
    end do

    do i=1, st%Nshell
      dr  = max(st%sh(i)%r_out - st%sh(i)%r_in, 1.0e-12_rk)
      acc = - (piface(i+1) - piface(i)) / dr / max(st%sh(i)%rho, 1.0e-30_rk)
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
