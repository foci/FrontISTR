!======================================================================!
!                                                                      !
! Software Name : FrontISTR Ver. 4.5                                   !
!                                                                      !
!      Module Name : I/O and Utility                                   !
!                                                                      !
!            Written by X. YUAN (AdavanceSoft)                         !
!                                                                      !
!      Contact address :  IIS,The University of Tokyo, CISS            !
!                                                                      !
!      "Structural Analysis for Large Scale Assembly"                  !
!                                                                      !
!======================================================================!
!======================================================================!
!
!>   This module manages read in of various material properties
!>
!!
!>  \author     X. YUAN (AdavanceSoft)
!>  \date       2009/10/31
!>  \version    0.00
!!
!======================================================================!
module fstr_ctrl_material
   use hecmw
   use mMaterial
   use m_table
   implicit none
   
   private :: read_user_matl

   include 'fstr_ctrl_util_f.inc'

contains

!----------------------------------------------------------------------
!> Read in !MATERIAL
integer function fstr_ctrl_get_MATERIAL( ctrl, matname )
        integer(kind=kint), intent(in) :: ctrl
        character(len=*), intent(out) :: matname

		matname=""
        fstr_ctrl_get_MATERIAL = fstr_ctrl_get_param_ex( ctrl, 'NAME ',  '# ',  0, 'S', matname )
end function fstr_ctrl_get_MATERIAL

!----------------------------------------------------------------------
!> Read in !USER_MATERIAL
integer function fstr_ctrl_get_USERMATERIAL( ctrl, mattype, nlgeom, nstatus, matval )
        integer(kind=kint), intent(in)    :: ctrl
        integer(kind=kint), intent(inout) :: mattype
        integer(kind=kint), intent(out)   :: nlgeom
        integer(kind=kint), intent(out)   :: nstatus
        real(kind=kreal),intent(out)      :: matval(:)
		
        integer(kind=kint) :: ipt
        character(len=HECMW_NAME_LEN) :: data_fmt
        character(len=256) :: s, fname

        fstr_ctrl_get_USERMATERIAL = -1
        mattype = USERMATERIAL 
        nlgeom = UPDATELAG   !default value
        nstatus = 1
        if( fstr_ctrl_get_param_ex( ctrl, 'NSTATUS ',  '# ',    0,   'I',   nstatus )/= 0) return
        if( fstr_ctrl_get_param_ex( ctrl, 'KIRCHHOFF ',  '# ',    0,   'E',   ipt )/= 0) return
        if( ipt/=0 ) nlgeom = TOTALLAG
		
        fstr_ctrl_get_USERMATERIAL = read_user_matl( ctrl, matval )
end function fstr_ctrl_get_USERMATERIAL

