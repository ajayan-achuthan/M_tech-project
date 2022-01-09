      SUBROUTINE UMAT(STRESS, STATEV, DDSDDE, SSE, SPD, SCD, RPL,
     1 DDSDDT, DRPLDE, DRPLDT, STRAN, DSTRAN, TIME, DTIME, TEMP, DTEMP,
     2 PREDEF, DPRED, CMNAME, NDI, NSHR, NTENS, NSTATV, PROPS, NPROPS,
     3 COORDS, DROT, PNEWDT, CELENT, DFGRD0, DFGRD1, NOEL, NPT, LAYER,
     4 KSPT, KSTEP, KINC)
C
      INCLUDE 'ABA_PARAM.INC'
C
      CHARACTER*8 CMNAME
C
      DIMENSION STRESS(NTENS), STATEV(NSTATV), DDSDDE(NTENS, NTENS),
     1 DDSDDT(NTENS), DRPLDE(NTENS), STRAN(NTENS), DSTRAN(NTENS),
     2 PREDEF(1), DPRED(1), PROPS(NPROPS), COORDS(3), DROT(3, 3),
     3 DFGRD0(3, 3), DFGRD1(3, 3)
	 
      DIMENSION EELAS(6),EPLAS(6),ALPHA(6),FLOW(6),OLDS(6),OLDPL(6)
      PARAMETER(ZERO=0.D0, ONE=1.D0, TWO=2.D0, THREE=3.D0, SIX=6.D0,
     1          ENUMAX=.4999D0, NEWTON=10, TOLER=1.0D-6)

      EMOD=PROPS(1) ! YOUNG'S MODULUS
      ENU=PROPS(2) ! POISSON'S RATIO
      SY=PROPS(3) ! YIELD STRESS
      XN=PROPS(4) ! STRAIN HARDENING EXPONENT
      
      EBULK3=EMOD/(ONE-TWO*ENU)
      EG2=EMOD/(ONE+ENU)
      EG=EG2/TWO
      EG3=THREE*EG
      ELAM=(EBULK3-EG2)/THREE
      DO K1=1, NDI
         DO K2=1, NDI
           DDSDDE(K2, K1)=ELAM
         END DO
         DDSDDE(K1, K1)=EG2+ELAM
      END DO
      DO K1=NDI+1, NTENS
         DDSDDE(K1, K1)=EG
      END DO
      CALL ROTSIG(STATEV(1),DROT,EELAS,2,NDI,NSHR)
      CALL ROTSIG(STATEV(NTENS+1),DROT,EPLAS,2,NDI,NSHR)
      EQPLAS=STATEV(1+2*NTENS)
      OLDS=STRESS
      OLDPL=EPLAS
      STRESS=STRESS+MATMUL(DDSDDE,DSTRAN)
      EELAS=EELAS+DSTRAN
      
      SMISES=(STRESS(1)-STRESS(2))**2+(STRESS(2)-STRESS(3))**2
     1 +(STRESS(3)-STRESS(1))**2
      DO I=NDI+1,NTENS
       SMISES=SMISES+SIX*STRESS(I)**2
      END DO
      SMISES=SQRT(SMISES/TWO)	 
      
!     GET YIELD STRESS FROM THE SPECIFIED HARDENING CURVE
      SF=SY*(1.D0+EMOD*EQPLAS/SY)**XN
      
!     DETERMINE IF ACTIVE YIELDING
      IF (SMISES.GT.(1.D0+TOLER)*SF) THEN

!     CALCULATE THE FLOW DIRECTION
       SHYDRO=(STRESS(1)+STRESS(2)+STRESS(3))/THREE
       DO K1=1,NDI
           FLOW(K1)=(STRESS(K1)-SHYDRO)/SMISES
       END DO
       DO K1=NDI+1, NTENS
           FLOW(K1)=STRESS(K1)/SMISES
       END DO
       
!     SOLVE FOR SMISES AND DEQPL USING NEWTON'S METHOD
       DEQPL=ZERO
       ET=EMOD*XN*(ONE+EMOD*EQPLAS/SY)**(XN-1)
       DO KEWTON=1,NEWTON
        RHS=SMISES-(THREE*EG)*DEQPL-SF
        DEQPL=DEQPL+RHS/((THREE*EG)+ET)
        SF=SY*(ONE+EMOD*(EQPLAS+DEQPL)/SY)**XN
        ET=EMOD*XN*(ONE+EMOD*(EQPLAS+DEQPL)/SY)**(XN-1)
        IF(ABS(RHS).LT.TOLER*SY) EXIT
       END DO
       IF (KEWTON.EQ.NEWTON) WRITE(7,*)'WARNING: PLASTICITY LOOP FAILED'


       DO K1=1,NDI
		   STRESS(K1)=FLOW(K1)*SF+SHYDRO
           EPLAS(K1)=EPLAS(K1)+THREE/TWO*FLOW(K1)*DEQPL
           EELAS(K1)=EELAS(K1)-THREE/TWO*FLOW(K1)*DEQPL
        END DO
        DO K1=NDI+1,NTENS
		   STRESS(K1)=FLOW(K1)*SF
           EPLAS(K1)=EPLAS(K1)+THREE*FLOW(K1)*DEQPL
		   EELAS(K1)=EELAS(K1)-THREE*FLOW(K1)*DEQPL
        END DO
       EQPLAS=EQPLAS+DEQPL

!    CALCULATE THE PLASTIC STRAIN ENERGY DENSITY
       DO I=1,NTENS
        SPD=SPD+(STRESS(I)+OLDS(I))*(EPLAS(I)-OLDPL(I))/TWO
       END DO
      
!     FORMULATE THE JACOBIAN (MATERIAL TANGENT)   
       EFFG=EG*SF/SMISES
       EFFG2=TWO*EFFG
       EFFG3=THREE*EFFG
       EFFLAM=(EBULK3-EFFG2)/THREE
       EFFHRD=3.D0*EG*ET/(3.D0*EG+ET)-3.D0*EFFG
       DO K1=1,NDI
        DO K2=1,NDI
         DDSDDE(K2,K1)=EFFLAM
        ENDDO
        DDSDDE(K1,K1)=2.D0*EFFG+EFFLAM
       END DO
       DO K1=NDI+1,NTENS
        DDSDDE(K1,K1)=EFFG
       END DO

       DO K1=1,NTENS
        DO K2=1,NTENS
         DDSDDE(K2,K1)=DDSDDE(K2,K1)+EFFHRD*FLOW(K2)*FLOW(K1)
        END DO
       END DO
      ENDIF
      
!    STORE STRAINS IN STATE VARIABLE ARRAY
      STATEV(1:NTENS)=EELAS
      STATEV((NTENS+1):2*NTENS)=EPLAS
      STATEV(1+2*NTENS)=EQPLAS

      RETURN
      END