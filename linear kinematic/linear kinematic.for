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
	 
      EMOD=PROPS(1)
      ENU=MIN(PROPS(2), ENUMAX)
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
      CALL ROTSIG(STATEV( 1), DROT, EELAS, 2, NDI, NSHR)
      CALL ROTSIG(STATEV(NTENS+1), DROT, EPLAS, 2, NDI, NSHR)
	  CALL ROTSIG(STATEV(2*NTENS+1), DROT, ALPHA, 1, NDI, NSHR)
      DO K1=1, NTENS
		 OLDS(K1)=STRESS(K1)
		 OLDPL(K1)=EPLAS(K1)
		 EELAS(K1)=EELAS(K1)+DSTRAN(K1)
         DO K2=1, NTENS
            STRESS(K2)=STRESS(K2)+DDSDDE(K2, K1)*DSTRAN(K1)
         END DO
      END DO
      SMISES=(STRESS(1)-ALPHA(1)-STRESS(2)+ALPHA(2))**2+(STRESS(2)-ALPHA(2)-STRESS(3)+ALPHA(3))**2
     1                                                 +(STRESS(3)-ALPHA(3)-STRESS(1)+ALPHA(1))**2
      DO K1=NDI+1,NTENS
         SMISES=SMISES+SIX*(STRESS(K1)-ALPHA(K1))**2
      END DO
      SMISES=SQRT(SMISES/TWO)
	  SYIELD=PROPS(3)
	  HARD=PROPS(4)	  
      IF(SMISES.GT.(ONE+TOLER)*SYIELD) THEN
        SHYDRO=(STRESS(1)+STRESS(2)+STRESS(3))/THREE
        DO K1=1,NDI
           FLOW(K1)=(STRESS(K1)-ALPHA(K1)-SHYDRO)/SMISES
        END DO
        DO K1=NDI+1, NTENS
           FLOW(K1)=(STRESS(K1)-ALPHA(K1))/SMISES
        END DO
		DEQPL=(SMISES-SYIELD)/(EG3+HARD)
        DO K1=1,NDI
           ALPHA(K1)=ALPHA(K1)+HARD*FLOW(K1)*DEQPL
           EPLAS(K1)=EPLAS(K1)+THREE/TWO*FLOW(K1)*DEQPL
           EELAS(K1)=EELAS(K1)-THREE/TWO*FLOW(K1)*DEQPL
		   STRESS(K1)=ALPHA(K1)+FLOW(K1)*SYIELD+SHYDRO
        END DO
        DO K1=NDI+1,NTENS
           ALPHA(K1)=ALPHA(K1)+HARD*FLOW(K1)*DEQPL
           EPLAS(K1)=EPLAS(K1)+THREE*FLOW(K1)*DEQPL
		   EELAS(K1)=EELAS(K1)-THREE*FLOW(K1)*DEQPL
		   STRESS(K1)=ALPHA(K1)+FLOW(K1)*SYIELD
        END DO
        SPD=ZERO
		DO K1=1, NDI
           SPD=SPD+(STRESS(K1)+OLDS(K1))*(EPLAS(K1)-OLDPL(K1))/TWO
        END DO
        EFFG=EG*(SYIELD+HARD*DEQPL)/SMISES
        EFFG2=TWO*EFFG
        EFFG3=THREE*EFFG
        EFFLAM=(EBULK3-EFFG2)/THREE
        EFFHRD=EG3*HARD/(EG3+HARD)-EFFG3
        DO K1=1, NDI
           DO K2=1, NDI
              DDSDDE(K2, K1)=EFFLAM
           END DO
           DDSDDE(K1, K1)=EFFG2+EFFLAM
        END DO
        DO K1=NDI+1, NTENS
           DDSDDE(K1, K1)=EFFG
        END DO
C        DO K1=1, NTENS
C           DO K2=1, NTENS
C              DDSDDE(K2, K1)=DDSDDE(K2, K1)+EFFHRD*FLOW(K2)*FLOW(K1)
C           END DO
C        END DO
      ENDIF
      DO K1=1, NDI
        STATEV(K1)=EELAS(K1)
		STATEV(K1+NTENS)=EPLAS(K1)
		STATEV(K1+2*NTENS)=ALPHA(K1)
      END DO	  
	  RETURN
      END
      