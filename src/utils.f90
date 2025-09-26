module utils
  use kinds
  use constants
  implicit none
contains
  pure function shell_volume(rin, rout) result(v)
    real(rk), intent(in) :: rin, rout
    real(rk) :: v
    v = (4._rk/3._rk)*pi*(max(rout,0._rk)**3 - max(rin,0._rk)**3)
  end function

  pure function safe_div(a,b, default) result(x)
    real(rk), intent(in) :: a, b, default
    real(rk) :: x
    if (abs(b) > 1.0e-30_rk) then
      x = a/b
    else
      x = default
    end if
  end function

  pure function clamp(x, lo, hi) result(y)
    real(rk), intent(in) :: x, lo, hi
    real(rk) :: y
    y = min(max(x, lo), hi)
  end function
end module utils
