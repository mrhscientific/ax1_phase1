module input_parser
  use kinds
  use types
  use utils, only: shell_volume
  use eos_table
  use thermo, only: attach_tables
  implicit none
contains
  subroutine load_deck(filename, st, ctrl)
    character(len=*), intent(in) :: filename
    type(State),      intent(inout) :: st
    type(Control),    intent(inout) :: ctrl

    integer :: iu, ios
    character(len=512) :: line, key, section
    character(len=256) :: sval
    integer :: ival, i, g, gp, imat, j

    open(newunit=iu, file=filename, status='old', action='read', iostat=ios)
    if (ios/=0) stop "Cannot open deck file."

    section = ""
    st%Nshell = 0; st%G=0; st%nmat=0

    do
      read(iu,'(A)',iostat=ios) line
      if (ios/=0) exit
      if (len_trim(line)==0) cycle
      if (line(1:1) == "#") cycle
      if (line(1:1) == "[") then
        section = adjustl(line)
        cycle
      end if

      select case (trim(section))
      case ("[controls]")
        read(line,*) key, sval
        select case (trim(key))
        case ("eigmode"); ctrl%eigmode = trim(sval)
        case ("dt"); read(sval,*) ctrl%dt
        case ("hydro_per_neut"); read(sval,*) ctrl%hydro_per_neut
        case ("cfl"); read(sval,*) ctrl%cfl
        end select

      case ("[geometry]")
        read(line,*) key, ival
        if (index(key,"Nshell")>0) st%Nshell = ival
        if (trim(key)=="G") st%G = ival

      case ("[materials]")
        read(line,*) key, ival
        if (index(key,"nmat")>0) then
          st%nmat = ival
          if (.not. allocated(st%mat)) allocate(st%mat(st%nmat))
        end if

      case ("[material]")
        read(line,*) imat
        st%mat(imat)%G = st%G

      case ("[xs_group]")
        read(line,*) imat, g, st%mat(imat)%g(g)%sig_t, st%mat(imat)%g(g)%nu_sig_f, st%mat(imat)%g(g)%chi

      case ("[scatter]")
        read(line,*) imat, gp, g, st%mat(imat)%sig_s(gp,g)

      case ("[delayed]")
        ! imat j beta lambda
        read(line,*) imat, j, st%mat(imat)%beta(j), st%mat(imat)%lambda(j)

      case ("[eos]")
        if (.not. allocated(st%eos)) allocate(st%eos(max(st%Nshell,1)))
        integer :: idx; real(rk):: a,b,c,Acv,Bcv; character(len=256):: path
        read(line,*) idx, a, b, c, Acv, Bcv
        st%eos(idx)%a=a; st%eos(idx)%b=b; st%eos(idx)%c=c; st%eos(idx)%Acv=Acv; st%eos(idx)%Bcv=Bcv

      case ("[eos_table]")
        ! i, path
        integer :: idx2, rc
        character(len=256) :: p2
        read(line,*) idx2, p2
        st%eos(idx2)%tabular = .true.
        st%eos(idx2)%table_path = trim(p2)

      case ("[shells]")
        if (.not. allocated(st%sh)) allocate(st%sh(st%Nshell))
        if (.not. allocated(st%mat_of_shell)) allocate(st%mat_of_shell(st%Nshell))
        integer :: idx3, matid
        real(rk) :: r_out, rho0, T0
        read(line,*) idx3, r_out, matid, rho0, T0
        st%mat_of_shell(idx3)=matid
        st%sh(idx3)%r_out = r_out
        st%sh(idx3)%rho = rho0
        st%sh(idx3)%temp = T0
        if (idx3==1) then
          st%sh(idx3)%r_in = 0._rk
        else
          st%sh(idx3)%r_in = st%sh(idx3-1)%r_out
        end if
        st%sh(idx3)%rbar = 0.5_rk*(st%sh(idx3)%r_in + st%sh(idx3)%r_out)
        st%sh(idx3)%mass = rho0 * shell_volume(st%sh(idx3)%r_in, st%sh(idx3)%r_out)
      end select
    end do
    close(iu)

    if (.not. allocated(st%eos)) then
      allocate(st%eos(st%Nshell))
      do i=1, st%Nshell
        st%eos(i)%a=0._rk; st%eos(i)%b=0._rk; st%eos(i)%c=1._rk
        st%eos(i)%Acv=1._rk; st%eos(i)%Bcv=0._rk
      end do
    end if
    if (.not. allocated(st%mat_of_shell)) then
      allocate(st%mat_of_shell(st%Nshell)); st%mat_of_shell=1
    end if

    call attach_tables(st%Nshell)
    do i=1, st%Nshell
      if (st%eos(i)%tabular) then
        integer :: rc
        call read_eos_csv(st%eos(i)%table_path, tbl(i), rc)
        if (rc/=0) stop "Failed to read EOS table"
      end if
    end do
  end subroutine load_deck
end module input_parser
