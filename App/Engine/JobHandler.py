
import numpy as np
import pandas as pd
import AppBase.LpBase as lpbase  
from gams import GamsWorkspace

class JobHandler(lpbase.LpBase):
    """
    JobHandler performs the runs of the LP optimization model.
    """

    version = "0.0.1"
    ws = None

    def __init__(self, name:str, description:str, wkdir: str, modelText: str) -> None:
        super().__init__(name, description, JobHandler.version)
        self.wkdir = wkdir
        self.modelText = modelText

        if JobHandler.ws == None:
            JobHandler.ws = GamsWorkspace(wkdir)

        self.Symbols = dict()  # Key is symbol name, value is scalar, dictionary or DataFrame
        self.gw = None

        return
    
    def solve(self):
        self.db = JobHandler.ws.add_database()
        f = self.db.add_parameter("OnCapacityReservation", 0, "Angiver 0/1 om kapacitetsreservationer skal respekteres")
        f.add_record().value = 0;
        job = JobHandler.ws.add_job_from_string(self.modelText)
        opt = JobHandler.ws.add_options()
        # opt.defines["gdxincname"] = self.db.name
        job.run(opt,databases=self.db)

        self.jobOutDb = job.out_db
        self.symbolList = self.jobOutDb.get_symbol_list()
        
        return  #---  job.out_db.get_variable("z").first_record().level

    def __str__(self) -> str:   
        return f"{super().__str__()} {self.wkdir}"
    
    def getSymbol(self, symbol:str, attrName:str)  -> any:
        """ Extracts given symbol as a scalar, a dictionary or a DataFrame. """

        if self.gw is None:
            self.gw = lpbase.GdxWrapper.GdxWrapper(self.jobOutDb)

        if symbol in self.Symbols:
            return self.Symbols[symbol]
        if not symbol in self.symbolList:
            raise ValueError(f"Symbol {symbol} not found in job output database: {str(self)}.")
        
        sym = self.jobOutDb.get_symbol(symbol)
        if sym.number_records == 0:
            raise ValueError(f"Symbol {symbol} has no records in job output database: {str(self)}.")
        
        if sym.dimension == 0:
            self.Symbols[symbol] = sym.first_record().level
        
        elif sym.dimension == 1:
            self.Symbols[symbol.name] = self.gw.getDataFrame(symbol.name, attrName)
        
        elif sym.dimension >= 2:
            self.Symbols[symbol.name] = self.gw.getRecords(symbol.name, attrName)
         
        return self.Symbols[symbol]

