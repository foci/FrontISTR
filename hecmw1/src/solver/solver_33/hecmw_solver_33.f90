!======================================================================!
!                                                                      !
!   Software Name : HEC-MW Library for PC-cluster                      !
!         Version : 2.6                                                !
!                                                                      !
!     Last Update : 2014/01/25                                         !
!        Category : Linear Solver                                      !
!                                                                      !
!            Written by Kengo Nakajima (Univ. of Tokyo)                !
!                       Kazuya Goto (PExProCS LLC)                     !
!                                                                      !
!     Contact address :  IIS,The University of Tokyo RSS21 project     !
!                                                                      !
!     "Structural Analysis System for General-purpose Coupling         !
!      Simulations Using High End Computing Middleware (HEC-MW)"       !
!                                                                      !
!======================================================================!

module hecmw_solver_33
contains
  !
  !C***
  !C*** hecmw_solve_33
  !C***
  !
  subroutine hecmw_solve_33 (hecMESH, hecMAT)

    use hecmw_util
    use hecmw_solver_CG_33
    use hecmw_solver_BiCGSTAB_33
    use hecmw_solver_GMRES_33
    use hecmw_solver_GPBiCG_33
    use m_hecmw_solve_error
    use m_hecmw_comm_f
    use hecmw_matrix_ass
    use hecmw_matrix_contact
    use hecmw_solver_las_33
    use hecmw_precond_33
    use hecmw_local_matrix
    use hecmw_matrix_misc
    use hecmw_matrix_dump
    use hecmw_solver_misc

    implicit none

    type (hecmwST_matrix), target :: hecMAT
    type (hecmwST_local_mesh) :: hecMESH

    integer(kind=kint) :: ERROR

    integer(kind=kint) :: ITER, METHOD, PRECOND, NSET
    integer(kind=kint) :: iterPREmax, i

    real(kind=kreal) :: RESID, SIGMA_DIAG, THRESH, FILTER

    integer(kind=kint) :: ITERlog, TIMElog
    real(kind=kreal) :: TIME_setup, TIME_comm, TIME_soltot, TR
    real(kind=kreal) :: time_Ax, time_precond
    real(kind=kreal) :: S_TIME, E_TIME, TIME_mpc_pre, TIME_mpc_post
    real(kind=kreal),    dimension(1) :: RHS
    integer (kind=kint), dimension(1) :: IFLAG

    integer(kind=kint) :: NREST
    real(kind=kreal)   :: SIGMA,TIME_sol

    type (hecmwST_matrix), pointer :: hecTKT
    integer(kind=kint) :: totalmpc, MPC_METHOD
    real(kind=kreal), allocatable :: Btmp(:)
    real(kind=kreal)::t_max,t_min,t_avg,t_sd

    !C===
    !C +------------+
    !C | PARAMETERs |
    !C +------------+
    !C===
    ITER      = hecMAT%Iarray(1)
    METHOD    = hecMAT%Iarray(2)
    PRECOND   = hecMAT%Iarray(3)
    NSET      = hecMAT%Iarray(4)
    iterPREmax= hecMAT%Iarray(5)
    NREST     = hecMAT%Iarray(6)

    ITERlog= hecMAT%Iarray(21)
    TIMElog= hecMAT%Iarray(22)

    TIME_setup  = 0.d0
    TIME_comm   = 0.d0
    TIME_soltot = 0.d0

    RESID     = hecMAT%Rarray(1)
    SIGMA_DIAG= hecMAT%Rarray(2)
    SIGMA     = hecMAT%Rarray(3)

    THRESH= hecMAT%Rarray(4)
    FILTER= hecMAT%Rarray(5)

    if (iterPREmax.lt.0) iterPREmax= 0
    if (iterPREmax.gt.4) iterPREmax= 4

    if (SIGMA_DIAG.lt.1.d0) SIGMA_DIAG= 1.d0
    if (SIGMA_DIAG.gt.2.d0) SIGMA_DIAG= 2.d0

    if (SIGMA.lt.0.d0) SIGMA= 0.d0
    if (SIGMA.gt.1.d0) SIGMA= 1.d0

    !C===
    !C +-------------+
    !C | ERROR CHECK |
    !C +-------------+
    !C===
    ERROR= 0

    !C
    !C-- ZERO RHS norm
    RHS(1)= 0.d0
    do i= 1, hecMAT%N
      RHS(1)= RHS(1) + hecMAT%B(3*i-2)**2 + hecMAT%B(3*i-1)**2       &
           &                   + hecMAT%B(3*i  )**2
    enddo
    if (hecMESH%mpc%n_mpc > 0) then
      do i= 1, hecMESH%mpc%n_mpc
        RHS(1)= RHS(1) + hecMESH%mpc%mpc_const(i)**2
      enddo
    endif
    call hecmw_allreduce_R (hecMESH, RHS, 1, hecmw_sum)

    if (RHS(1).eq.0.d0) then
      ERROR= 2002
      call hecmw_solve_error (hecMESH, ERROR)
    endif

    !C
    !C-- ZERO DIAGONAL component
    IFLAG(1)= 0
    do i= 1, hecMAT%N
      if (dabs(hecMAT%D(9*i-8)).eq.0.d0) IFLAG(1)= 1
      if (dabs(hecMAT%D(9*i-4)).eq.0.d0) IFLAG(1)= 1
      if (dabs(hecMAT%D(9*i  )).eq.0.d0) IFLAG(1)= 1
    enddo

    call hecmw_allreduce_I (hecMESH, IFLAG, 1, hecmw_sum)
    if (IFLAG(1).ne.0 .and. (PRECOND.le.10 .and. iterPREmax.gt.0)) then
      ERROR= 2001
      call hecmw_solve_error (hecMESH, ERROR)
    endif

    !C
    !C-- INCONSISTENT SOLVER/PRECONDITIONING
    IFLAG(1)= 0
    if (METHOD.le.0 .or. METHOD.ge.5)    IFLAG(1)= 1
    if (PRECOND.le.0 .or. PRECOND.gt.21) IFLAG(1)= 1

    call hecmw_allreduce_I (hecMESH, IFLAG, 1, hecmw_sum)
    if (IFLAG(1).ne.0) then
      ERROR= 1001
      call hecmw_solve_error (hecMESH, ERROR)
    endif

    IFLAG(1)= 1
    if (PRECOND.eq. 1) IFLAG(1)= 0
    if (PRECOND.eq. 2) IFLAG(1)= 0
    if (PRECOND.eq. 3) IFLAG(1)= 0
    if (PRECOND.eq.10) IFLAG(1)= 0
    if (PRECOND.eq.11) IFLAG(1)= 0
    if (PRECOND.eq.12) IFLAG(1)= 0

    if (IFLAG(1).ne.0) then
      ERROR= 1001
      call hecmw_solve_error (hecMESH, ERROR)
    endif

    call hecmw_matvec_33_clear_timer()
    call hecmw_precond_33_clear_timer()

    !C===
    !C +-------------+
    !C | MPC Preproc |
    !C +-------------+
    !C===
    totalmpc = hecMESH%mpc%n_mpc
    call hecmw_allreduce_I1 (hecMESH, totalmpc, hecmw_sum)

    S_TIME= HECMW_WTIME()

    if (totalmpc > 0) then
      call hecmw_mpc_scale(hecMESH)

      MPC_METHOD = hecmw_mat_get_mpc_method(hecMAT)
      if (MPC_METHOD < 1 .or. 3 < MPC_METHOD) MPC_METHOD = 3

      if (MPC_METHOD == 1) then  ! penalty
        write(0,*) "DEBUG: MPC Method: Penalty"
        call hecmw_mat_ass_equation ( hecMESH, hecMAT )
        hecTKT => hecMAT
      else if (MPC_METHOD == 2) then  ! MPCCG
        write(0,*) "DEBUG: MPC Method: MPC-CG"
        call hecmw_matvec_33_set_mpcmatvec_flg (.true.)
        allocate(Btmp(hecMAT%NP * hecMAT%NDOF))
        do i=1,hecMAT%NP * hecMAT%NDOF
          Btmp(i) = hecMAT%B(i)
        enddo
        call hecmw_trans_b_33(hecMESH, hecMAT, Btmp, hecMAT%B, TIME_comm)
        hecTKT => hecMAT
      else if (MPC_METHOD == 3) then  ! elimination
        write(0,*) "DEBUG: MPC Method: Elimination"
        allocate(hecTKT)
        call hecmw_mat_init(hecTKT)
        !write(0,*) "DEBUG: MPC: eliminating slave DOF"
        call hecmw_trimatmul_TtKT_mpc(hecMESH, hecMAT, hecTKT)
        !write(0,*) "DEBUG: MPC: trimatmul done"
        call hecmw_trans_b_33(hecMESH, hecMAT, hecMAT%B, hecTKT%B, TIME_comm)
        !write(0,*) "DEBUG: MPC: make new RHS done"
      endif
    else
      hecTKT => hecMAT
    endif

    E_TIME= HECMW_WTIME()
    call hecmw_time_statistics(hecMESH, E_TIME - S_TIME, &
         t_max, t_min, t_avg, t_sd)
    if (hecMESH%my_rank.eq.0) then
      write(*,*) 'Time MPC pre'
      write(*,*) '  Max     :',t_max
      write(*,*) '  Min     :',t_min
      write(*,*) '  Avg     :',t_avg
      write(*,*) '  Std Dev :',t_sd
    endif
    TIME_mpc_pre = t_max

    call hecmw_mat_dump(hecTKT, hecMESH)

    !C===
    !C +------------------+
    !C | ITERATIVE solver |
    !C +------------------+
    !C===

    !C
    !C-- CG
    if (METHOD.eq.1) then
      if (hecMESH%my_rank.eq.0 .and. (ITERlog.eq.1 .or. TIMElog.eq.1)) then
        if (PRECOND.eq.1) &
             write (*,'(a,i3)') '### 3x3 B-IC-CG(0)',iterPREmax
        if (PRECOND.eq.2) &
             write (*,'(a,i3)') '### 3x3 B-SSOR-CG(0)',iterPREmax
        if (PRECOND.eq.3) &
             write (*,'(a,i3)') '### 3x3 B-scale-CG  ',iterPREmax
        if (PRECOND.eq.10) &
             write (*,'(a,i3)') '### 3x3 B-IC-CG(0)',iterPREmax
        if (PRECOND.eq.11) &
             write (*,'(a,i3)') '### 3x3 B-IC-CG(1)',iterPREmax
        if (PRECOND.eq.12) &
             write (*,'(a,i3)') '### 3x3 B-IC-CG(2)',iterPREmax
      endif
      call hecmw_solve_CG_33( hecMESH,  hecTKT, ITER, RESID, ERROR,   &
           &                          TIME_setup, TIME_sol, TIME_comm )
    endif

    !C
    !C-- BiCGSTAB
    if (METHOD.eq.2) then
      if (hecMESH%my_rank.eq.0 .and. (ITERlog.eq.1 .or. TIMElog.eq.1)) then
        if (PRECOND.eq.1) &
             write (*,'(a,i3)') '### 3x3 B-ILU-BiCGSTAB(0)',iterPREmax
        if (PRECOND.eq.2) &
             write (*,'(a,i3)') '### 3x3 B-SSOR-BiCGSTAB(0)',iterPREmax
        if (PRECOND.eq.3) &
             write (*,'(a,i3)') '### 3x3 B-scale-BiCGSTAB  ',iterPREmax
        if (PRECOND.eq.10) &
             write (*,'(a,i3)') '### 3x3 B-IlU-BiCGSTAB(0)',iterPREmax
        if (PRECOND.eq.11) &
             write (*,'(a,i3)') '### 3x3 B-IlU-BiCGSTAB(1)',iterPREmax
        if (PRECOND.eq.12) &
             write (*,'(a,i3)') '### 3x3 B-IlU-BiCGSTAB(2)',iterPREmax
      endif

      call hecmw_solve_BiCGSTAB_33( hecMESH,  hecTKT, ITER, RESID, ERROR, &
           &                                TIME_setup, TIME_sol, TIME_comm )
    endif

    !C
    !C-- GMRES
    if (METHOD.eq.3) then
      if (hecMESH%my_rank.eq.0 .and. (ITERlog.eq.1 .or. TIMElog.eq.1)) then
        if (PRECOND.eq.1) &
             write (*,'(a,i3)') '### 3x3 B-ILU-GMRES(0)',iterPREmax
        if (PRECOND.eq.2) &
             write (*,'(a,i3)') '### 3x3 B-SSOR-GMRES(0)',iterPREmax
        if (PRECOND.eq.3) &
             write (*,'(a,i3)') '### 3x3 B-scale-GMRES  ',iterPREmax
        if (PRECOND.eq.10) &
             write (*,'(a,i3)') '### 3x3 B-ILU-GMRES(0)',iterPREmax
        if (PRECOND.eq.11) &
             write (*,'(a,i3)') '### 3x3 B-ILU-GMRES(1)',iterPREmax
        if (PRECOND.eq.12) &
             write (*,'(a,i3)') '### 3x3 B-ILU-GMRES(2)',iterPREmax
      endif

      call hecmw_solve_GMRES_33( hecMESH,  hecTKT, ITER, RESID, ERROR, &
           &                             TIME_setup, TIME_sol, TIME_comm )
    endif

    !C
    !C-- GPBiCG
    if (METHOD.eq.4) then
      if (hecMESH%my_rank.eq.0 .and. (ITERlog.eq.1 .or. TIMElog.eq.1)) then
        if (PRECOND.eq.1) &
             write (*,'(a,i3)') '### 3x3 B-ILU-GPBiCG(0)',iterPREmax
        if (PRECOND.eq.2) &
             write (*,'(a,i3)') '### 3x3 B-SSOR-GPBiCG(0)',iterPREmax
        if (PRECOND.eq.3) &
             write (*,'(a,i3)') '### 3x3 B-scale-GPBiCG  ',iterPREmax
        if (PRECOND.eq.10) &
             write (*,'(a)') '### 3x3 B-ILU-GPBiCG(0)',iterPREmax
        if (PRECOND.eq.11) &
             write (*,'(a)') '### 3x3 B-ILU-GPBiCG(1)',iterPREmax
        if (PRECOND.eq.12) &
             write (*,'(a)') '### 3x3 B-ILU-GPBiCG(2)',iterPREmax
      endif

      call hecmw_solve_GPBiCG_33( hecMESH,  hecTKT, ITER, RESID, ERROR, &
           &                              TIME_setup, TIME_sol, TIME_comm )
    endif

    if (RESID.gt.hecTKT%Rarray(1)) then
      call hecmw_solve_error (hecMESH, 3001)
    endif

    call hecmw_mat_dump_solution(hecTKT)

    !C===
    !C +--------------+
    !C | MPC Postproc |
    !C +--------------+
    !C===
    call hecmw_barrier(hecMESH)
    S_TIME= HECMW_WTIME()

    if (totalmpc > 0) then
      if (MPC_METHOD == 1) then  ! penalty
        ! do nothing
      else if (MPC_METHOD == 2) then  ! MPCCG
        call hecmw_tback_x_33(hecMESH, hecTKT%X, TIME_comm)
        do i=1,hecMAT%NP * hecMAT%NDOF
          hecMAT%B(i) = Btmp(i)
        enddo
        deallocate(Btmp)
      else if (MPC_METHOD == 3) then  ! elimination
        !write(0,*) "DEBUG: MPC: solve done"
        call hecmw_tback_x_33(hecMESH, hecTKT%X, TIME_comm)
        hecMAT%X(:)=hecTKT%X(:)
        !write(0,*) "DEBUG: MPC: recover solution done"
        call hecmw_mat_finalize(hecTKT)
        deallocate(hecTKT)
      endif
    endif

    call hecmw_barrier(hecMESH)
    E_TIME= HECMW_WTIME()
    TIME_mpc_post = E_TIME - S_TIME

    time_Ax = hecmw_matvec_33_get_timer()
    time_precond = hecmw_precond_33_get_timer()

    if (hecMESH%my_rank.eq.0 .and. TIMElog.eq.1) then
      TR= (TIME_sol-TIME_comm)/(TIME_sol+1.d-24)*100.d0
      write (*,'(/a)')          '### summary of linear solver'
      write (*,'(i10,a, 1pe16.6)')      ITER, ' iterations  ', RESID
      write (*,'(a, 1pe16.6 )') '    set-up time      : ', TIME_setup
      write (*,'(a, 1pe16.6 )') '    solver time      : ', TIME_sol
      write (*,'(a, 1pe16.6 )') '    solver/comm time : ', TIME_comm
      write (*,'(a, 1pe16.6 )') '    solver/matvec    : ', time_Ax
      write (*,'(a, 1pe16.6 )') '    solver/precond   : ', time_precond
      write (*,'(a, 1pe16.6 )') '    solver/1 iter    : ', TIME_sol / ITER
      write (*,'(a, 1pe16.6 )') '    MPC pre          : ', TIME_mpc_pre
      write (*,'(a, 1pe16.6 )') '    MPC post         : ', TIME_mpc_post
      write (*,'(a, 1pe16.6/)') '    work ratio (%)   : ', TR
    endif

  end subroutine hecmw_solve_33
end module hecmw_solver_33
