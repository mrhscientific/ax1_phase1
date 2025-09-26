module thermo
  use kinds
  use types
  use eos_table
  implicit none
  type(EOSTable), allocatable :: tbl(:)  ! one per shell optional
contains
  subroutine attach_tables(nshell)
    integer, intent(in) :: nshell
    if (.not. allocated(tbl)) allocate(tbl(nshell))
  end subroutine

  subroutine update_thermo(st, i, dE_spec)
    type(State), intent(inout) :: st
    integer,     intent(in)    :: i
    real(rk),    intent(in)    :: dE_spec
    real(rk) :: Cv, T, Ptab
    if (st%eos(i)%tabular) then
      call eos_lookup(tbl(i), st%sh(i)%rho, st%sh(i)%temp, Ptab, Cv)
      st%sh(i)%eint = st%sh(i)%eint + dE_spec
      if (Cv>0._rk) st%sh(i)%temp = st%sh(i)%temp + dE_spec/Cv
      st%sh(i)%p_hyd = Ptab
    else
      Cv = st%eos(i)%Acv + st%eos(i)%Bcv*st%sh(i)%temp
      st%sh(i)%eint = st%sh(i)%eint + dE_spec
      if (Cv>0._rk) st%sh(i)%temp = st%sh(i)%temp + dE_spec/Cv
      T = st%sh(i)%temp
      st%sh(i)%p_hyd = st%eos(i)%a*st%sh(i)%rho + st%eos(i)%b + st%eos(i)%c*T
    end if
    st%sh(i)%p = st%sh(i)%p_hyd + st%sh(i)%p_visc
  end subroutine

  subroutine visc_pressure(st, i, dr, dt, c_vp)
    type(State), intent(inout) :: st
    integer, intent(in) :: i
    real(rk), intent(in) :: dr, dt, c_vp
    real(rk) :: vgrad
    if (dt<=0._rk .or. dr<=0._rk) then
      st%sh(i)%p_visc = 0._rk; return
    end if
    vgrad = st%sh(i)%vel / dr
    if (vgrad < 0._rk) then
      st%sh(i)%p_visc = c_vp * ( -vgrad )**2
    else
      st%sh(i)%p_visc = 0._rk
    end if
  end subroutine
end module thermo