!----------------------------------------------------------------------
!> Read in !ELASTIC
integer function fstr_ctrl_get_ELASTICITY( ctrl, mattype, nlgeom, matval, dict )
        integer(kind=kint), intent(in)    :: ctrl
        integer(kind=kint), intent(inout) :: mattype
        integer(kind=kint), intent(out)   :: nlgeom
        real(kind=kreal),intent(out)      :: matval(:)
        type(DICT_STRUCT), pointer        :: dict

        integer(kind=kint) :: i,j, rcode, depends, ipt, n
        real(kind=kreal),pointer :: fval(:,:)
        character(len=HECMW_NAME_LEN) :: data_fmt
        type( tTable )        :: mattable
        character(len=256) :: s

        fstr_ctrl_get_ELASTICITY = -1
        depends = 0
        rcode = fstr_ctrl_get_param_ex( ctrl, 'DEPENDENCIES  ', '# ',           0,   'I',   depends )
        if( depends>1 ) depends=1   ! temperature depends only currently
        if( depends > 3 ) stop "We cannot read dependencies>3 right now"
        nlgeom = TOTALLAG   !default value
        if( fstr_ctrl_get_param_ex( ctrl, 'CAUCHY ',  '# ',    0,   'E',   ipt )/= 0) return
        if( ipt/=0 ) nlgeom = UPDATELAG

        ipt=1
        s = 'ISOTROPIC,USER '
        if( fstr_ctrl_get_param_ex( ctrl, 'TYPE ',  s, 0, 'P',   ipt    ) /= 0 ) return

        ! ISOTROPIC
        if( ipt==1 ) then
            n = fstr_ctrl_get_data_line_n( ctrl )
            allocate( fval(2+depends,n) )
            if( depends==0 ) then
              data_fmt = "RR "
              fstr_ctrl_get_ELASTICITY = &
                fstr_ctrl_get_data_array_ex( ctrl, data_fmt, fval(1,:), fval(2,:) )
            endif
            if( depends==1 ) then
              data_fmt = "RRR "
              fstr_ctrl_get_ELASTICITY = &
                fstr_ctrl_get_data_array_ex( ctrl, data_fmt, fval(1,:), fval(2,:), fval(3,:) )
            endif
            if( fstr_ctrl_get_ELASTICITY ==0 ) then
              matval(M_YOUNGS) = fval(1,1)
              matval(M_POISSON) = fval(2,1)
              call init_table( mattable, depends, 2+depends,n, fval )
              call dict_add_key( dict, MC_ISOELASTIC, mattable )
		!	  call print_table( mattable, 6 ); pause
            endif
            mattype = ELASTIC
        
        else if( ipt==2 ) THEN
            allocate( fval(10,10) )
            fval =0.d0
            fstr_ctrl_get_ELASTICITY = fstr_ctrl_get_data_ex( ctrl, 1, 'rrrrrrrrrr ',    &
               fval(1,:), fval(2,:), fval(3,:), fval(4,:), fval(5,:), fval(6,:),           &
               fval(7,:), fval(8,:), fval(9,:), fval(10,:) ) 
            if( fstr_ctrl_get_ELASTICITY ==0 ) then
              do i=1,10
              do j=1,10
                matval(100+(i-1)*10+j)=fval(i,j)
              enddo
              enddo
            endif
            mattype = USERELASTIC
			nlgeom = INFINITE
			
        else
            stop "ERROR: Material type not supported"
            
        endif

        if( associated(fval) ) deallocate(fval)
end function fstr_ctrl_get_ELASTICITY


