module neutronics_s4_alpha
  use kinds
  use types
  implicit none
contains
  subroutine set_S4_quadrature(st)
    type(State), intent(inout) :: st
    if (.not. allocated(st%mu)) allocate(st%mu(2))
    if (.not. allocated(st%w))  allocate(st%w(2))
    st%Nmu = 2
    st%mu(1)=0.8611363116_rk; st%w(1)=0.3478548451_rk
    st%mu(2)=0.3399810436_rk; st%w(2)=0.6521451549_rk
  end subroutine

  subroutine ensure_neutronics_arrays(st)
    type(State), intent(inout) :: st
    if (.not. allocated(st%phi))       allocate(st%phi(st%G, st%Nshell))
    if (.not. allocated(st%q_scatter)) allocate(st%q_scatter(st%G, st%Nshell))
    if (.not. allocated(st%q_fiss))    allocate(st%q_fiss(st%G, st%Nshell))
    if (.not. allocated(st%q_delay))   allocate(st%q_delay(st%G, st%Nshell))
    if (.not. allocated(st%power_frac))allocate(st%power_frac(st%Nshell))
    if (.not. allocated(st%C))         allocate(st%C(DGRP, st%G, st%Nshell))
    st%phi = 1._rk / real(st%G, rk)
    st%C = 0._rk
  end subroutine

  subroutine build_sources(st, k, alpha, prompt_factor)
    type(State), intent(inout) :: st
    real(rk),    intent(in)    :: k, alpha, prompt_factor
    integer :: i, g, gp, imat, j
    real(rk) :: sumf

    st%q_scatter = 0._rk
    st%q_fiss    = 0._rk
    st%q_delay   = 0._rk

    do i=1, st%Nshell
      imat = st%mat_of_shell(i)
      do g=1, st%G
        do gp=1, st%G
          st%q_scatter(g,i) = st%q_scatter(g,i) + st%mat(imat)%sig_s(gp,g) * st%phi(gp,i)
        end do
        sumf = 0._rk
        do gp=1, st%G
          sumf = sumf + st%mat(imat)%g(gp)%nu_sig_f * st%phi(gp,i)
        end do
        st%q_fiss(g,i) = prompt_factor * st%mat(imat)%g(g)%chi * sumf / max(k, 1.0e-30_rk)
        ! delayed source: χ_d ≈ χ * sum_j λ_j C_j,g
        do j=1, DGRP
          st%q_delay(g,i) = st%q_delay(g,i) + st%mat(imat)%g(g)%chi * st%mat(imat)%lambda(j) * st%C(j,g,i)
        end do
      end do
    end do
  end subroutine

  subroutine sweep_spherical_k(st, k, alpha, tol, itmax)
    ! k-eigen sweep with modified Σ_t' = Σ_t + alpha/v (alpha-eigen via root-find)
    type(State), intent(inout) :: st
    real(rk),    intent(inout) :: k
    real(rk),    intent(in)    :: alpha, tol
    integer,     intent(in)    :: itmax
    integer :: it, i, g, m, imat
    real(rk) :: mu, wmu, rin, rout, dx, sig_t, tau, Sg, psi_in, psi_out
    real(rk) :: prod_old, prod_new, w_i

    do it=1, itmax
      call build_sources(st, k, alpha, prompt_factor=1.0_rk)  ! prompt only for k
      prod_old = 1.0_rk
      prod_new = 0._rk
      st%phi = 0._rk

      do m=1, st%Nmu
        mu = st%mu(m); wmu = st%w(m)
        ! outward
        do g=1, st%G
          psi_in = 0._rk
          do i=1, st%Nshell
            imat = st%mat_of_shell(i)
            sig_t = st%mat(imat)%g(g)%sig_t + alpha/max(st%vbar,1.0e-30_rk)
            rin = st%sh(i)%r_in; rout = st%sh(i)%r_out
            dx = max(rout - rin, 1.0e-12_rk)
            Sg = 0.5_rk*( st%q_scatter(g,i) + st%q_fiss(g,i) )  ! no delayed in k
            tau = sig_t*dx / max(mu, 1.0e-12_rk)
            psi_out = ((1._rk - 0.5_rk*tau) * psi_in + dx*Sg) / (1._rk + 0.5_rk*tau + dx*0.5_rk/max(0.5_rk*(rin+rout),1.0e-6_rk))
            st%phi(g,i) = st%phi(g,i) + wmu*0.5_rk*(psi_in+psi_out)
            psi_in = psi_out
          end do
        end do
        ! inward
        do g=1, st%G
          psi_in = 0._rk
          do i=st%Nshell,1,-1
            imat = st%mat_of_shell(i)
            sig_t = st%mat(imat)%g(g)%sig_t + alpha/max(st%vbar,1.0e-30_rk)
            rin = st%sh(i)%r_in; rout = st%sh(i)%r_out
            dx = max(rout - rin, 1.0e-12_rk)
            Sg = 0.5_rk*( st%q_scatter(g,i) + st%q_fiss(g,i) )
            tau = sig_t*dx / max(mu, 1.0e-12_rk)
            psi_out = ((1._rk - 0.5_rk*tau) * psi_in + dx*Sg) / (1._rk + 0.5_rk*tau + dx*0.5_rk/max(0.5_rk*(rin+rout),1.0e-6_rk))
            st%phi(g,i) = st%phi(g,i) + wmu*0.5_rk*(psi_in+psi_out)
            psi_in = psi_out
          end do
        end do
      end do

      ! production ratio update
      do i=1, st%Nshell
        do g=1, st%G
          w_i = (st%sh(i)%r_out - st%sh(i)%r_in)
          prod_new = prod_new + st%mat(st%mat_of_shell(i))%g(g)%nu_sig_f * st%phi(g,i) * w_i
        end do
      end do
      if (abs(prod_new-1._rk) < tol) exit
      k = k * prod_new    ! rescale k
    end do
  end subroutine

  subroutine solve_alpha_by_root(st, alpha_out, k_out)
    type(State), intent(inout) :: st
    real(rk),    intent(out)   :: alpha_out, k_out
    real(rk) :: a0, a1, k0, k1, f0, f1, anew
    integer :: iter
    a0 = -1.0_rk; a1 = 1.0_rk   ! initial bracket (μs^-1)
    k0 = 1.0_rk; k1 = 1.0_rk
    call sweep_spherical_k(st, k0, a0, 1.0e-5_rk, 200)
    f0 = k0 - 1.0_rk
    call sweep_spherical_k(st, k1, a1, 1.0e-5_rk, 200)
    f1 = k1 - 1.0_rk
    do iter=1, 30
      if (abs(f1-f0) < 1.0e-12_rk) exit
      anew = a1 - f1*(a1-a0)/(f1-f0)   ! secant
      a0 = a1; f0 = f1
      a1 = anew; k1 = 1.0_rk
      call sweep_spherical_k(st, k1, a1, 1.0e-5_rk, 200)
      f1 = k1 - 1.0_rk
      if (abs(f1) < 1.0e-5_rk) exit
    end do
    alpha_out = a1
    k_out = k1
  end subroutine

  subroutine finalize_power_and_alpha(st, k, include_delayed)
    type(State), intent(inout) :: st
    real(rk),    intent(in)    :: k
    logical,     intent(in)    :: include_delayed
    integer :: i, g, imat
    real(rk) :: prod_tot, flux_tot, vol_i, norm
    st%k_eff = k
    if (.not. allocated(st%power_frac)) allocate(st%power_frac(st%Nshell))
    prod_tot = 0._rk; flux_tot = 0._rk; norm = 0._rk
    do i=1, st%Nshell
      vol_i = max(st%sh(i)%r_out - st%sh(i)%r_in, 1.0e-12_rk)
      st%power_frac(i) = 0._rk
      do g=1, st%G
        imat = st%mat_of_shell(i)
        st%power_frac(i) = st%power_frac(i) + st%mat(imat)%g(g)%nu_sig_f * st%phi(g,i) * vol_i
        prod_tot = prod_tot + st%mat(imat)%g(g)%nu_sig_f * st%phi(g,i) * vol_i
        flux_tot = flux_tot + st%phi(g,i) * vol_i
      end do
      norm = norm + st%power_frac(i)
    end do
    if (norm>0._rk) then
      st%power_frac = st%power_frac / norm
    else
      st%power_frac = 1._rk/real(st%Nshell,rk)
    end if
    st%total_power = 1._rk
    ! alpha is set externally in alpha mode; in k-mode we can compute via Λ if desired
  end subroutine

  subroutine update_precursors(st, ctrl, dt)
    type(State), intent(inout) :: st
    type(Control), intent(in)  :: ctrl
    real(rk), intent(in) :: dt
    integer :: i, g, j, imat
    real(rk) :: source_g
    do i=1, st%Nshell
      imat = st%mat_of_shell(i)
      do g=1, st%G
        source_g = 0._rk
        do j=1, DGRP
          st%C(j,g,i) = st%C(j,g,i) + dt * ( st%mat(imat)%beta(j) * sum_fission_rate(st,i) - st%mat(imat)%lambda(j)*st%C(j,g,i) )
        end do
      end do
    end do
  contains
    pure function sum_fission_rate(st, i) result(Fi)
      type(State), intent(in) :: st
      integer, intent(in) :: i
      real(rk) :: Fi
      integer :: gp, imat
      Fi = 0._rk
      imat = st%mat_of_shell(i)
      do gp=1, st%G
        Fi = Fi + st%mat(imat)%g(gp)%nu_sig_f * st%phi(gp,i)
      end do
    end function
  end subroutine

end module neutronics_s4_alpha
