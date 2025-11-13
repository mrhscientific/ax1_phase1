module neutronics_s4_alpha
  use kinds
  use types
  use utils, only: clamp
  implicit none
  character(len=16) :: p2_upscatter_mode = "allow"
  real(rk) :: p2_upscatter_scale = 1.0_rk
contains
  subroutine neutronics_set_controls(ctrl)
    type(Control), intent(in) :: ctrl
    p2_upscatter_mode = trim(ctrl%upscatter)
    p2_upscatter_scale = ctrl%upscatter_scale
  end subroutine
  subroutine set_Sn_quadrature(st, n)
    type(State), intent(inout) :: st
    integer, intent(in) :: n
    integer :: m
    ! Use Gauss-Legendre abscissae for 2, 3, 4 points (S4/S6/S8 mapped to 2/3/4 per-octant in 1D slab-like)
    select case (n)
    case (4)
      if (.not. allocated(st%mu)) allocate(st%mu(2))
      if (.not. allocated(st%w))  allocate(st%w(2))
      st%Nmu = 2
      st%mu(1)=0.8611363116_rk; st%w(1)=0.3478548451_rk
      st%mu(2)=0.3399810436_rk; st%w(2)=0.6521451549_rk
    case (6)
      if (.not. allocated(st%mu)) allocate(st%mu(3))
      if (.not. allocated(st%w))  allocate(st%w(3))
      st%Nmu = 3
      st%mu = [0.9324695142_rk, 0.6612093865_rk, 0.2386191861_rk]
      st%w  = [0.1713244924_rk, 0.3607615730_rk, 0.4679139346_rk]
    case (8)
      if (.not. allocated(st%mu)) allocate(st%mu(4))
      if (.not. allocated(st%w))  allocate(st%w(4))
      st%Nmu = 4
      st%mu = [0.9602898565_rk, 0.7966664774_rk, 0.5255324099_rk, 0.1834346425_rk]
      st%w  = [0.1012285363_rk, 0.2223810345_rk, 0.3137066459_rk, 0.3626837834_rk]
    case default
      ! fallback to S4 (duplicate S4 case to avoid recursion)
      if (.not. allocated(st%mu)) allocate(st%mu(2))
      if (.not. allocated(st%w))  allocate(st%w(2))
      st%Nmu = 2
      st%mu(1)=0.8611363116_rk; st%w(1)=0.3478548451_rk
      st%mu(2)=0.3399810436_rk; st%w(2)=0.6521451549_rk
    end select
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

  subroutine build_sources(st, k, prompt_factor)
    type(State), intent(inout) :: st
    real(rk),    intent(in)    :: k, prompt_factor
    integer :: i, g, gp, imat, j
    real(rk) :: sumf, prompt_scale, beta_tot

    st%q_scatter = 0._rk
    st%q_fiss    = 0._rk
    st%q_delay   = 0._rk

    do i=1, st%Nshell
      imat = st%mat_of_shell(i)
      beta_tot = 0._rk
      do j=1, DGRP
        beta_tot = beta_tot + st%mat(imat)%beta(j)
      end do
      beta_tot = min(max(beta_tot, 0._rk), 0.9999_rk)
      ! Only the prompt fraction contributes to the prompt source; the delayed portion is
      ! emitted through the precursor populations tracked in st%C.
      prompt_scale = prompt_factor * (1._rk - beta_tot)

      do g=1, st%G
        do gp=1, st%G
          st%q_scatter(g,i) = st%q_scatter(g,i) + scattering_coeff(imat, gp, g, st) * st%phi(gp,i)
        end do
        sumf = 0._rk
        do gp=1, st%G
          sumf = sumf + st%mat(imat)%groups(gp)%nu_sig_f * st%phi(gp,i)
        end do
        st%q_fiss(g,i) = prompt_scale * st%mat(imat)%groups(g)%chi * sumf / max(k, 1.0e-30_rk)
        ! delayed source: χ_d ≈ χ * sum_j λ_j C_j,g
        do j=1, DGRP
          st%q_delay(g,i) = st%q_delay(g,i) + st%mat(imat)%groups(g)%chi * st%mat(imat)%lambda(j) * st%C(j,g,i)
        end do
      end do
    end do
  end subroutine

  pure function scattering_coeff(imat, gp, g, st) result(sig)
    integer, intent(in) :: imat, gp, g
    type(State), intent(in) :: st
    real(rk) :: sig
    sig = st%mat(imat)%sig_s(gp,g)
    if (trim(p2_upscatter_mode) == "neglect") then
      if (g < gp) sig = 0._rk
    else if (trim(p2_upscatter_mode) == "scale") then
      if (g < gp) sig = sig * p2_upscatter_scale
    end if
  end function

  

  subroutine sweep_spherical_k(st, k, alpha, tol, itmax, use_dsa)
    ! k-eigen sweep with modified Σ_t' = Σ_t + alpha/v (alpha-eigen via root-find)
    type(State), intent(inout) :: st
    real(rk),    intent(inout) :: k
    real(rk),    intent(in)    :: alpha, tol
    integer,     intent(in)    :: itmax
    logical,     intent(in), optional :: use_dsa
    integer :: it, i, g, m, imat
    real(rk) :: mu, wmu, rin, rout, dx, sig_t, tau, Sg, psi_in, psi_out
    real(rk) :: prod_old, prod_new, w_i
    logical :: do_dsa

    prod_old = 1.0_rk
    do_dsa = .false.; if (present(use_dsa)) do_dsa = use_dsa
    do it=1, itmax
      st%transport_iterations = st%transport_iterations + 1
      call build_sources(st, k, prompt_factor=1.0_rk)  ! prompt only for k
      prod_new = 0._rk
      st%phi = 0._rk

      do m=1, st%Nmu
        mu = st%mu(m); wmu = st%w(m)
        ! outward
        do g=1, st%G
          psi_in = 0._rk
          do i=1, st%Nshell
            imat = st%mat_of_shell(i)
            sig_t = st%mat(imat)%groups(g)%sig_t + alpha/max(st%vbar,1.0e-30_rk)
            sig_t = max(sig_t, 1.0e-8_rk)
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
            sig_t = st%mat(imat)%groups(g)%sig_t + alpha/max(st%vbar,1.0e-30_rk)
            sig_t = max(sig_t, 1.0e-8_rk)
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

      ! Optional diffusion synthetic acceleration (scalar flux correction)
      if (do_dsa) then
        st%dsa_iterations = st%dsa_iterations + 1
        call dsa_correction(st)
      end if

      ! production ratio update
      do i=1, st%Nshell
        do g=1, st%G
          w_i = (st%sh(i)%r_out - st%sh(i)%r_in)
          prod_new = prod_new + st%mat(st%mat_of_shell(i))%groups(g)%nu_sig_f * st%phi(g,i) * w_i
        end do
      end do
      if (abs(prod_new-1._rk) < tol) exit
      if (prod_old > 0._rk) then
        k = k * (prod_new / prod_old)
      else
        k = k * prod_new
      end if
      prod_old = prod_new
    end do
  end subroutine

  subroutine dsa_correction(st)
    type(State), intent(inout) :: st
    ! Minimal tridiagonal diffusion correction on scalar flux per group, per shell
    ! D ~ 1/(3*Σ_t), solve -∇·(D∇φ) + Σ_a φ = Q for a single pseudo-iteration; here we do one GS sweep
    integer :: g, i
    real(rk) :: sig_t, sig_a, Dl, Dr, Ai, Bi, Ci, Qi, denom, phi_new
    do g=1, st%G
      do i=1, st%Nshell
        sig_t = max(st%mat(st%mat_of_shell(i))%groups(g)%sig_t, 1.0e-8_rk)
        sig_a = max(sig_t - st%mat(st%mat_of_shell(i))%sig_s(g,g), 0._rk)
        Dl = 1.0_rk/(3._rk*sig_t)
        Dr = Dl
        Ai = Dl
        Ci = Dr
        Bi = sig_a + Ai + Ci
        Qi = st%q_scatter(g,i) + st%q_fiss(g,i) + st%q_delay(g,i)
        denom = max(Bi, 1.0e-12_rk)
        phi_new = (Qi + Ai*st%phi(g, max(1,i-1)) + Ci*st%phi(g, min(st%Nshell,i+1)))/denom
        st%phi(g,i) = 0.5_rk*st%phi(g,i) + 0.5_rk*phi_new
      end do
    end do
  end subroutine

  subroutine solve_alpha_by_root(st, alpha_out, k_out, use_dsa)
    type(State), intent(inout) :: st
    real(rk),    intent(out)   :: alpha_out, k_out
    logical,     intent(in), optional :: use_dsa
    real(rk) :: a0, a1, k0, k1, f0, f1, anew
    integer :: iter
    logical :: do_dsa
    a0 = -1.0_rk; a1 = 1.0_rk   ! initial bracket (μs^-1)
    k0 = 1.0_rk; k1 = 1.0_rk
    do_dsa = .false.; if (present(use_dsa)) do_dsa = use_dsa
    call sweep_spherical_k(st, k0, a0, 1.0e-5_rk, 200, use_dsa=do_dsa)
    f0 = k0 - 1.0_rk
    call sweep_spherical_k(st, k1, a1, 1.0e-5_rk, 200, use_dsa=do_dsa)
    f1 = k1 - 1.0_rk
    do iter=1, 30
      if (abs(f1-f0) < 1.0e-12_rk) exit
      anew = a1 - f1*(a1-a0)/(f1-f0)   ! secant
      a0 = a1; f0 = f1
      a1 = anew; k1 = 1.0_rk
      call sweep_spherical_k(st, k1, a1, 1.0e-5_rk, 200, use_dsa=do_dsa)
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
    real(rk) :: prompt_tot, delay_tot, vol_i, norm
    real(rk) :: shell_power, delayed_shell, total_fission
    st%k_eff = k
    if (.not. allocated(st%power_frac)) allocate(st%power_frac(st%Nshell))
    prompt_tot = 0._rk; delay_tot = 0._rk; norm = 0._rk
    do i=1, st%Nshell
      vol_i = max(st%sh(i)%r_out - st%sh(i)%r_in, 1.0e-12_rk)
      st%power_frac(i) = 0._rk
      total_fission = 0._rk
      delayed_shell = 0._rk
      imat = st%mat_of_shell(i)
      do g=1, st%G
        total_fission = total_fission + st%mat(imat)%groups(g)%nu_sig_f * st%phi(g,i) * vol_i
        delayed_shell = delayed_shell + st%q_delay(g,i) * vol_i
      end do
      delayed_shell = min(max(delayed_shell, 0._rk), total_fission)
      shell_power = max(total_fission - delayed_shell, 0._rk)
      prompt_tot = prompt_tot + shell_power
      if (include_delayed) then
        shell_power = shell_power + delayed_shell
        delay_tot = delay_tot + delayed_shell
      end if
      st%power_frac(i) = shell_power
      norm = norm + shell_power
    end do
    if (norm>0._rk) then
      st%power_frac = st%power_frac / norm
    else
      st%power_frac = 1._rk/real(st%Nshell,rk)
    end if
    if (include_delayed) then
      st%total_power = prompt_tot + delay_tot
    else
      st%total_power = prompt_tot
    end if
    ! alpha is set externally in alpha mode; in k-mode we can compute via Λ if desired
  end subroutine

  subroutine update_precursors(st, dt)
    type(State), intent(inout) :: st
    real(rk), intent(in) :: dt
    integer :: i, g, j, imat
    real(rk) :: f_rate
    do i=1, st%Nshell
      imat = st%mat_of_shell(i)
      f_rate = sum_fission_rate(st, i)
      do g=1, st%G
        do j=1, DGRP
          st%C(j,g,i) = st%C(j,g,i) + dt * ( st%mat(imat)%beta(j) * f_rate - st%mat(imat)%lambda(j)*st%C(j,g,i) )
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
        Fi = Fi + st%mat(imat)%groups(gp)%nu_sig_f * st%phi(gp,i)
      end do
    end function
  end subroutine

end module neutronics_s4_alpha