!----------------------------------------------------------------------
!> Read in !HYPERELASTIC
integer function fstr_ctrl_get_HYPERELASTIC( ctrl, mattype, nlgeom, matval )
        integer(kind=kint), intent(in)    :: ctrl
        integer(kind=kint), intent(inout) :: mattype
        integer(kind=kint), intent(out)   :: nlgeom
        real(kind=kreal),intent(out)      :: matval(:)

        integer(kind=kint) :: i,j, rcode, depends, ipt
        real(kind=kreal),pointer :: fval(:,:)
        character(len=HECMW_NAME_LEN) :: data_fmt
        character(len=256) :: s

        fstr_ctrl_get_HYPERELASTIC = -1
        depends = 0
        rcode = fstr_ctrl_get_param_ex( ctrl, 'DEPENDENCIES  ', '# ',           0,   'I',   depends )
        if( depends > 3 ) stop "We cannot read dependencies>3 right now"
        nlgeom = TOTALLAG   !default value
        if( fstr_ctrl_get_param_ex( ctrl, 'CAUCHY ',  '# ',    0,   'E',   ipt )/= 0) return
        if( ipt/=0 ) nlgeom = UPDATELAG

        ipt=1
        s = 'NEOHOOKE,MOONEY-RIVLIN,ARRUDA-BOYCE,USER '
        if( fstr_ctrl_get_param_ex( ctrl, 'TYPE ',  s, 0, 'P',   ipt    ) /= 0 ) return

        ! NEOHOOKE
        if( ipt==1 ) then
            allocate( fval(2,depends+1) )
            if( depends==0 ) then
              data_fmt = "RR "
              fstr_ctrl_get_HYPERELASTIC =                           &
                fstr_ctrl_get_data_array_ex( ctrl, data_fmt, fval(1,:), fval(2,:) )
            endif
            if( fstr_ctrl_get_HYPERELASTIC ==0 ) then
	          if( fval(2,1)==0.d0 ) stop "We cannot deal with imcompresible material currently"
              matval(M_PLCONST1) = fval(1,1)
              matval(M_PLCONST2) = 0.d0
              matval(M_PLCONST3) = fval(2,1)
           !   matval(M_YOUNGS) = fval(1,1)
           !   matval(M_POISSON) = fval(2,1)
            endif
            mattype = NEOHOOKE

        ! MOONEY
        else if( ipt==2 ) then
            allocate( fval(3,depends+1) )
            if( depends==0 ) then
              data_fmt = "RRR "
              fstr_ctrl_get_HYPERELASTIC =                       &
                 fstr_ctrl_get_data_array_ex( ctrl, data_fmt, fval(1,:), fval(2,:), fval(3,:) )
            endif
            if( fstr_ctrl_get_HYPERELASTIC ==0 ) then
              matval(M_PLCONST1) = fval(1,1)
              matval(M_PLCONST2) = fval(2,1)
              matval(M_PLCONST3) = fval(3,1)
            endif
            mattype = MOONEYRIVLIN

        ! ARRUDA
        else if( ipt==3 ) then
            allocate( fval(3,depends+1) )
            if( depends==0 ) then
              data_fmt = "RRR "
              fstr_ctrl_get_HYPERELASTIC = &
                fstr_ctrl_get_data_array_ex( ctrl, data_fmt, fval(1,:), fval(2,:), fval(3,:) )
            endif
            if( fstr_ctrl_get_HYPERELASTIC ==0 ) then
              matval(M_PLCONST1) = fval(1,1)
              matval(M_PLCONST2) = fval(2,1)
              matval(M_PLCONST3) = fval(3,1)
            endif
            mattype = ARRUDABOYCE

        else if( ipt==4 ) THEN    !User
            allocate( fval(10,10) )
            fval =0.d0
            fstr_ctrl_get_HYPERELASTIC = fstr_ctrl_get_data_ex( ctrl, 1, 'rrrrrrrrrr ',    &
               fval(1,:), fval(2,:), fval(3,:), fval(4,:), fval(5,:), fval(6,:),           &
               fval(7,:), fval(8,:), fval(9,:), fval(10,:) ) 
            if( fstr_ctrl_get_HYPERELASTIC ==0 ) then
              do i=1,10
              do j=1,10
                matval(100+(i-1)*10+j)=fval(i,j)
              enddo
              enddo
            endif
			mattype = USERHYPERELASTIC
            
        endif

        if( associated(fval) ) deallocate(fval)
end function fstr_ctrl_get_HYPERELASTIC


!----------------------------------------------------------------------
!> Read in !VISCOELASTIC
integer function fstr_ctrl_get_VISCOELASTICITY( ctrl, mattype, nlgeom, dict )
        integer(kind=kint), intent(in)    :: ctrl
        integer(kind=kint), intent(inout) :: mattype
        integer(kind=kint), intent(out)   :: nlgeom
        type(DICT_STRUCT), pointer        :: dict

        integer(kind=kint) :: i,j, rcode, depends, ipt, n
        real(kind=kreal),pointer :: fval(:,:)
        character(len=HECMW_NAME_LEN) :: data_fmt
        type( tTable )        :: mattable
        character(len=256) :: s

        fstr_ctrl_get_VISCOELASTICITY = -1
        depends = 0
        rcode = fstr_ctrl_get_param_ex( ctrl, 'DEPENDENCIES  ', '# ',           0,   'I',   depends )
        if( depends>1 ) depends=1   ! temperature depends only currently
        depends = 0
        nlgeom = TOTALLAG   !default value
        if( fstr_ctrl_get_param_ex( ctrl, 'CAUCHY ',  '# ',    0,   'E',   ipt )/= 0) return
        if( ipt/=0 ) nlgeom = UPDATELAG

        ipt=1
        s = 'ISOTROPIC,USER '
        if( fstr_ctrl_get_param_ex( ctrl, 'TYPE ',  s, 0, 'P',   ipt    ) /= 0 ) return
        ipt = 1

        ! ISOTROPIC
        if( ipt==1 ) then
            n = fstr_ctrl_get_data_line_n( ctrl )
            allocate( fval(2+depends,n) )
            if( depends==0 ) then
              data_fmt = "RR "
              fstr_ctrl_get_VISCOELASTICITY = &
                fstr_ctrl_get_data_array_ex( ctrl, data_fmt, fval(1,:), fval(2,:) )
              if( fval(2,1)==0.d0 ) stop "Error in defining viscoelasticity: Relaxation time cannot be zero!"
            endif
            if( depends==1 ) then
              data_fmt = "RRR "
              fstr_ctrl_get_VISCOELASTICITY = &
                fstr_ctrl_get_data_array_ex( ctrl, data_fmt, fval(1,:), fval(2,:), fval(3,:) )
            endif
            if( fstr_ctrl_get_VISCOELASTICITY ==0 ) then
              call init_table( mattable, 1, 2+depends,n, fval )
              call dict_add_key( dict, MC_VISCOELASTIC, mattable )
		!	  call print_table( mattable, 6 ); pause
            endif
            mattype = VISCOELASTIC
        
			
        else
            stop "ERROR: Material type not supported"
            
        endif

        call finalize_table( mattable )
        if( associated(fval) ) deallocate(fval)
