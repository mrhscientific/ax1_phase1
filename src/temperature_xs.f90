module temperature_xs
  use kinds
  use types
  implicit none
contains

  subroutine store_reference_xs(st)
    ! Store reference cross sections at T_ref for temperature-dependent materials
    type(State), intent(inout) :: st
    
    integer :: imat, g, gp
    
    do imat=1, st%nmat
      if (st%mat(imat)%temperature_dependent .and. .not. st%mat(imat)%reference_stored) then
        ! Store reference cross sections
        do g=1, st%mat(imat)%num_groups
          st%mat(imat)%groups_ref(g)%sig_t = st%mat(imat)%groups(g)%sig_t
          st%mat(imat)%groups_ref(g)%nu_sig_f = st%mat(imat)%groups(g)%nu_sig_f
          st%mat(imat)%groups_ref(g)%chi = st%mat(imat)%groups(g)%chi
        end do
        do gp=1, st%G
          do g=1, st%G
            st%mat(imat)%sig_s_ref(gp, g) = st%mat(imat)%sig_s(gp, g)
          end do
        end do
        st%mat(imat)%reference_stored = .true.
      end if
    end do
  end subroutine

  subroutine update_xs_for_temperature(st, shell_idx)
    ! Update cross sections for a specific shell based on its temperature
    type(State), intent(inout) :: st
    integer, intent(in) :: shell_idx
    
    integer :: imat, g, gp
    real(rk) :: T, T_ref, doppler_factor
    real(rk) :: doppler_exp
    
    if (shell_idx < 1 .or. shell_idx > st%Nshell) return
    
    imat = st%mat_of_shell(shell_idx)
    if (imat < 1 .or. imat > st%nmat) return
    
    ! Check if material has temperature-dependent cross sections
    if (.not. st%mat(imat)%temperature_dependent) return
    if (.not. st%mat(imat)%reference_stored) return
    
    T = st%sh(shell_idx)%temp
    T_ref = st%mat(imat)%T_ref
    doppler_exp = st%mat(imat)%doppler_exponent
    
    if (T <= 0.0_rk .or. T_ref <= 0.0_rk) return
    
    ! Doppler broadening: sig(T) = sig(T_ref) * (T_ref / T)^exponent
    ! For typical Doppler broadening: exponent = 0.5 (sqrt)
    ! This applies to absorption cross sections (sig_t, nu_sig_f)
    doppler_factor = (T_ref / T)**doppler_exp
    
    ! Update cross sections for this shell's material
    ! Note: We update the material XS, but since materials are shared,
    ! we need to apply temperature corrections per-shell in the transport solver
    ! For now, we'll apply the correction in the transport solver functions
    
    ! Store temperature correction factor in shell (alternative approach)
    ! Actually, we'll calculate it on-the-fly in the transport solver
  end subroutine

  function get_temperature_corrected_sig_t(st, shell_idx, group) result(sig_t)
    ! Get temperature-corrected total cross section
    type(State), intent(in) :: st
    integer, intent(in) :: shell_idx, group
    real(rk) :: sig_t
    
    integer :: imat
    real(rk) :: T, T_ref, doppler_factor
    real(rk) :: doppler_exp
    
    if (shell_idx < 1 .or. shell_idx > st%Nshell) then
      sig_t = 0.0_rk
      return
    end if
    
    imat = st%mat_of_shell(shell_idx)
    if (imat < 1 .or. imat > st%nmat .or. group < 1 .or. group > st%G) then
      sig_t = 0.0_rk
      return
    end if
    
    ! Get base cross section
    sig_t = st%mat(imat)%groups(group)%sig_t
    
    ! Apply temperature correction if material is temperature-dependent
    if (st%mat(imat)%temperature_dependent .and. st%mat(imat)%reference_stored) then
      T = st%sh(shell_idx)%temp
      T_ref = st%mat(imat)%T_ref
      doppler_exp = st%mat(imat)%doppler_exponent
      
      if (T > 0.0_rk .and. T_ref > 0.0_rk) then
        ! Use reference cross section if available
        if (group <= st%mat(imat)%num_groups) then
          sig_t = st%mat(imat)%groups_ref(group)%sig_t
        end if
        
        ! Apply Doppler broadening
        doppler_factor = (T_ref / T)**doppler_exp
        sig_t = sig_t * doppler_factor
      end if
    end if
  end function

  function get_temperature_corrected_nu_sig_f(st, shell_idx, group) result(nu_sig_f)
    ! Get temperature-corrected nu_sig_f
    type(State), intent(in) :: st
    integer, intent(in) :: shell_idx, group
    real(rk) :: nu_sig_f
    
    integer :: imat
    real(rk) :: T, T_ref, doppler_factor
    real(rk) :: doppler_exp
    
    if (shell_idx < 1 .or. shell_idx > st%Nshell) then
      nu_sig_f = 0.0_rk
      return
    end if
    
    imat = st%mat_of_shell(shell_idx)
    if (imat < 1 .or. imat > st%nmat .or. group < 1 .or. group > st%G) then
      nu_sig_f = 0.0_rk
      return
    end if
    
    ! Get base cross section
    nu_sig_f = st%mat(imat)%groups(group)%nu_sig_f
    
    ! Apply temperature correction if material is temperature-dependent
    if (st%mat(imat)%temperature_dependent .and. st%mat(imat)%reference_stored) then
      T = st%sh(shell_idx)%temp
      T_ref = st%mat(imat)%T_ref
      doppler_exp = st%mat(imat)%doppler_exponent
      
      if (T > 0.0_rk .and. T_ref > 0.0_rk) then
        ! Use reference cross section if available
        if (group <= st%mat(imat)%num_groups) then
          nu_sig_f = st%mat(imat)%groups_ref(group)%nu_sig_f
        end if
        
        ! Apply Doppler broadening
        doppler_factor = (T_ref / T)**doppler_exp
        nu_sig_f = nu_sig_f * doppler_factor
      end if
    end if
  end function

  function get_temperature_corrected_sig_s(st, shell_idx, gp, g) result(sig_s)
    ! Get temperature-corrected scattering cross section
    type(State), intent(in) :: st
    integer, intent(in) :: shell_idx, gp, g
    real(rk) :: sig_s
    
    integer :: imat
    real(rk) :: T, T_ref, doppler_factor
    real(rk) :: doppler_exp
    
    if (shell_idx < 1 .or. shell_idx > st%Nshell) then
      sig_s = 0.0_rk
      return
    end if
    
    imat = st%mat_of_shell(shell_idx)
    if (imat < 1 .or. imat > st%nmat .or. gp < 1 .or. gp > st%G .or. g < 1 .or. g > st%G) then
      sig_s = 0.0_rk
      return
    end if
    
    ! Get base cross section
    sig_s = st%mat(imat)%sig_s(gp, g)
    
    ! Apply temperature correction if material is temperature-dependent
    if (st%mat(imat)%temperature_dependent .and. st%mat(imat)%reference_stored) then
      T = st%sh(shell_idx)%temp
      T_ref = st%mat(imat)%T_ref
      doppler_exp = st%mat(imat)%doppler_exponent
      
      if (T > 0.0_rk .and. T_ref > 0.0_rk) then
        ! Use reference cross section if available
        sig_s = st%mat(imat)%sig_s_ref(gp, g)
        
        ! Apply Doppler broadening (scattering also depends on temperature)
        doppler_factor = (T_ref / T)**doppler_exp
        sig_s = sig_s * doppler_factor
      end if
    end if
  end function

end module temperature_xs

