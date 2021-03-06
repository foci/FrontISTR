!-------------------------------------------------------------------------------
! Copyright (c) 2016 The University of Tokyo
! This software is released under the MIT License, see LICENSE.txt
!-------------------------------------------------------------------------------
!> \brief  This module provides aux functions
module m_utilities
  use hecmw
  implicit none

  real(kind=kreal), parameter, private :: PI=3.14159265358979d0

  contains

  !> Record used memeory
  SUBROUTINE memget(var,dimn,syze)
    INTEGER :: var,dimn,syze,bite
    PARAMETER(bite=1)
    var = var + dimn*syze*bite
  END SUBROUTINE memget


  !> Insert an integer at end of a file name
  subroutine append_int2name( n, fname, n1 )
    integer, intent(in)             :: n
    integer, intent(in), optional  ::  n1
    character(len=*), intent(inout) :: fname
    integer            :: npos, nlen
    character(len=128) :: tmpname, tmp

    npos = scan( fname, '.')
    nlen = len_trim( fname )
    if( nlen>128 ) stop "String too long(>128) in append_int2name"
    if( n>100000 ) stop "Integer too big>100000 in append_int2name"
    tmpname = fname
    if( npos==0 ) then
      write( fname, '(a,i6)') fname(1:nlen),n
    else
      write( tmp, '(i6,a)') n,tmpname(npos:nlen)
      fname = tmpname(1:npos-1) // adjustl(tmp)
    endif
    if(present(n1).and.n1/=0)then
      write(tmp,'(i8)')n1
      fname = fname(1:len_trim(fname))//'.'//adjustl(tmp)
    endif
  end subroutine

  !> Insert an integer into a integer array
  subroutine insert_int2array( iin, carray )
    integer, intent(in) :: iin
    integer, pointer :: carray(:)

    integer :: i, oldsize
    integer, pointer :: dumarray(:) => null()
    if( .not. associated(carray) ) then
      allocate( carray(1) )
      carray(1) = iin
    else
      oldsize = size( carray )
      allocate( dumarray(oldsize) )
      do i=1,oldsize
        dumarray(i) = carray(i)
      enddo
      deallocate( carray )
      allocate( carray(oldsize+1) )
      do i=1,oldsize
        carray(i) = dumarray(i)
      enddo
      carray(oldsize+1) = iin
    endif
    if( associated(dumarray) ) deallocate( dumarray )
  end subroutine

  !> Given symmetric 3x3 matrix M, compute the eigenvalues
  SUBROUTINE tensor_eigen3( tensor, eigval, eigproj )
    REAL(kind=kreal), INTENT(IN)  :: tensor(6)          !< tensor
    REAL(kind=kreal), INTENT(OUT) :: eigval(3)     !< eigenvalues
    REAL(kind=kreal), INTENT(OUT) :: eigproj(3,3)  !< eigenprojectss

    INTEGER  :: i
    REAL(kind=kreal) :: I1,I2,I3,R,sita,Q, X(3,3), XX(3,3), II(3,3)

    II(:,:)=0.d0
    II(1,1)=1.d0;  II(2,2)=1.d0;  II(3,3)=1.d0
    X(1,1)=tensor(1); X(2,2)=tensor(2); X(3,3)=tensor(3)
    X(1,2)=tensor(4); X(2,1)=X(1,2)
    X(2,3)=tensor(5); X(3,2)=X(2,3)
    X(3,1)=tensor(6); X(1,3)=X(3,1)

    XX= MATMUL( X,X )
    I1= X(1,1)+X(2,2)+X(3,3)
    I2= 0.5d0*( I1*I1 - (XX(1,1)+XX(2,2)+XX(3,3)) )
    I3= X(1,1)*X(2,2)*X(3,3)+X(2,1)*X(3,2)*X(1,3)+X(3,1)*X(1,2)*X(2,3)    &
     -X(3,1)*X(2,2)*X(1,3)-X(2,1)*X(1,2)*X(3,3)-X(1,1)*X(3,2)*X(2,3)

    R=(-2.d0*I1*I1*I1+9.d0*I1*I2-27.d0*I3)/54.d0
    Q=(I1*I1-3.d0*I2)/9.d0
    sita = acos(R/dsqrt(Q*Q*Q))

    eigval(1) = -2.d0*Q*cos(sita/3.d0)+I1/3.d0
    eigval(2) = -2.d0*Q*cos((sita+2.d0*PI)/3.d0)+I1/3.d0
    eigval(3) = -2.d0*Q*cos((sita-2.d0*PI)/3.d0)+I1/3.d0

  END SUBROUTINE

  !> Compute eigenvalue and eigenvetor for symmetric 3*3 tensor using
  !> Jacobi iteration adapted from numerical recpies
  SUBROUTINE eigen3 (tensor, eigval, princ)
    real(kind=kreal) :: tensor(6)     !< tensor
    real(kind=kreal) :: eigval(3)     !< vector containing the eigvalches
    real(kind=kreal) :: princ(3, 3)   !< matrix containing the three principal column vectors

    INTEGER, PARAMETER :: msweep = 50
    INTEGER :: i,j, is, ip, iq, ir
    real(kind=kreal) :: fsum, od, theta, t, c, s, tau, g, h, hd, btens(3,3)

    btens(1,1)=tensor(1); btens(2,2)=tensor(2); btens(3,3)=tensor(3)
    btens(1,2)=tensor(4); btens(2,1)=btens(1,2)
    btens(2,3)=tensor(5); btens(3,2)=btens(2,3)
    btens(3,1)=tensor(6); btens(1,3)=btens(3,1)