end function fstr_ctrl_get_VISCOELASTICITY


!----------------------------------------------------------------------
!> Read in !PLASTIC
integer function fstr_ctrl_get_PLASTICITY( ctrl, mattype, nlgeom, matval, mattable, dict )
        integer(kind=kint), intent(in)    :: ctrl
        integer(kind=kint), intent(inout) :: mattype
        integer(kind=kint), intent(out)   :: nlgeom
        real(kind=kreal),intent(out)      :: matval(:)
        real(kind=kreal), pointer         :: mattable(:)
        type(DICT_STRUCT), pointer        :: dict

        integer(kind=kint) :: i, n, rcode, depends, ipt, hipt
        real(kind=kreal),pointer :: fval(:,:)
        real(kind=kreal) :: dum, fdum
        character(len=HECMW_NAME_LEN) :: data_fmt
        character(len=256)    :: s
        type( tTable )        :: mttable
        real(kind=kreal), parameter :: PI=3.14159265358979d0

        fstr_ctrl_get_PLASTICITY = -1
        ipt = 0; hipt = 0

        depends = 0
        rcode = fstr_ctrl_get_param_ex( ctrl, 'DEPENDENCIES  ', '# ',           0,   'I',   depends )
        if( depends>1 ) depends = 1 ! we consider temprature dependence only currently
        if( depends > 3 ) stop "We cannot read dependencies>3 right now"
        nlgeom = UPDATELAG   !default value
        if( fstr_ctrl_get_param_ex( ctrl, 'KIRCHHOFF ',  '# ',    0,   'E',   ipt )/= 0) return
    !    rcode = fstr_ctrl_get_param_ex( ctrl, 'FILE  ', '# ',           0,   'S',   fname )
        if( ipt/=0 ) nlgeom = TOTALLAG
		
        call setDigit( 1, 1, mattype )
        call setDigit( 2, 2, mattype )
		
		! hardening 
        s = 'BILINEAR,MULTILINEAR,SWIFT,RAMBERG-OSGOOD,KINEMATIC,COMBINED '        
        if( fstr_ctrl_get_param_ex( ctrl, 'HARDEN ',  s , 0, 'P',   hipt    ) /= 0 ) return
        if( hipt==0 ) hipt=1  ! default: linear hardening
        call setDigit( 5, hipt-1, mattype )  
		
        ! yield function
        s = 'MISES,MOHR-COULOMB,DRUCKER-PRAGER,USER '
        call setDigit( 2, 2, mattype )
        if( fstr_ctrl_get_param_ex( ctrl, 'YIELD ',  s , 0, 'P',   ipt    ) /= 0 ) return
        if( ipt==0 ) ipt=1  ! default: mises yield function
        call setDigit( 4, ipt-1, mattype )    
		
        n = fstr_ctrl_get_data_line_n( ctrl )
        if( n == 0 ) return               ! fail in reading plastic
        if( hipt==2 .and. n<2 ) return    ! not enought data
        if( ( ipt==3 .or. ipt==4 ) .and. hipt>2 ) hipt = 1
		
        select case (ipt)
        case (1)  !Mises
            select case (hipt) 
            case (1,5)  ! linear hardening, kinematic hardening
              allocate( fval(2,n) )
              data_fmt = "RR "
              fstr_ctrl_get_PLASTICITY = &
                fstr_ctrl_get_data_array_ex( ctrl, data_fmt, fval(1,:), fval(2,:) )
              if( fstr_ctrl_get_PLASTICITY ==0 ) then
                matval(M_PLCONST1) = fval(1,1)
                if(hipt==1) then
                  matval(M_PLCONST2) = fval(2,1)
                else
                  matval(M_PLCONST2) = 0.d0
                  matval(M_PLCONST3) = fval(2,1)
                endif
              endif
            case (2)  ! multilinear approximation
              allocate( fval(depends+2,n) )
              if( depends==0 ) then
                data_fmt = "RR "
                fstr_ctrl_get_PLASTICITY = &
                  fstr_ctrl_get_data_array_ex( ctrl, data_fmt, fval(1,:), fval(2,:) )
                if( fstr_ctrl_get_PLASTICITY ==0 ) then 
                  if( fval(2,1)/=0.d0 ) then
                    print *, "Multilinear hardening: First plastic strain must be zero"
				    stop
                  endif
                  do i=1,n
                    if( fval(2,i)<0.0 ) &
                      stop "Multilinear hardening: Error in plastic strain definition" 
                  enddo
                  call init_table( mttable,1, 2+depends, n, fval )
                  call dict_add_key( dict, MC_YIELD, mttable )		  
			  
                endif
              else  ! depends==1
                data_fmt = "RRR "
                fstr_ctrl_get_PLASTICITY = &
                  fstr_ctrl_get_data_array_ex( ctrl, data_fmt, fval(1,:), fval(2,:), fval(3,:) )
                if( fstr_ctrl_get_PLASTICITY ==0 ) then
                  call init_table( mttable,2, 2+depends,n, fval )
                  call dict_add_key( dict, MC_YIELD, mttable )		  
                endif
              endif
            case (3, 4, 6)  ! swift, Ramberg-Osgood, Combined
              allocate( fval(3,1) )
              data_fmt = "RRR "
              fstr_ctrl_get_PLASTICITY = &
                fstr_ctrl_get_data_array_ex( ctrl, data_fmt, fval(1,:), fval(2,:), fval(3,:) )
              if( fstr_ctrl_get_PLASTICITY ==0 ) then
                matval(M_PLCONST1) = fval(1,1)
                matval(M_PLCONST2) = fval(2,1)
                matval(M_PLCONST3) = fval(3,1)
              endif
            case default
               print *, "Error in hardening definition!"
               stop
            end select
        case (2, 3)  ! Mohr-Coulomb, Drucker-Prager
            call setDigit( 5, 0, mattype )  
            allocate( fval(3,depends+1) )
            data_fmt = "RRr "
            fstr_ctrl_get_PLASTICITY = &
               fstr_ctrl_get_data_array_ex( ctrl, data_fmt, fval(1,:), fval(2,:), fval(3,:) )
            if( fstr_ctrl_get_PLASTICITY ==0 ) then
              matval(M_PLCONST1) = fval(1,1)    ! c
              matval(M_PLCONST2) = fval(3,1)    ! H
              if( ipt==3 ) then     ! Drucker-Prager
                dum = fval(2,1)*PI/180.d0
                fdum = 2.d0*sin(dum)/ ( sqrt(3.d0)*(3.d0+sin(dum)) )
                matval(M_PLCONST3) = fdum
                fdum = 6.d0* cos(dum)/ ( sqrt(3.d0)*(3.d0+sin(dum)) )
                matval(M_PLCONST4) = fdum
              else                  ! Mohr-Coulomb
                matval(M_PLCONST3) = fval(2,1)*PI/180.d0
              endif
            endif
			
        case(4)
            fstr_ctrl_get_PLASTICITY = read_user_matl( ctrl, matval )
			
        case default
            stop "Yield function not supported"
        end select

        if( associated(fval) ) deallocate(fval)
        call finalize_table( mttable )
