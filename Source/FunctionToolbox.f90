! This module contains basic functions
MODULE FunctionToolbox

USE Constants
IMPLICIT NONE

CONTAINS
	!-------------------------------------------------------------------------------------------------------------------------------
	! Saturates inputValue. Makes sure it is not smaller than minValue and not larger than maxValue
	REAL FUNCTION saturate(inputValue, minValue, maxValue)
	!

		IMPLICIT NONE

		REAL(4), INTENT(IN)		:: inputValue
		REAL(4), INTENT(IN)		:: minValue
		REAL(4), INTENT(IN)		:: maxValue

		saturate = MIN(MAX(inputValue,minValue), maxValue)

	END FUNCTION saturate
	!-------------------------------------------------------------------------------------------------------------------------------
	! Saturates inputValue. Makes sure it is not smaller than minValue and not larger than maxValue
	REAL FUNCTION ratelimit(refSignal, measSignal, minRate, maxRate, DT)
	!
		IMPLICIT NONE

		REAL(4), INTENT(IN)		:: refSignal
		REAL(4), INTENT(IN)		:: measSignal
		REAL(4), INTENT(IN)		:: minRate
		REAL(4), INTENT(IN)		:: maxRate
		REAL(4), INTENT(IN)		:: DT
		
		! Local variables
		REAL(4)					:: rate

		rate = (refSignal - measSignal)/DT						! Signal rate (unsaturated)
		rate = saturate(rate, minRate, maxRate)					! Saturate the signal rate
		ratelimit = measSignal + rate*DT						! Saturate the overall command using the rate limit

	END FUNCTION ratelimit
	!-------------------------------------------------------------------------------------------------------------------------------
	! PI controller, with output saturation
	REAL FUNCTION PIController(error, kp, ki, minValue, maxValue, DT, I0, reset, inst)
	!
		IMPLICIT NONE

		! Inputs
		REAL(4), INTENT(IN)			:: error
		REAL(4), INTENT(IN)			:: kp
		REAL(4), INTENT(IN)			:: ki
		REAL(4), INTENT(IN)			:: minValue
		REAL(4), INTENT(IN)			:: maxValue
		REAL(4), INTENT(IN)			:: DT
		INTEGER(4), INTENT(INOUT)	:: inst
		REAL(4), INTENT(IN)			:: I0
		LOGICAL, INTENT(IN)			:: reset
		
		! Local
		INTEGER(4)						:: i											! Counter for making arrays
		REAL(4)							:: PTerm										! Proportional term
		REAL(4), DIMENSION(99), SAVE	:: ITerm = (/ (real(9999.9), i = 1,99) /)		! Integral term, current.
		REAL(4), DIMENSION(99), SAVE	:: ITermLast = (/ (real(9999.9), i = 1,99) /)	! Integral term, the last time this controller was called. Supports 99 separate instances.
		INTEGER(4), DIMENSION(99), SAVE	:: FirstCall = (/ (1, i=1,99) /)				! First call of this function?
		
		! Initialize persistent variables/arrays, and set inital condition for integrator term
		IF ((FirstCall(inst) == 1) .OR. reset) THEN
			ITerm(inst) = I0
			ITermLast(inst) = I0
			
			FirstCall(inst) = 0
			PIController = I0
		ELSE
			PTerm = kp*error
			ITerm(inst) = ITerm(inst) + DT*ki*error
			ITerm(inst) = saturate(ITerm(inst), minValue, maxValue)
			PIController = PTerm + ITerm(inst)
			PIController = saturate(PIController, minValue, maxValue)
		
			ITermLast(inst) = ITerm(inst)
		END IF
		inst = inst + 1
		
	END FUNCTION PIController
	!-------------------------------------------------------------------------------------------------------------------------------
	! interp1 1-D interpolation (table lookup), xData and yData should be monotonically increasing
	REAL FUNCTION interp1d(xData, yData, xq)
	!
		IMPLICIT NONE
			! Inputs
		REAL(4), DIMENSION(:), INTENT(IN)		:: xData		! Provided x data (vector), to be interpolated
		REAL(4), DIMENSION(:), INTENT(IN)		:: yData		! Provided y data (vector), to be interpolated
		REAL(4), INTENT(IN)						:: xq			! x-value for which the y value has to be interpolated
		INTEGER(4)								:: I			! Iteration index
		
		IF (xq <= MINVAL(xData)) THEN
			interp1d = yData(1)
		ELSEIF (xq >= MAXVAL(xData)) THEN
			interp1d = yData(SIZE(xData))
		ELSE
			DO I = 1, SIZE(xData)
				IF (xq <= xData(I)) THEN
					interp1d = yData(I-1) + (yData(I) - yData(I-1))/(xData(I) - xData(I-1))*(xq - xData(I-1))
					EXIT
				ELSE
					CONTINUE
				END IF
			END DO
		END IF
		
	END FUNCTION interp1d
	!-------------------------------------------------------------------------------------------------------------------------------
	! DF controller, with output saturation
	REAL FUNCTION DFController(error, Kd, Tf, DT, inst)
	!
		IMPLICIT NONE

			! Inputs
		REAL(4), INTENT(IN)		:: error
		REAL(4), INTENT(IN)		:: kd
		REAL(4), INTENT(IN)		:: tf
		REAL(4), INTENT(IN)		:: DT
		INTEGER(4), INTENT(IN)	:: inst
		
			! Local
		REAL(4)							:: B									! 
		INTEGER(4)						:: i									! Counter for making arrays
		REAL(4), DIMENSION(99), SAVE	:: errorLast = (/ (0, i=1,99) /)		! 
		REAL(4), DIMENSION(99), SAVE	:: DFControllerLast = (/ (0, i=1,99) /)	! 
		INTEGER(4), DIMENSION(99), SAVE	:: FirstCall = (/ (1, i=1,99) /)		! First call of this function?
		
			! Initialize persistent variables/arrays, and set inital condition for integrator term
		! IF (FirstCall(inst) == 1) THEN
			! FirstCall(inst) = 0
		! END IF
		
		B = 2.0/DT
		DFController = (Kd*B)/(B*Tf+1.0)*error - (Kd*B)/(B*Tf+1.0)*errorLast(inst) - (1.0-B*Tf)/(B*Tf+1.0)*DFControllerLast(inst)

		errorLast(inst) = error
		DFControllerLast(inst) = DFController
	END FUNCTION DFController
	!-------------------------------------------------------------------------------------------------------------------------------
	! PRBS identification signal generator function
	!REAL FUNCTION PRBSgen(mean, amplitude, cycleTime, seed, initValue, reset, inst)
	!!
	!	IMPLICIT NONE
    !
	!		! Inputs
	!	REAL(4), INTENT(IN)		:: mean
	!	REAL(4), INTENT(IN)		:: amplitude
	!	INTEGER(4), INTENT(IN)	:: cycleTime
	!	INTEGER(4), INTENT(IN)	:: seed
	!	LOGICAL, INTENT(IN)		:: reset
	!	REAL(4), INTENT(IN)		:: initValue
	!	
	!		! Local
	!	INTEGER(4)				:: i											! Counter for making arrays
	!	REAL(4)					:: randomNumber
	!	INTEGER(4), DIMENSION(99), SAVE	:: FirstCall = (/ (1, i=1,99) /)
	!	
	!	IF ((FirstCall(inst) == 1) .OR. reset) THEN
	!		RANDOM_NUMBER(1)
	!		RAND(seed)
	!		
	!		FirstCall(inst) = 0
	!		PRBSgen = initValue
	!	ELSE
	!		randomNumber = RAND()
	!		
	!		IF randomNumber > 0.5 THEN
	!			randomNumber = 1
	!		ELSE
	!			randomNumber = 0
	!		END IF
	!		
	!		randomNumber = randomNumber - 0.5
	!		randomNumber = randomNumber*amplitude*2 + mean
	!		PRBSgen = randomNumber
	!	END IF
	!	
	!END FUNCTION PRBSgen
	!-------------------------------------------------------------------------------------------------------------------------------
	! Stata machine, determines the state of the wind turbine to determine the corresponding control actions
	! States:
	! - 0, Error state, unknown state (for debugging purposes)
	! - 10, idling, wind and rotor speed too low for start-up: set pitch to vane position and torque to minimum
	! - 20, start-up mode, set pitch demand to start-up pitch angle for maximum aerodynamic torque and torque demand to minimum
	! - 25, start-up2normal
	! - 30, Region 1 operation
	! - 40, Region 1.5 operation, torque control to keep the rotor at cut-in speed towards the Cp-max operational curve
	! - 50, Region 2, operation, maximum rotor power efficiency (Cp-max) tracking, keep TSR constant at a fixed fine-pitch angle
	! - 60, Region 2.5, transition between below and above-rated operating conditions (near-rated region) using PI torque control
	! - 70, Region 2.75, above-rated operation using pitch control (constant torque mode)
	! - 80, Region 3, above-rated operation using pitch control (constant torque mode)
	! - 81, Region 3, above-rated operation using pitch control (constant power mode)
	INTEGER FUNCTION StateMachine(CntrPar, LocalVar)
		USE DRC_Types, ONLY : LocalVariables, ControlParameters
		IMPLICIT NONE
    
			! Inputs
		TYPE(ControlParameters), INTENT(IN)		:: CntrPar
		TYPE(LocalVariables), INTENT(IN)		:: LocalVar
		
			! Local
			! Pitch control state machine
		IF ((CntrPar%VS_ControlMode == 0) .AND. (LocalVar%GenTrqAr >= CntrPar%PC_RtTq99)) THEN
			StateMachine = 70
			IF (LocalVar%PC_PitComT >= CntrPar%VS_Rgn3MP) THEN
				StateMachine = 80
			END IF
		ELSEIF ((CntrPar%VS_ControlMode == 1) .AND. (LocalVar%GenTrqAr >= CntrPar%VS_GenTrqArSatMax*0.99)) THEN
			StateMachine = 70
			IF (LocalVar%PC_PitComT >= CntrPar%VS_Rgn3MP) THEN
				StateMachine = 81
			END IF
		ELSEIF (LocalVar%GenTrqAr >= CntrPar%VS_Rgn2MaxTq*1.01) THEN
			StateMachine = 60
		ELSEIF (LocalVar%GenTrqBr <= CntrPar%VS_Rgn2MinTq*0.99) THEN
			StateMachine = 40
		ELSEIF (LocalVar%GenSpeedF < CntrPar%VS_MaxOM) THEN
			StateMachine = 50
		ELSE
			StateMachine = 0
		END IF
	END FUNCTION StateMachine
	!-------------------------------------------------------------------------------------------------------------------------------
	SUBROUTINE Debug(LocalVar, CntrPar, avrSWAP, RootName, size_avcOUTNAME)
		USE, INTRINSIC	:: ISO_C_Binding
		USE DRC_Types, ONLY : LocalVariables, ControlParameters
		
		IMPLICIT NONE
	
		TYPE(ControlParameters), INTENT(IN)		:: CntrPar
		TYPE(LocalVariables), INTENT(IN)		:: LocalVar
	
		INTEGER(4), INTENT(IN)						:: size_avcOUTNAME
		INTEGER(4)									:: I				! Generic index.
		CHARACTER(1), PARAMETER						:: Tab = CHAR(9)						! The tab character.
		CHARACTER(25), PARAMETER					:: FmtDat = "(F8.3,99('"//Tab//"',ES10.3E2,:))	"	! The format of the debugging data
		INTEGER(4), PARAMETER						:: UnDb = 85		! I/O unit for the debugging information
		INTEGER(4), PARAMETER						:: UnDb2 = 86		! I/O unit for the debugging information, avrSWAP
		REAL(C_FLOAT), INTENT(INOUT)				:: avrSWAP(*)	! The swap array, used to pass data to, and receive data from, the DLL controller.
		CHARACTER(size_avcOUTNAME-1), INTENT(IN)	:: RootName		! a Fortran version of the input C string (not considered an array here)    [subtract 1 for the C null-character]
		
		!..............................................................................................................................
		! Initializing debug file
		!..............................................................................................................................
		IF (LocalVar%iStatus == 0)  THEN  ! .TRUE. if we're on the first call to the DLL
		! If we're debugging, open the debug file and write the header:
			IF (CntrPar%LoggingLevel > 0) THEN
				OPEN (UnDb, FILE=TRIM(RootName)//'.dbg', STATUS='REPLACE')
				WRITE (UnDb,'(A)')	'   LocalVar%Time '  //Tab//'LocalVar%PC_PitComT  ' //Tab//'LocalVar%PC_SpdErr  ' //Tab//'LocalVar%PC_KP ' //Tab//'LocalVar%PC_KI  ' //Tab//'LocalVar%Y_M  ' //Tab//'LocalVar%rootMOOP(1)  '//Tab//'VS_RtPwr  '//Tab//'LocalVar%GenTrq'
				WRITE (UnDb,'(A)')	'   (sec) ' //Tab//'(rad)    '  //Tab//'(rad/s) '//Tab//'(-) ' //Tab//'(-)   ' //Tab//'(rad)   ' //Tab//'(?)   ' //Tab//'(W)   '//Tab//'(Nm)  '
			END IF
			
			IF (CntrPar%LoggingLevel > 1) THEN
				OPEN(UnDb2, FILE=TRIM(RootName)//'.dbg2', STATUS='REPLACE')
				WRITE(UnDb2,'(/////)')
				WRITE(UnDb2,'(A,85("'//Tab//'AvrSWAP(",I2,")"))')  'LocalVar%Time ', (i,i=1,85)
				WRITE(UnDb2,'(A,85("'//Tab//'(-)"))')  '(s)'
			END IF
		ELSE
			! Print simulation status, every 10 seconds
			IF (MODULO(LocalVar%Time, 10.0) == 0) THEN
				WRITE(*, 100) LocalVar%GenSpeedF*RPS2RPM, LocalVar%BlPitch(1)*R2D, avrSWAP(15)/1000.0 ! LocalVar%Time !/1000.0
				100 FORMAT('Generator speed: ', f6.1, ' RPM, Pitch angle: ', f5.1, ' deg, Power: ', f7.1, ' kW')
				PRINT *, LocalVar%GlobalState, LocalVar%PC_MaxPitVar, LocalVar%PC_PitComT
			END IF
			
			! Output debugging information if requested:
			IF (CntrPar%LoggingLevel > 0) THEN
				WRITE (UnDb,FmtDat)		LocalVar%Time,	LocalVar%PC_PitComT,	LocalVar%PC_SpdErr,	LocalVar%PC_KP,	LocalVar%PC_KI,	LocalVar%Y_MErr,	LocalVar%rootMOOP(1), CntrPar%VS_RtPwr, LocalVar%GenTrq
			END IF
			
			IF (CntrPar%LoggingLevel > 1) THEN
				WRITE (UnDb2,FmtDat)	LocalVar%Time, avrSWAP(1:85)
			END IF
		END IF
		
		IF (MODULO(LocalVar%Time, 10.0) == 0.0) THEN
			!LocalVar%TestType = LocalVar%TestType + 10
			!PRINT *, LocalVar%TestType
		END IF
	END SUBROUTINE Debug
	!-------------------------------------------------------------------------------------------------------------------------------
	!The Coleman or d-q axis transformation transforms the root out of plane bending moments of each turbine blade
	!to a direct axis and a quadrature axis
	SUBROUTINE ColemanTransform(rootMOOP, aziAngle, axisTilt, axisYaw)
	!...............................................................................................................................

		IMPLICIT NONE

			! Inputs

		REAL(4), INTENT(IN)		:: rootMOOP(3)						! Root out of plane bending moments of each blade
		REAL(4), INTENT(IN)		:: aziAngle							! Rotor azimuth angle

			! Outputs

		REAL(4), INTENT(OUT)	:: axisTilt, axisYaw				! Direct axis and quadrature axis outputted by this transform

			! Local

		REAL(4), PARAMETER		:: phi2 = 2.0/3.0*PI				! Phase difference from first to second blade
		REAL(4), PARAMETER		:: phi3 = 4.0/3.0*PI				! Phase difference from first to third blade

			! Body

		axisTilt	= 2.0/3.0 * (cos(aziAngle)*rootMOOP(1) + cos(aziAngle+phi2)*rootMOOP(2) + cos(aziAngle+phi3)*rootMOOP(3))
		axisYaw		= 2.0/3.0 * (sin(aziAngle)*rootMOOP(1) + sin(aziAngle+phi2)*rootMOOP(2) + sin(aziAngle+phi3)*rootMOOP(3))

	END SUBROUTINE ColemanTransform
	!-------------------------------------------------------------------------------------------------------------------------------
	!The inverse Coleman or d-q axis transformation transforms the direct axis and quadrature axis
	!back to root out of plane bending moments of each turbine blade
	SUBROUTINE ColemanTransformInverse(axisTilt, axisYaw, aziAngle, phi, PitComIPC)
	!...............................................................................................................................

		IMPLICIT NONE

			! Inputs

		REAL(4), INTENT(IN)		:: axisTilt, axisYaw			! Direct axis and quadrature axis
		REAL(4), INTENT(IN)		:: aziAngle 						! Rotor azimuth angle
		REAL(4), INTENT(IN)		:: phi								! Phase shift added to the azimuth angle

			! Outputs

		REAL(4), INTENT(OUT)	:: PitComIPC (3)					! Root out of plane bending moments of each blade

			! Local

		REAL(4), PARAMETER		:: phi2 = 2.0/3.0*PI				! Phase difference from first to second blade
		REAL(4), PARAMETER		:: phi3 = 4.0/3.0*PI				! Phase difference from first to third blade

			! Body

		PitComIPC(1) = cos(aziAngle+phi)*axisTilt + sin(aziAngle+phi)*axisYaw
		PitComIPC(2) = cos(aziAngle+phi+phi2)*axisTilt + sin(aziAngle+phi+phi2)*axisYaw
		PitComIPC(3) = cos(aziAngle+phi+phi3)*axisTilt + sin(aziAngle+phi+phi3)*axisYaw

	END SUBROUTINE ColemanTransformInverse
	!-------------------------------------------------------------------------------------------------------------------------------
END MODULE FunctionToolbox