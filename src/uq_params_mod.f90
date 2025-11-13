module uq_params_mod
  use kinds
  use types
  implicit none
  
  type :: UQParameters
     real(rk) :: xs_uncertainty = 0.05_rk   ! 5% uncertainty in cross sections
     real(rk) :: eos_uncertainty = 0.02_rk  ! 2% uncertainty in EOS
     real(rk) :: beta_uncertainty = 0.10_rk ! 10% uncertainty in delayed neutron fractions
     integer :: n_samples = 100             ! Number of Monte Carlo samples
     logical :: enable_xs_uq = .false.
     logical :: enable_eos_uq = .false.
     logical :: enable_beta_uq = .false.
     character(len=256) :: uq_output_file = "" ! Output file for UQ results
  end type

  type(UQParameters) :: uq_params_global

contains

  subroutine parse_uq_parameters(line, uq_params)
    ! Parse UQ parameters from input deck
    character(len=*), intent(in) :: line
    type(UQParameters), intent(inout) :: uq_params
    
    integer :: kpos
    character(len=512) :: key, sval
    
    ! Parse key and value
    kpos = index(line, ' ')
    if (kpos > 0) then
      key = trim(adjustl(line(1:kpos-1)))
      sval = adjustl(line(kpos+1:))
    else
      key = trim(adjustl(line))
      sval = ""
    end if
    
    select case (trim(key))
    case ("xs_uncertainty"); read(sval,*) uq_params%xs_uncertainty
    case ("eos_uncertainty"); read(sval,*) uq_params%eos_uncertainty
    case ("beta_uncertainty"); read(sval,*) uq_params%beta_uncertainty
    case ("n_samples"); read(sval,*) uq_params%n_samples
    case ("enable_xs_uq");
      if (trim(adjustl(sval))=="1" .or. trim(adjustl(sval))=="true") then
        uq_params%enable_xs_uq = .true.
      else
        uq_params%enable_xs_uq = .false.
      end if
    case ("enable_eos_uq");
      if (trim(adjustl(sval))=="1" .or. trim(adjustl(sval))=="true") then
        uq_params%enable_eos_uq = .true.
      else
        uq_params%enable_eos_uq = .false.
      end if
    case ("enable_beta_uq");
      if (trim(adjustl(sval))=="1" .or. trim(adjustl(sval))=="true") then
        uq_params%enable_beta_uq = .true.
      else
        uq_params%enable_beta_uq = .false.
      end if
    case ("uq_output_file"); uq_params%uq_output_file = trim(sval)
    end select
  end subroutine

end module uq_params_mod

