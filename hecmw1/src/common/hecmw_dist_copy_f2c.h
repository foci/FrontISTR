/*=====================================================================*
 *                                                                     *
 *   Software Name : HEC-MW Library for PC-cluster                     *
 *         Version : 2.8                                               *
 *                                                                     *
 *     Last Update : 2006/06/01                                        *
 *        Category : I/O and Utility                                   *
 *                                                                     *
 *            Written by Kazuaki Sakane (RIST)                         *
 *                                                                     *
 *     Contact address :  IIS,The University of Tokyo RSS21 project    *
 *                                                                     *
 *     "Structural Analysis System for General-purpose Coupling        *
 *      Simulations Using High End Computing Middleware (HEC-MW)"      *
 *                                                                     *
 *=====================================================================*/



#ifndef HECMW_DIST_COPY_F2C_INCLUDED
#define HECMW_DIST_COPY_F2C_INCLUDED


extern int HECMW_dist_copy_f2c_init(struct hecmwST_local_mesh *local_mesh);


extern int HECMW_dist_copy_f2c_finalize(void);

#endif
