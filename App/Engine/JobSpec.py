
# from typing import Protocol
import uuid
import datetime as dt
import enum                           # https://www.tutorialspoint.com/enum-in-python 
import AppBase.LpBase as lpbase


class JobSpec(lpbase.Lpbase):
    """
    JobSpec holds the specification for a Load Planner job.
    """
    
    version = "0.0.1"

    def __init__(self, name:str, description:str) -> None:
        super().__init__(name, description, JobSpec.version)
        pass