!
!     Initialise princ to the identity
!
      DO i = 1, 3
        DO j = 1, 3
          princ (i, j) = 0.d0
        END DO
        princ (i, i) = 1.d0
        eigval (i) = btens (i, i)
      END DO
!
!     Starts sweeping.
!
      DO is = 1, msweep
        fsum = 0.d0
        DO ip = 1, 2
          DO iq = ip + 1, 3
            fsum = fsum + abs( btens(ip, iq) )
          END DO
        END DO
!
!     If the fsum of off-diagonal terms is zero returns
!
        IF ( fsum < 1.d-10 ) RETURN

!
!     Performs the sweep in three rotations. One per off diagonal term
!
        DO ip = 1, 2
          DO iq = ip + 1, 3
            od = 100.d0 * abs (btens (ip, iq) )
            IF ( (od+abs (eigval (ip) ) /= abs (eigval (ip) )) &
                 .and. (od+abs (eigval (iq) ) /= abs (eigval (iq) ))) then
                hd = eigval (iq) - eigval (ip)
!
!    Evaluates the rotation angle
!
              IF ( abs (hd) + od == abs (hd)  ) then
                t = btens (ip, iq) / hd
              ELSE
                theta = 0.5d0 * hd / btens (ip, iq)
                t = 1.d0 / (abs (theta) + sqrt (1.d0 + theta**2) )
                IF ( theta < 0.d0 ) t = - t
              END IF
!
!     Re-evaluates the diagonal terms
!
              c = 1.d0 / sqrt (1.d0 + t**2)
              s = t * c
              tau = s / (1.d0 + c)
              h = t * btens (ip, iq)
              eigval (ip) = eigval (ip) - h
              eigval (iq) = eigval (iq) + h
!
!     Re-evaluates the remaining off-diagonal terms
!
              ir = 6 - ip - iq
              g = btens (min (ir, ip), max (ir, ip) )
              h = btens (min (ir, iq), max (ir, iq) )
              btens (min (ir, ip), max (ir, ip) ) = g &
                                                  - s * (h + g * tau)
              btens (min (ir, iq), max (ir, iq) ) = h &
                                                  + s * (g - h * tau)
!
!     Rotates the eigenvectors
!
              DO ir = 1, 3
                g = princ (ir, ip)
                h = princ (ir, iq)
                princ (ir, ip) = g - s * (h + g * tau)
                princ (ir, iq) = h + s * (g - h * tau)
              END DO
            END IF
            btens (ip, iq) = 0.d0
          END DO
        END DO
      END DO ! over sweeps
