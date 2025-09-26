module eos_table
  use kinds
  implicit none
  type :: EOSTable
     integer :: nr=0, nt=0
     real(rk), allocatable :: rho(:), temp(:)
     real(rk), allocatable :: P(:,:), Cv(:,:)   ! (nr, nt)
  end type
contains
  subroutine read_eos_csv(path, tbl, ios)
    character(len=*), intent(in) :: path
    type(EOSTable),   intent(inout) :: tbl
    integer,          intent(out) :: ios
    integer :: iu, i, j, nr, nt
    ios = 0
    open(newunit=iu, file=path, status='old', action='read', iostat=ios)
    if (ios/=0) return
    read(iu,*) nr, nt
    allocate(tbl%rho(nr), tbl%temp(nt), tbl%P(nr,nt), tbl%Cv(nr,nt))
    do i=1, nr
      read(iu,*) tbl%rho(i)
    end do
    do j=1, nt
      read(iu,*) tbl%temp(j)
    end do
    do i=1, nr
      read(iu,*) tbl%P(i,1:nt)
    end do
    do i=1, nr
      read(iu,*) tbl%Cv(i,1:nt)
    end do
    close(iu)
  end subroutine

  subroutine eos_lookup(tbl, rho, T, P, Cv)
    type(EOSTable), intent(in) :: tbl
    real(rk), intent(in) :: rho, T
    real(rk), intent(out):: P, Cv
    integer :: i, j
    real(rk) :: fr, ft
    i = max(1, min(tbl%nr-1, count(tbl%rho <= rho)))
    j = max(1, min(tbl%nt-1, count(tbl%temp <= T)))
    fr = 0._rk; if (tbl%rho(i+1)>tbl%rho(i)) fr = (rho - tbl%rho(i)) / (tbl%rho(i+1)-tbl%rho(i))
    ft = 0._rk; if (tbl%temp(j+1)>tbl%temp(j)) ft = (T - tbl%temp(j)) / (tbl%temp(j+1)-tbl%temp(j))
    P  = (1-fr)*(1-ft)*tbl%P(i,j) + fr*(1-ft)*tbl%P(i+1,j) + (1-fr)*ft*tbl%P(i,j+1) + fr*ft*tbl%P(i+1,j+1)
    Cv = (1-fr)*(1-ft)*tbl%Cv(i,j)+ fr*(1-ft)*tbl%Cv(i+1,j)+ (1-fr)*ft*tbl%Cv(i,j+1)+ fr*ft*tbl%Cv(i+1,j+1)
  end subroutine
end module eos_table
