import sys
import os
import uuid
import datetime as dt
import logging
import inspect             # Inspection of the python stack.
import locale
import enum
import numpy as np
import pandas as pd
# from dataclasses import dataclass
# from datetime import datetime, timedelta

MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAJ', 'JUN', 'JUL', 'AUG', 'SEP', 'OKT', 'NOV', 'DEC']

def whoami():
    s = inspect.stack()
    return [ s[1][3], s[2][3] ]  # function and caller names.

def init(logName: str, logfileName: str) -> logging.Logger:
    
    locale.setlocale(locale.LC_TIME, 'da_DK.UTF-8')

    # Setup logger(s): Levels are: DEBUG, INFO, WARNING, ERROR, CRITICAL. See https://realpython.com/python-logging/
    """
    Example of logging an exception:
    a =5; b = 0;
    try:
    c = a / b
    except Exception as e:
    logging.error("Exception occurred", exc_info=True)
    
    OR simply:
    logging.exception("Exception occurred")
    """

    logfile_handler = logging.FileHandler(filename=f'{logfileName}.log')
    stdout_handler  = logging.StreamHandler(stream=sys.stdout)
    stdout_handler.level = logging.INFO
    handlers = [logfile_handler, stdout_handler]

    logging.basicConfig(
        level=logging.DEBUG, 
        format='[%(asctime)s] {%(filename)s:%(lineno)d} %(levelname)s - %(message)s',
        datefmt='%y-%b-%d %H.%M.%S',
        handlers=handlers
    )

    if logName is None:
        logName = 'Default'
    logger = logging.getLogger(logName)

    return logger

def shutdown(logger: logging.Logger, message: str):
    if message is not None:
        logger.info('Closing log file.')

    for handler in logger.handlers:
        handler.close()
        # logger.removeFilter(handler)        
    logging.shutdown()

class JobResultKind(enum.Enum):
   OK = 0
   Info = 1
   Warning = 2
   Error  = 3
   Critical = 4
   Success = 10
   Failure = 11
   

class Lpbase():
    """ Base class for all LP classes. """
    
    # Static class variables
    __name__: str = None
    _logger: logging.Logger = None
    logName: str = None


    def __init__(self, name:str, description:str, version:str) -> None:
        self.__id: str = uuid.uuid4()
        self._name: str = name
        self.description: str = description
        self._version: str = version
        Lpbase.logName = name

        self._created: dt.datetime = dt.datetime.now()
        self._modified: dt.datetime = dt.datetime.now()
        self.status: str = "New"
        self.author: str = "Unknown"
        self._logger = init(Lpbase.logName, f"{self._name}")
        return
    
    def __str__(self) -> str:
        return f"{self._name} {self.description} {self._version}"
    
    @property
    def id(self) -> str:
        return self.__id
    
    @staticmethod
    def logger() -> logging.Logger:
        if Lpbase._logger is None:
            Lpbase._logger = init(f"{__name__}", f"{__name__}")
        return Lpbase._logger
    
