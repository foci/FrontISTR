!======================================================================!
!                                                                      !
! Software Name : FrontISTR Ver. 4.5                                   !
!                                                                      !
!      Module Name : Dynamic Transit Analysis                          !
!                                                                      !
!            Written by Toshio Nagashima (Sophia University)           !
!                       Yasuji Fukahori (Univ. of Tokyo)               !
!                       Tomotaka Ogasawara (Univ. of Tokyo)            !
!                                                                      !
!                                                                      !
!      Contact address :  IIS,The University of Tokyo, CISS            !
!                                                                      !
!      "Structural Analysis for Large Scale Assembly"                  !
!                                                                      !
!======================================================================!

!C================================================================C
!> \brief This module contains functions to set displacement boundary condition in dynamic analysis
!C================================================================C

module m_dynamic_mat_ass_bc

contains



!C***
!>  MAT_ASS_SOLID_BC_FIX for FSTR solver
!C***

      subroutine DYNAMIC_MAT_ASS_BC(hecMESH, hecMAT, fstrSOLID ,fstrDYNAMIC)
      use m_fstr
      use m_table_dyn

      implicit none
      type (hecmwST_matrix)     :: hecMAT
      type (hecmwST_local_mesh) :: hecMESH
      type (fstr_solid        ) :: fstrSOLID
      type ( fstr_dynamic     ) :: fstrDYNAMIC

      INTEGER(kind=kint) ig0, ig, ityp, NDOF, iS0, iE0, ik, in, idofS, idofE, idof
!!!
      INTEGER(kind=kint) flag_u
      real(kind=kreal) RHS, f_t
!!!
      flag_u = 1
!!!

!C=============================C
!C-- implicit dynamic analysis
!C=============================C
      if( fstrDYNAMIC%idx_eqa .eq. 1 ) then
!C
        do ig0 = 1, fstrSOLID%BOUNDARY_ngrp_tot
          ig   = fstrSOLID%BOUNDARY_ngrp_ID(ig0)
          RHS  = fstrSOLID%BOUNDARY_ngrp_val(ig0)

!!!!!!  time history
          call table_dyn(hecMESH, fstrSOLID, fstrDYNAMIC, ig0, f_t, flag_u)
          RHS = RHS * f_t
!!!!!!
          ityp = fstrSOLID%BOUNDARY_ngrp_type(ig0)

          idofS = ityp/10
          idofE = ityp - idofS*10

          iS0 = hecMESH%node_group%grp_index(ig-1) + 1
          iE0 = hecMESH%node_group%grp_index(ig  )

          do ik = iS0, iE0
            in = hecMESH%node_group%grp_item(ik)

            do idof = idofS, idofE
         !     call hecmw_mat_ass_bc(hecMAT, in, idof, RHS)
            enddo
          enddo

        enddo
!C
!C-- end of implicit dynamic analysis
!C

!C=============================C
!C-- explicit dynamic analysis
!C=============================C
      else if( fstrDYNAMIC%idx_eqa .eq. 11 ) then
!C
        NDOF = hecMAT%NDOF
        do ig0 = 1, fstrSOLID%BOUNDARY_ngrp_tot
          ig   = fstrSOLID%BOUNDARY_ngrp_ID(ig0)
          RHS  = fstrSOLID%BOUNDARY_ngrp_val(ig0)

!!!!!!  time history
          call table_dyn(hecMESH, fstrSOLID, fstrDYNAMIC, ig0, f_t, flag_u)
          RHS = RHS * f_t
!!!!!!
          ityp = fstrSOLID%BOUNDARY_ngrp_type(ig0)

          iS0 = hecMESH%node_group%grp_index(ig-1) + 1
          iE0 = hecMESH%node_group%grp_index(ig  )
          idofS = ityp/10
          idofE = ityp - idofS*10

          do ik = iS0, iE0
            in = hecMESH%node_group%grp_item(ik)
!C
            DO idof = idofS, idofE
              hecMAT%B        (NDOF*in-(NDOF-idof)) = RHS
              fstrDYNAMIC%VEC1(NDOF*in-(NDOF-idof)) = 1.0d0
            END DO
          enddo
!*End ig0 (main) loop
        enddo
!C
!C-- end of explicit dynamic analysis
!C
      end if

      end subroutine DYNAMIC_MAT_ASS_BC 


!C***
!> This subroutine setup initial condition of displacement
!C***
      subroutine DYNAMIC_BC_INIT(hecMESH, hecMAT, fstrSOLID ,fstrDYNAMIC)
      use m_fstr
      use m_table_dyn

      implicit none
      type (hecmwST_matrix)     :: hecMAT
      type (hecmwST_local_mesh) :: hecMESH
      type (fstr_solid        ) :: fstrSOLID
      type ( fstr_dynamic     ) :: fstrDYNAMIC

      INTEGER(kind=kint) NDOF, ig0, ig, ityp, iS0, iE0, ik, in, idofS, idofE, idof
!!!
      INTEGER(kind=kint) flag_u
      real(kind=kreal) RHS, f_t
!!!
      flag_u = 1
!!!

      NDOF = hecMAT%NDOF
      do ig0 = 1, fstrSOLID%BOUNDARY_ngrp_tot
        ig   = fstrSOLID%BOUNDARY_ngrp_ID(ig0)
        RHS  = fstrSOLID%BOUNDARY_ngrp_val(ig0)

!!!!!!  time history
        call table_dyn(hecMESH, fstrSOLID, fstrDYNAMIC, ig0, f_t, flag_u)
        RHS = RHS * f_t
!!!!!!
        ityp = fstrSOLID%BOUNDARY_ngrp_type(ig0)

        iS0 = hecMESH%node_group%grp_index(ig-1) + 1
        iE0 = hecMESH%node_group%grp_index(ig  )
        idofS = ityp/10
        idofE = ityp - idofS*10

        do ik = iS0, iE0
          in = hecMESH%node_group%grp_item(ik)
!C
          DO idof = idofS, idofE
            fstrDYNAMIC%DISP(NDOF*in-(NDOF-idof),1) = RHS
          END DO
        enddo
!*End ig0 (main) loop
      enddo

      return
      end subroutine DYNAMIC_BC_INIT

end module m_dynamic_mat_ass_bc
