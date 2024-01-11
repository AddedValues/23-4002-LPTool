
# from typing import Protocol
import uuid
import datetime as dt
import enum                           # https://www.tutorialspoint.com/enum-in-python 
import AppBase.LpBase as lpbase


class JobSpec():   #--- (lpbase.Lpbase):
    """
    JobSpec holds the specification for a Load Planner job.
    """
    version = "0.0.1"

    def __init__(self, name:str, description:str, parms) -> None:
        super().__init__(name, description, JobSpec.version)
        self.logger = self.getLogger()
        self.parms = parms
        # self.timeStart:    dt.datetime    # Start time of model planning horizon.
        # self.duration:     int            # Duration [hour] of model planning horizon.
        # self.hourBegin:    int            # Hour of day when historical data interval starts.
        # self.hourEnd:      int            # Hour of day when historical data interval ends.
        # self.resolBid:     int            # Resolution of bid day in minutes.
        # self.resolDefault: int            # Resolution of other days in minutes.
        # self.activePlants: list           # List of active plants.
        return 

    def __str__(self) -> str:
        return f"{self._name} {self.description} {self._version}"
    