!
!     If convergence is not achieved stops
!
      STOP       ' Jacobi iteration unable to converge'
  END SUBROUTINE eigen3

  !> Compute determinant for symmetric 3*3 matrix
  real(kind=kreal) function Determinant( mat )
    real(kind=kreal) :: mat(6)     !< tensor
    real(kind=kreal) :: xj(3,3)

    xj(1,1)=mat(1); xj(2,2)=mat(2); xj(3,3)=mat(3)
    xj(1,2)=mat(4); xj(2,1)=xj(1,2)
    xj(2,3)=mat(5); xj(3,2)=xj(2,3)
    xj(3,1)=mat(6); xj(1,3)=xj(3,1)

    Determinant=XJ(1,1)*XJ(2,2)*XJ(3,3)               &
           +XJ(2,1)*XJ(3,2)*XJ(1,3)                   &
           +XJ(3,1)*XJ(1,2)*XJ(2,3)                   &
           -XJ(3,1)*XJ(2,2)*XJ(1,3)                   &
           -XJ(2,1)*XJ(1,2)*XJ(3,3)                   &
           -XJ(1,1)*XJ(3,2)*XJ(2,3)
  end function Determinant

  subroutine fstr_chk_alloc( imsg, sub_name, ierr )
    use hecmw
    character(*) :: sub_name
    integer(kind=kint) :: imsg
    integer(kind=kint) :: ierr

    if( ierr /= 0 ) then
      write(imsg,*) 'Memory overflow at ', sub_name
      write(*,*) 'Memory overflow at ', sub_name
      call hecmw_abort( hecmw_comm_get_comm( ) )
    endif
  end subroutine fstr_chk_alloc

  !> calculate inverse of matrix a
  SUBROUTINE calInverse(NN, A)
    INTEGER, INTENT(IN)             :: NN
    REAL(kind=kreal), intent(inout) :: A(NN,NN)

    INTEGER          :: I, J,K,IW,LR,IP(NN)
    REAL(kind=kreal) :: W,WMAX,PIVOT,API,EPS,DET
    DATA EPS/1.0E-35/
    DET=1.d0
    DO I=1,NN
      IP(I)=I
    ENDDO
    DO K=1,NN
      WMAX=0.d0
      DO I=K,NN
        W=DABS(A(I,K))
        IF (W.GT.WMAX) THEN
          WMAX=W
          LR=I
        ENDIF
      ENDDO
      PIVOT=A(LR,K)
      API=ABS(PIVOT)
      IF(API.LE.EPS) THEN
        WRITE(*,'(''PIVOT ERROR AT'',I5)') K
        STOP
      END IF
      DET=DET*PIVOT
      IF (LR.NE.K) THEN
        DET=-DET
        IW=IP(K)
        IP(K)=IP(LR)
        IP(LR)=IW
        DO J=1,NN
          W=A(K,J)
          A(K,J)=A(LR,J)
          A(LR,J)=W
        ENDDO
      ENDIF
      DO I=1,NN
        A(K,I)=A(K,I)/PIVOT
      ENDDO
      DO I=1,NN
        IF (I.NE.K) THEN
          W=A(I,K)
          IF (W.NE.0.) THEN
            DO J=1,NN
              IF (J.NE.K) A(I,J)=A(I,J)-W*A(K,J)
            ENDDO
            A(I,K)=-W/PIVOT
          ENDIF
        ENDIF
      ENDDO
      A(K,K)=1.d0/PIVOT
    ENDDO

    DO I=1,NN
      K=IP(I)
      IF (K.NE.I) THEN
        IW=IP(K)
        IP(K)=IP(I)
        IP(I)=IW
        DO J=1,NN
          W=A(J,I)
          A(J,I)=A(J,K)
          A(J,K)=W
        ENDDO
      ENDIF
    ENDDO

  end subroutine calInverse

  subroutine cross_product(v1,v2,vn)
    real(kind=kreal),intent(in)  ::  v1(3),v2(3)
    real(kind=kreal),intent(out)  ::  vn(3)

    vn(1) = v1(2)*v2(3) - v1(3)*v2(2)
    vn(2) = v1(3)*v2(1) - v1(1)*v2(3)
    vn(3) = v1(1)*v2(2) - v1(2)*v2(1)
  end subroutine cross_product

  subroutine transformation(jacob, tm)
  real(kind=kreal),intent(in)  ::  jacob(3,3)   !< Jacobian
  real(kind=kreal),intent(out)  ::  tm(6,6)      !< transform matrix

  integer    ::  i,j,k,m,nDim,nTensorDim

    do i=1,3
      do j=1,3
        tm(i,j)= jacob(i,j)*jacob(i,j)
      enddo
      tm(i,4) = jacob(i,1)*jacob(i,2)
      tm(i,5) = jacob(i,2)*jacob(i,3)
      tm(i,6) = jacob(i,3)*jacob(i,1)
    enddo
    tm(4,1) = 2.d0*jacob(1,1)*jacob(2,1)
    tm(5,1) = 2.d0*jacob(2,1)*jacob(3,1)
    tm(6,1) = 2.d0*jacob(3,1)*jacob(1,1)
    tm(4,2) = 2.d0*jacob(1,2)*jacob(2,2)
    tm(5,2) = 2.d0*jacob(2,2)*jacob(3,2)
    tm(6,2) = 2.d0*jacob(3,2)*jacob(1,2)
    tm(4,3) = 2.d0*jacob(1,3)*jacob(2,3)
    tm(5,3) = 2.d0*jacob(2,3)*jacob(3,3)
    tm(6,3) = 2.d0*jacob(3,3)*jacob(1,3)
    tm(4,4) = jacob(1,1)*jacob(2,2) + jacob(1,2)*jacob(2,1)
    tm(5,4) = jacob(2,1)*jacob(3,2) + jacob(2,2)*jacob(3,1)
    tm(6,4) = jacob(3,1)*jacob(1,2) + jacob(3,2)*jacob(1,1)
    tm(4,5) = jacob(1,2)*jacob(2,3) + jacob(1,3)*jacob(2,2)
    tm(5,5) = jacob(2,2)*jacob(3,3) + jacob(2,3)*jacob(3,2)
    tm(6,5) = jacob(3,2)*jacob(1,3) + jacob(3,3)*jacob(1,2)
    tm(4,6) = jacob(1,3)*jacob(2,1) + jacob(1,1)*jacob(2,3)
    tm(5,6) = jacob(2,3)*jacob(3,1) + jacob(2,1)*jacob(3,3)
    tm(6,6) = jacob(3,3)*jacob(1,1) + jacob(3,1)*jacob(1,3)

  end subroutine transformation

  SUBROUTINE get_principal (tensor, eigval, princmatrix)

    implicit none
    integer i,j
    real(kind=kreal) :: tensor(1:6)
    real(kind=kreal) :: eigval(3)
    real(kind=kreal) :: princmatrix(3,3)
    real(kind=kreal) :: princnormal(3,3)
    real(kind=kreal) :: tempv(3)
    real(kind=kreal) :: temps

    call eigen3(tensor,eigval,princnormal)

    if (eigval(1)<eigval(2)) then
      temps=eigval(1)
      eigval(1)=eigval(2)
      eigval(2)=temps
      tempv(:)=princnormal(:,1)
      princnormal(:,1)=princnormal(:,2)
      princnormal(:,2)=tempv(:)
    end if
    if (eigval(1)<eigval(3)) then
      temps=eigval(1)
      eigval(1)=eigval(3)
      eigval(3)=temps
      tempv(:)=princnormal(:,1)
      princnormal(:,1)=princnormal(:,3)
      princnormal(:,3)=tempv(:)
    end if
    if (eigval(2)<eigval(3)) then
      temps=eigval(2)
      eigval(2)=eigval(3)
      eigval(3)=temps
      tempv(:)=princnormal(:,2)
      princnormal(:,2)=princnormal(:,3)
      princnormal(:,3)=tempv(:)
    end if

    do j=1,3
      do i=1,3
        princmatrix(i,j) = princnormal(i,j) * eigval(j)
      end do
    end do

  end subroutine get_principal

  SUBROUTINE eigen3d (tensor, eigval, princ)
    implicit none

    real(kind=kreal) :: tensor(6)     !< tensor
    real(kind=kreal) :: eigval(3)     !< vector containing the eigvalches
    real(kind=kreal) :: princ(3,3)   !< matrix containing the three principal column vectors

    real(kind=kreal) :: s11, s22, s33, s12, s23, s13, j1, j2, j3, s1 , s2 , s3
    real(kind=kreal) :: p,q,ks1,ks2,ks3,a,b,c,d,pivot, ml,nl,l
    complex(kind=kreal):: x1,x2,x3
    real(kind=kreal):: rtemp
    real(kind=kreal) :: mat(3,4)
    integer :: i
    s11 = tensor(1)
    s22 = tensor(2)
    s33 = tensor(3)
    s12 = tensor(4)
    s23 = tensor(5)
    s13 = tensor(6)

    !応力テンソルの１～３次不変量
    j1 = s11 + s22 + s33
    j2 = -s11*s22 - s22*s33 - s33*s11 + s12**2 + s23**2 + s13**2
    j3 = s11*s22*s33 + 2*s12*s23*s13 - s11*s23**2 - s22*s13**2 - s33*s12**2
    !Cardanoの方法
    ! x^3+ ax^2   + bx  +c =0
    ! s^3 - J1*s^2 -J2s -J3 =0
    !より
    call cardano(-j1, -j2, -j3, x1, x2, x3)
    eigval(1)= real(x1)
    eigval(2)= real(x2)
    eigval(3)= real(x3)
    if (eigval(1)<eigval(2)) then
      rtemp=eigval(1)
      eigval(1)=eigval(2)
      eigval(2)=rtemp
    end if
    if (eigval(1)<eigval(3)) then
      rtemp=eigval(1)
      eigval(1)=eigval(3)
      eigval(3)=rtemp
    end if
    if (eigval(2)<eigval(3)) then
      rtemp=eigval(2)
      eigval(2)=eigval(3)
      eigval(3)=rtemp
    end if

    do i=1,3
      if (eigval(i)/(eigval(1)+eigval(2)+eigval(3)) < 1.0d-10 )then
        eigval(i) = 0.0d0
        princ(i,:) = 0.0d0
        exit
      end if
      ml = ( s23*s13 - s12*(s33-eigval(i)) ) / ( -s23**2 + (s22-eigval(i))*(s33-eigval(i)) )
       nl = ( s12**2 - (s22-eigval(i))*(s11-eigval(i)) ) / ( s12*s23 - s13*(s22-eigval(i)) )
      if (abs(ml) >= huge(ml)) then
       ml=0.0d0
      end if
      if (abs(nl) >= huge(nl)) then
       nl=0.0d0
      end if
      princ(i,1) = eigval(i)/sqrt( 1 + ml**2 + nl**2)
      princ(i,2) = ml * princ(i,1)
      princ(i,3) = nl * princ(i,1)
    end do

    write(*,*)
  end subroutine eigen3d

  subroutine cardano(a,b,c,x1,x2,x3)
    real(kind=kreal):: a,b,c
    real(kind=kreal):: p,q,d
    complex(kind=kreal):: w
    complex(kind=kreal):: u,v,y
    complex(kind=kreal):: x1,x2,x3
    w = (-1.0d0 + sqrt(dcmplx(-3.0d0)))/2.0d0
    p = -a**2/9.0d0 + b/3.0d0
    q = 2.0d0/2.7d1*a**3 - a*b/3.0d0 + c
    d = q**2 + 4.0d0*p**3

    u = ((-dcmplx(q) + sqrt(dcmplx(d)))/2.0d0)**(1.0d0/3.0d0)

    if(u.ne.0.0d0) then
      v = -dcmplx(p)/u
      x1 = u + v -dcmplx(a)/3.0d0
      x2 = u*w + v*w**2 -dcmplx(a)/3.0d0
      x3 = u*w**2 + v*w -dcmplx(a)/3.0d0
    else
      y = (-dcmplx(q))**(1.0d0/3.0d0)
      x1 = y -dcmplx(a)/3.0d0
      x2 = y*w -dcmplx(a)/3.0d0
      x3 = y*w**2 -dcmplx(a)/3.0d0
    end if

  end subroutine cardano

end module
