import uuid
import datetime as dt

class Lpbase():
    """ Base class for all LP classes. """
    def __init__(self, name:str, description:str, version:str) -> None:
        self.id: str = uuid.uuid4()
        self.name: str = name
        self.description: str = description
        self.version: str = version

        self.created: dt.datetime = dt.datetime.now()
        self.modified: dt.datetime = dt.datetime.now()
        self.status: str = "New"
        self.author: str = "Unknown"
        return
    
    def __str__(self) -> str:
        return f"{self.name} {self.description} {self.version}"