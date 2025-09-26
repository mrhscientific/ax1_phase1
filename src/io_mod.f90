module io_mod
  use kinds
  use types
  implicit none
contains
  subroutine banner()
    print *, "AX-1 Phase 1 — S4 (spherical), alpha-eigen, delayed groups, EOS tables, CFL+W"
  end subroutine
  subroutine step_line(st, ctrl, tag)
    type(State),   intent(in) :: st
    type(Control), intent(in) :: ctrl
    character(len=*), intent(in) :: tag
    write(*,'(a,f9.5,2x,a,f10.6,2x,a,f9.5,2x,a,i3,2x,a)') &
      "t=", st%time, "alpha=", st%alpha, "keff=", st%k_eff, "H/neu=", ctrl%hydro_per_neut, trim(tag)
  end subroutine
  subroutine warn(msg)
    character(len=*), intent(in) :: msg
    write(*,'(a)') "[WARN] "//trim(msg)
  end subroutine
end module io_mod
