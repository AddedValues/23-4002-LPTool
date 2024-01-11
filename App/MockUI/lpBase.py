import os
import sys
import uuid
import datetime as dt
import logging
import inspect             # Inspection of the python stack.
import locale
import enum

# Months are not used (yet).
MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAJ', 'JUN', 'JUL', 'AUG', 'SEP', 'OKT', 'NOV', 'DEC']

def whoami():
    s = inspect.stack()
    return [ s[1][3], s[2][3] ]  # function and caller names.

class JobResultKind(enum.Enum):
    OK = 0
    Info = 1
    Warning = 2
    Error  = 3
    Critical = 4
    Success = 10
    Failure = 11
 

class LpBase():
    """ Base class for all LP classes. """
    
    # Static class variables
    _logger: logging.Logger = None
    logName: str = None
    appRootPath: str = None

    @staticmethod
    def setAppRootPath(appPath):
        if not os.path.exists(appPath):
            raise ValueError(f'App root path {appPath} does not exist.')
        
        LpBase.appRootPath = appPath
        return appPath

    @staticmethod
    def getUid() -> str:
        return str(uuid.uuid4())

    @staticmethod
    def getLogName() -> str:
        return LpBase.logName
    
    @staticmethod
    def initLogger(logName: str) -> logging.Logger:
        
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

        logfile_handler = logging.FileHandler(filename=f'{logName}.log')
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
        
        _logger = logging.getLogger(logName)

        return _logger

    @staticmethod
    def getLogger() -> logging.Logger:
        if LpBase._logger is None:
            LpBase._logger = LpBase.initLogger(f"{__name__}")
        return LpBase._logger
    
    @staticmethod
    def shutdown(logger: logging.Logger, message: str):
        if message is not None:
            logger.info('Closing log file.')

        for handler in logger.handlers:
            handler.close()
            # logger.removeFilter(handler)        
        
        logging.shutdown()
