# from typing import Protocol
from typing import Any
# import uuid
import datetime as dt
# import enum                           # https://www.tutorialspoint.com/enum-in-python 
# import AppBase.LpBase as lpbase

class JobSpec(): 
    """
    JobSpec holds the specification for a Load Planner job.
    """
    __version__ = "0.0.2"

    def __init__(self, name: str, description: str, scenId: str, masterParms: dict[str,Any]) -> None:
        self.name :str = name
        self.description: str = description        
        self.scenId: str = scenId
        self.masterParms: dict[str,Any] = masterParms
        self.checkValidity(self.masterParms)
        # self._uid: str = lpbase.LpBase.getUid()
        return 

    def __str__(self) -> str:
        res = f"name={self.name}, desc={self.description}, scenId={self.scenId}, ver={JobSpec.__version__}"
        return res

    def checkValidity(self, masterParms: dict[str,Any]) -> None:
        """ Check validity of masterParms. """
        if not isinstance(masterParms, dict):
            raise ValueError(f"masterParms must be a dict, not {type(masterParms)}")
        
        for key in masterParms:
            if key not in JobSpec._defaultMasterParms:
                raise ValueError(f"masterParms contains unknown key {key}")
        return
    
    # @staticmethod
    def getDefaultMasterParms() -> dict[str,Any]:
        return JobSpec._defaultMasterParms

    _defaultMasterParms = {
        'Scenarios.ScenarioID'            : 0,
        # 'Scenarios.DumpPeriodsToGdx'      : 0,
        # 'Scenarios.LenRollHorizon'        : 437,
        # 'Scenarios.StepRollHorizon'       : 365,
        'Scenarios.LenRollHorizonOverhang': 72,
        'Scenarios.CountRollHorizon'      : 1,
        'Scenarios.OnCapacityReservation' : 0,
        'Scenarios.HourBegin'             : 577,
        'Scenarios.DurationPeriod'        : 48,
        'Scenarios.TimestampStart'        : '2024011000',
        # 'Scenarios.HourBeginBidDay'       : 1,
        # 'Scenarios.HoursBidDay'           : 24,
        'Scenarios.TimeResolutionDefault' : 60,
        'Scenarios.TimeResolutionBid'     : 60,
        # 'Scenarios.OnTimeAggr'            : 0,
        # 'Scenarios.AggrKind'              : 0,
        'Scenarios.QfInfeasMax'           : 0,
        # 'Scenarios.OnVakStartFix'         : 0,
        # 'Scenarios.OnStartCostSlk'        : 0,
        'Scenarios.OnRampConstraints'     : 0,
        'Scenarios.ElspotYear'            : 2019,
        'Scenarios.QdemandYear'           : 2019,
        'OnNetGlobalScen.netHo'           : 1,
        'OnNetGlobalScen.netSt'           : 1,
        'OnNetGlobalScen.netMa'           : 1,
        'OnUGlobalScen.MaVak'             : 0,
        'OnUGlobalScen.HoNVak'            : 0,
        'OnUGlobalScen.MaNVak'            : 0,
        'OnUGlobalScen.StVak'             : 0,
        'OnUGlobalScen.HoGk'              : 0,
        'OnUGlobalScen.HoOk'              : 0,
        'OnUGlobalScen.StGk'              : 0,
        'OnUGlobalScen.StOk'              : 0,
        'OnUGlobalScen.StEk'              : 0,
        'OnUGlobalScen.MaAff1'            : 0,
        'OnUGlobalScen.MaAff2'            : 0,
        'OnUGlobalScen.MaBio'             : 0,
        'OnUGlobalScen.MaCool'            : 0,
        'OnUGlobalScen.MaCool2'           : 0,
        'OnUGlobalScen.MaEk'              : 0,
        'OnUGlobalScen.HoNhpAir'          : 0,
        'OnUGlobalScen.HoNhpSew'          : 0,
        'OnUGlobalScen.HoNEk'             : 0,
        'OnUGlobalScen.HoNhpArla'         : 0,
        'OnUGlobalScen.HoNhpBirn'         : 0,
        'OnUGlobalScen.StNhpAir'          : 0,
        'OnUGlobalScen.StNFlis'           : 0,
        'OnUGlobalScen.StNEk'             : 0,
        'OnUGlobalScen.MaNEk'             : 0,
        'OnUGlobalScen.MaNbk'             : 0,
        'OnUGlobalScen.MaNbKV'            : 0,
        'OnUGlobalScen.MaNhpAir'          : 0,
        'OnUGlobalScen.MaNhpPtX'          : 0
    }
