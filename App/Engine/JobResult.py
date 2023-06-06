import datetime as dt
import numpy as np
import pandas as pd
import logging
from   AppBase.LpBase import Lpbase
import gams
import AppBase.GdxWrapper as gw

class JobResult(Lpbase):
    _version = "0.0.1"

    def __init__(self, name:str, description:str, gdb: gams.GamsDatabase) -> None:
        super().__init__(name, description, JobResult._version)
        self.logger = logging.getLogger(Lpbase.logName)
        self.gdb = gdb
        self.gw = gw.GdxWrapper(self.gdb, name=gdb.name) #--- , logger=self.logger)

        self.entities = dict()       # Key is entity name, value is scalar, dictionary or DataFrame
        self.loadedSymbols = dict()  # Key is symbol name, value is GSymbol instance

        self.symbolList = [sym.name for sym in self.gdb]
        self.lookup = {name.lower() : name for name in self.symbolList}

        return

    def __str__(self) -> str:
        return f"{super().__str__()}, db={self.gdb.name}"
    
    def getEntity(self, symbolNameCaseInsensitive:str, attrName:str)  -> any:
        """ 
        Extracts given GAMS symbol as a scalar, a dictionary or a DataFrame.
        Returns a tuple (GSymbol, entity) where GSymbol is an instance of GSymbol and entity is the extracted entity.
        Argument symbolNameCaseInsensitive is the symbol name in any literal case.
        Argument attrName is the attribute name to extract: 'level', 'marginal', 'lower', 'upper', 'scale', 'stat', 'text'.
        """
        symbolName = self.lookup[symbolNameCaseInsensitive.lower()] 
        if symbolName in self.entities:
            return self.entities[symbolName]

        if not symbolName in self.symbolList:
            raise ValueError(f"Symbol {symbolName} not found in job output database: {str(self)}.")

        sym = self.gdb[symbolName]
        gsym = gw.GSymbol(sym, self.gw)
        self.loadedSymbols[symbolName] = gsym

        # Extract symbol from GAMS database. Sets are handled separately.
        if gsym.kind == 'set':
            entity = self.gw.getSetMembers(symbolName)
        elif sym.dimension == 0:
            entity = self.gw.getValue(symbolName, attrName)
        elif sym.dimension == 1:
            entity = self.gw.getDataFrame(symbolName, attrName)  # Returns a dictionary
        elif sym.dimension == 2:
            # entity = self.gw.getDataFrame(symbolName, attrName)
            entity = self.gw.getRecords(symbolName, attrName)
            # If entity is a (group of) timeseries, convert to DataFrame using 'tt' as index.
            if 'tt' in gsym.domains:
                # entity is a two-dimensional hence has three columns: tt, other-domain, attrName
                otherDomain = gsym.domains[1] if gsym.domains[0] == 'tt' else gsym.domains[0]
                df = entity.pivot(index='tt', columns=otherDomain, values=attrName)
                # Convert index to integer values after removing the 't' prefix of tt-members.
                df.index = [int(s[1:]) for s in df.index]
                df.sort_index(inplace=True)
                entity = df
            else:
                df.sort_index(inplace=True)
                entity = df

        else:
            entity = self.gw.getRecords(symbolName, attrName)

        self.entities[symbolName] = entity
        return (gsym, entity) 