end function fstr_ctrl_get_PLASTICITY

!----------------------------------------------------------------------
!> Read in !DENSITY
integer function fstr_ctrl_get_DENSITY( ctrl, matval )
        integer(kind=kint), intent(in) :: ctrl
        real(kind=kreal),intent(out)   :: matval(:)
!
        integer(kind=kint) :: i, rcode, depends
        real(kind=kreal),pointer :: fval(:,:)
        character(len=HECMW_NAME_LEN) :: data_fmt
!
        data_fmt = "R "
!
        fstr_ctrl_get_DENSITY = -1
!
        depends = 0
        rcode = fstr_ctrl_get_param_ex( ctrl, 'DEPENDENCIES  ', '# ',           0,   'I',   depends )
        if( depends>1 ) depends = 1 ! we consider temprature dependence only currently
!
        allocate( fval(1,depends+1) )
        do i=2,1+depends
               data_fmt = data_fmt //"R "
        enddo
        fstr_ctrl_get_DENSITY = &
              fstr_ctrl_get_data_array_ex( ctrl, data_fmt, fval(1,:) )
        if( fstr_ctrl_get_DENSITY==0 ) matval(M_DENSITY) = fval(1,1)
!
       if( associated(fval) ) deallocate(fval)
!
end function fstr_ctrl_get_DENSITY
!
!
!
!----------------------------------------------------------------------
!> Read in !EXPANSION_COEFF
integer function fstr_ctrl_get_EXPANSION_COEFF( ctrl, matval, dict )
        integer(kind=kint), intent(in) :: ctrl
        real(kind=kreal),intent(out)   :: matval(:)
        type(DICT_STRUCT), pointer     :: dict

        integer(kind=kint) :: i, n, rcode, depends
        real(kind=kreal),pointer :: fval(:,:)
        type( tTable )           :: mttable
        character(len=HECMW_NAME_LEN) :: data_fmt

        data_fmt = "R "

        fstr_ctrl_get_EXPANSION_COEFF = -1
		n = fstr_ctrl_get_data_line_n( ctrl )
        if( n == 0 ) return               ! fail in reading plastic

        depends = 0
        rcode = fstr_ctrl_get_param_ex( ctrl, 'DEPENDENCIES  ', '# ',           0,   'I',   depends )
        if( depends>1 ) depends = 1 ! we consider temprature dependence only currently

        allocate( fval(depends+1, n) )
        do i=2,1+depends
               data_fmt = data_fmt //"R "
        enddo
        if( depends==0 ) then
          fstr_ctrl_get_EXPANSION_COEFF = &
            fstr_ctrl_get_data_array_ex( ctrl, "R ", fval(1,:) )
        else
          fstr_ctrl_get_EXPANSION_COEFF = &
            fstr_ctrl_get_data_array_ex( ctrl, "RR ", fval(1,:), fval(2,:) )
        endif
        if( fstr_ctrl_get_EXPANSION_COEFF==0 ) then
          matval(M_EXAPNSION) = fval(1,1)
          call init_table( mttable,depends, 1+depends, n, fval )
          call dict_add_key( dict, MC_THEMOEXP, mttable )		
        endif

        if( associated(fval) ) deallocate(fval)
end function fstr_ctrl_get_EXPANSION_COEFF


integer function read_user_matl( ctrl, matval )
        integer(kind=kint), intent(in)    :: ctrl
        real(kind=kreal),intent(out)      :: matval(:)
		
        integer(kind=kint) :: i, j
        real(kind=kreal)   :: fval(10,10)

        read_user_matl = -1
		
        fval =0.d0
        if( fstr_ctrl_get_data_array_ex( ctrl, 1, 'rrrrrrrrrr ', fval(1,:), fval(2,:), fval(3,:),  &
           fval(4,:), fval(5,:), fval(6,:), fval(7,:), fval(8,:), fval(9,:), fval(10,:) ) /= 0 ) return
        do i=1,10
        do j=1,10
          matval(100+(i-1)*10+j)=fval(i,j)
        enddo
        enddo
			
        read_user_matl = 0
end function read_user_matl
			
!* ----------------------------------------------------------------------------------------------- *!
end module fstr_ctrl_material




