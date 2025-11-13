module reactivity_feedback
  use kinds
  use types
  implicit none
contains

  subroutine calculate_reactivity_feedback(st, ctrl)
    ! Calculate reactivity feedback from temperature, density, and void effects
    type(State),   intent(inout) :: st
    type(Control), intent(in)    :: ctrl
    
    integer :: i
    real(rk) :: T_avg, T_ref, dT
    real(rk) :: rho_avg, rho_ref, drho
    real(rk) :: rho_total, rho_void_local
    
    ! Initialize reactivity components
    st%rho_doppler = 0.0_rk
    st%rho_expansion = 0.0_rk
    st%rho_void = 0.0_rk
    
    ! Calculate average temperature and density
    T_avg = 0.0_rk
    rho_avg = 0.0_rk
    do i=1, st%Nshell
      T_avg = T_avg + st%sh(i)%temp
      rho_avg = rho_avg + st%sh(i)%rho
    end do
    T_avg = T_avg / max(st%Nshell, 1)
    rho_avg = rho_avg / max(st%Nshell, 1)
    
    T_ref = st%feedback%T_ref
    rho_ref = st%feedback%rho_ref
    if (rho_ref <= 0.0_rk) rho_ref = rho_avg  ! Use current density as reference if not set
    
    dT = T_avg - T_ref
    drho = rho_avg - rho_ref
    
    ! Doppler feedback (temperature-dependent)
    if (st%feedback%enable_doppler) then
      st%rho_doppler = st%feedback%doppler_coef * dT
    end if
    
    ! Fuel expansion feedback (density-dependent)
    if (st%feedback%enable_expansion) then
      ! Expansion coefficient typically relates to density change
      ! rho_expansion = expansion_coef * (rho - rho_ref) / rho_ref
      if (abs(rho_ref) > 1.0e-30_rk) then
        st%rho_expansion = st%feedback%expansion_coef * drho / rho_ref * 100.0_rk  ! Convert to pcm
      end if
    end if
    
    ! Void feedback (density-dependent, negative for voiding)
    if (st%feedback%enable_void) then
      ! Void coefficient: reactivity change per % void
      ! Assuming void fraction is related to density decrease
      if (abs(rho_ref) > 1.0e-30_rk) then
        rho_void_local = -st%feedback%void_coef * (drho / rho_ref) * 100.0_rk  ! Negative for expansion
        st%rho_void = rho_void_local
      end if
    end if
    
    ! Total reactivity = inserted + feedback
    rho_total = ctrl%rho_insert + st%rho_doppler + st%rho_expansion + st%rho_void
    st%rho_inserted = ctrl%rho_insert
    st%reactivity = rho_total
    
    ! Convert reactivity to effective k: rho = (k - 1) / k
    ! For small rho: k ≈ 1 + rho (where rho is in pcm/10000)
    ! st%k_eff will be adjusted in the neutronics solver
  end subroutine

  subroutine apply_temperature_dependent_xs(st, i)
    ! Apply Doppler broadening to cross sections based on temperature
    ! Simple model: sig(T) = sig(T_ref) * sqrt(T_ref / T)
    type(State), intent(inout) :: st
    integer,     intent(in)    :: i
    
    integer :: imat
    real(rk) :: T, T_ref, doppler_factor
    real(rk) :: doppler_exp
    
    if (st%Nshell < i .or. i < 1) return
    
    imat = st%mat_of_shell(i)
    if (imat < 1 .or. imat > st%nmat) return
    
    ! Check if material has temperature-dependent cross sections
    if (.not. st%mat(imat)%temperature_dependent) return
    
    T = st%sh(i)%temp
    T_ref = st%mat(imat)%T_ref
    doppler_exp = st%mat(imat)%doppler_exponent
    
    if (T <= 0.0_rk .or. T_ref <= 0.0_rk) return
    
    ! Doppler broadening: sig(T) = sig(T_ref) * (T_ref / T)^exponent
    ! For typical Doppler broadening: exponent = 0.5 (sqrt)
    doppler_factor = (T_ref / T)**doppler_exp
    
    ! Apply to cross sections (stored in material, but we need to modify effective XS)
    ! Note: This is a simplified model. Full implementation would require
    ! storing original XS and applying temperature correction during transport
    ! For now, we'll apply a correction factor to the existing XS
    ! This should be done in the transport solver where XS are used
    
    ! TODO: Full implementation requires storing original XS and applying
    ! temperature correction in the transport solver
  end subroutine

  subroutine update_reactivity_from_k(st)
    ! Update reactivity from k_eff: rho = (k - 1) / k
    type(State), intent(inout) :: st
    
    real(rk) :: k_eff
    
    k_eff = st%k_eff
    if (abs(k_eff) > 1.0e-30_rk) then
      ! Reactivity in pcm: rho = (k - 1) / k * 1e5
      st%reactivity = (k_eff - 1.0_rk) / k_eff * 1.0e5_rk
    else
      st%reactivity = 0.0_rk
    end if
  end subroutine

end module reactivity_feedback

