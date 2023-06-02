
import uuid
# from typing import Protocol
import datetime as dt
import LpBase as lpbase

class JobSpec(lpbase.Lpbase):
    """
    JobSpec holds the specification for a Load Planner job.
    """
    
    version = "0.0.1"

    def __init__(self, name:str, description:str) -> None:
        super().__init__(name, description, JobSpec.version)
        pass

