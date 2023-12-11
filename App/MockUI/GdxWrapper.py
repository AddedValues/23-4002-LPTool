# -*- coding: utf-8 -*-
"""
Created on Thu Dec 28 18:41:26 2017

Prequisites for using this python module:
1)	Open Anaconda prompt (shell)
2)	Navigate to C:\GAMS\33\apifiles\Python\<api_vv>
    where <api_vv> is the subfolder corresponding to the used 
    python version e.g. 3.8, so the subfolder will be api_38.
3)	Execute this command: python setup.py install
4)	Include this stmt in the .py file using this module: 
    from gams import *


@author: MogensBechLaursen
"""
# import os
# import sys
import inspect             # Inspection of the python stack.
import logging
import numpy as np
import pandas as pd
import gams as g
import copy
#--- import AppBase.LpBase as lpbase

# from gams import *

def whoami():
    s = inspect.stack()
    return [ s[1][3], s[2][3] ]  # function and caller names.

def isascii(s):
    """Check if the characters in string s are in ASCII, U+0-U+7F."""
    try: s.encode('ascii'); return True
    except UnicodeEncodeError: return False

def cleantext(txt : str):
    """
    Replaces Danish national characters with an appropriate character.
    Problem arises when using ASCII source files for GAMS.
    If not replaced the entire Python kernel may crash.
    """
    s = txt.replace('\udce6', 'æ').replace('\udcf8', 'ø').replace('\udce5', 'å') \
           .replace('\udcc6', 'Æ').replace('\udcd8', 'Ø').replace('\udcc5', 'Å')  # Gættet unicode code point for Å.
    return s


class GdxWrapper():
    """
    A class wrapping a single GAMS gdx database.
    Useful for extracting variables and parameters as numpy arrays.
    Note: Names for GAMS symbols and set members are case-insensitive.
    Usage: w = GdxWrapper('DIN', pathGdx)
    @author: MogensBechLaursen
    """

    # ----------------------------------------------------------------------------------------------------------
    def __init__(self, db: g.GamsDatabase, name:str= None, pathFile:str= None, loggerName: str = None):
        """Initializes instance by a user-given database or by a name and a file path."""
        # pathGdx = r'C:\Users\MogensBechLaursen\Documents\gamsdir\projdir\DIN\ESV4\ESV4 scenarier\219MWf\DIN 101.gdx'

        if loggerName is None:
            loggerName = 'DefaultLogger'

        self.logger = logging.getLogger(loggerName)
        
        if db is None:
            self.name = name
            self.pathFile = pathFile
            self.ws = g.GamsWorkspace()
            self.db = self.ws.add_database_from_gdx(pathFile, database_name=name)
        else:
            self.db = db
            self.name = db.name

        self.sets = {}
        self.parms = {}
        self.vars = {}
        self.eqns = {}
        for symbol in self.db:
            if isinstance(symbol, g.GamsSet):
                self.sets[symbol.name] = symbol
            elif isinstance(symbol, g.GamsParameter):
                self.parms[symbol.name] = symbol
            elif isinstance(symbol, g.GamsVariable):
                self.vars[symbol.name] = symbol
            elif isinstance(symbol, g.GamsEquation):
                self.eqns[symbol.name] = symbol
            else:
                raise ValueError(f'Unknown GAMS symbol kind = {symbol.name}')

        self.setLookup = self.__getSymbolLookup(self.sets.keys())
        self.parmLookup = self.__getSymbolLookup(self.parms.keys())
        self.varLookup = self.__getSymbolLookup(self.vars.keys())
        self.eqnLookup = self.__getSymbolLookup(self.eqns.keys())

        self.all = {**self.sets, **self.parms, **self.vars, **self.eqns}
        
        # self.allLookup =  dict() # Key is symbol kind {set,parm,var,eqn}
        # self.allLookup['set'] = self.setLookup
        # self.allLookup['parm'] = self.parmLookup
        # self.allLookup['var'] = self.varLookup
        # self.allLookup['eqn'] = self.eqnLookup

        return

    # ----------------------------------------------------------------------------------------------------------
    def firstkey(self, d : dict):
        """ First key of dictionary d. Python has no such method."""
        if d is None:
            return None
        else:
            return list(d.keys())[0]
        
    def __getSymbolLookup(self, skeys):
        """Private: Creates a lookup dictionary from lower case names to correct casing."""
        slookup = dict()
        for s in skeys:
            slookup[s.lower()] = s
        return slookup

    # ----------------------------------------------------------------------------------------------------------
    def __getMemberCased(self, s, m):
        """ Private: Returns the correctly cased name of member m belonging to set s."""
        mLower = m.lower()
        for member in s:
            if member.key(0).lower() == mLower:
                return member.key(0)
        raise Exception('Member ' + member.key(0) + ' was not found in set ' + s.name)

    # ----------------------------------------------------------------------------------------------------------
    def getSetNames(self):
        return np.array(sorted(self.sets.keys()))

    # ----------------------------------------------------------------------------------------------------------
    def getParmNames(self):
        return np.array(sorted(self.parms.keys()))

    # ----------------------------------------------------------------------------------------------------------
    def getVarNames(self):
        return np.array(sorted(self.vars.keys()))

    # ----------------------------------------------------------------------------------------------------------
    def getEqnNames(self):
        return np.array(sorted(self.eqns.keys()))

    # ----------------------------------------------------------------------------------------------------------
    def getSetMembers(self, setName):
        nameLower = setName.lower()
        if nameLower not in self.setLookup.keys():
            raise Exception('Set ' + setName + ' was not found')
        s = self.getSet(self.setLookup[nameLower])
        members = list()
        for rec in s:
            members.append(rec.key(0))

        return members

    # ----------------------------------------------------------------------------------------------------------
    def getSet(self, setName):
        """Returns the set of name setName, if any, else returns None"""
        nameLower = setName.lower()
        if nameLower in self.setLookup.keys():
            return self.sets[self.setLookup[nameLower]]
        else:
            return None

    # ----------------------------------------------------------------------------------------------------------
    def getParm(self, parmName):
        """Returns the parm of name parmName, if any, else returns None"""
        nameLower = parmName.lower()
        if nameLower in self.parmLookup.keys():
            return self.parms[self.parmLookup[nameLower]]
        else:
            return None

    # ----------------------------------------------------------------------------------------------------------
    def getVar(self, varName):
        """Returns the var of name varName, if any, else returns None"""
        nameLower = varName.lower()
        if nameLower in self.varLookup.keys():
            return self.vars[self.varLookup[nameLower]]
        else:
            return None

    # ----------------------------------------------------------------------------------------------------------
    def getEqn(self, eqnName):
        """Returns the equation of name eqnName, if any, else returns None"""
        nameLower = eqnName.lower()
        if nameLower in self.eqnLookup.keys():
            return self.eqns[self.eqnLookup[nameLower]]
        else:
            return None

    # ----------------------------------------------------------------------------------------------------------
    def getSymbolKind(self, symbolName):
        """
        Returns [kind, symbol] of the GAMS symbol given by name symbolName.
          kind    is a string among {'set', 'eqn', 'parm', 'var'}
          symbol  The GAMS symbol instance as retrieved from the gdx-file.

        If no symbol is found, ['None', None] is returned.
        """
        symbol = self.getSet(symbolName)
        if symbol is not None:
            kind = 'set'
            return [kind, symbol]
        symbol = self.getParm(symbolName)
        if symbol is not None:
            kind = 'parm'
            return [kind, symbol]
        symbol = self.getVar(symbolName)
        if symbol is not None:
            kind = 'var'
            return [kind, symbol]
        symbol = self.getEqn(symbolName)
        if symbol is not None:
            kind = 'eqn'
            return [kind, symbol]

        return ['None', None]

    # def getGSymbol(self, symbolName) -> GSymbol:
    #     """ Returns GamsSymbol instance wrapped as GSymbol instance or None if non-existent."""
    #     [kind, symbol] = self.getSymbolKind(symbolName)
    #     if symbol is None:
    #         return None
    #     else:
    #         return GSymbol(symbol, self)

    #     return
    
    # ----------------------------------------------------------------------------------------------------------
    def getAsGSymbols(self, symFilter = None):  # symbolkind:str, 
        """
        Returns a list of GAMS symbols wrapped as GSymbol instances.

        Parameters
        ----------
        symbolkind : str
            One of {set, parm, var, eqn}
        symFilter : function(gsym:GSymbol) -> boolean
            Filter on symbols to be returned. 
            Symbol gsym is included if symFilter(gsym) yields True.
            If symFilter is None, every symbol of kind symbolkind is returned.
        """
        # if symbolkind not in self.allLookup.keys():
        #     raise ValueError(F'symbolkind={symbolkind} is not recognized.')
        # self.logger.debug(F'symFilter = {type(symFilter)}')
        # self.logger.debug(f'I am {whoami()}')
        
        gsymFilter = symFilter
        if gsymFilter is None:
            gsymFilter = (lambda gsym: True)
        # self.logger.debug(f'{type(gsymFilter)}')

        try:
            items = dict()   # Key is name of symbol.
            for i, symbol in enumerate(self.all.values()):
                # self.logger.debug(f'i={i}, symbol={symbol.name}, domains={symbol.domains_as_strings}')
                # if symbol.domains_as_strings[0] == '*':
                    # continue
                gsym = GSymbol(symbol, self)
                # self.logger.debug(f'symbol = {gsym.name}') #--- ', symFilter={gsymFilter(gsym)}')
                try:
                    include = gsymFilter(gsym)
                    # self.logger.debug(f'Applied gsymFilter on {gsym.name} and got {include}')
                except Exception as e:
                    self.logger.critical(f'Symbol={gsym}: Exception = {e}', exc_info=True)
                if gsymFilter(gsym):
                    items[symbol.name] = gsym
            return items
        except Exception as e:
            stack = whoami()
            self.logger.critical(f'{type(e)} raised in {stack[0]} called by {stack[1]}', exc_info=True)
            return None
        
    # ----------------------------------------------------------------------------------------------------------
            
    def getSymRecords(self, symFilter, recFilter, funcResult):
        """
        Returns a dict of symbols and value as specified by the passed filters:
            symFilter: function(gsym: GSymbol) Filters the type of symbol to be fetched. Used in callind getAsGSymbols.
            recFilter: function(gref: GRecord)
            
        Example: Getting equations having a positive marginal value.
            # Define filters and which value to return:
            symFilter = lambda gsym: gsym.kind == 'eqn' and gsym.eqntype == 'L'
            recFilter = lambda grec: grec.marginal > 1E-14
            funcResult = lambda grec: grec.marginal
            # Call function:
            recs, syms = getEqnRecords(w, symFilter, recFilter, funcResult)
            
        where:
            recs: dictionary(key,GRecord): key is symbol name and record keys delimited by '/'
            sym:  dictionary(key,GSymbol): key is symbol name.

        """
        syms = self.getAsGSymbols(symFilter)
        results = dict()
        if syms == None or len(syms) == 0:
            return None, None, None
        for sym in [s for s in syms.values()]:
            for rec in sym.getRecords():
                if recFilter(rec):
                    # Compose a unique key for rec.
                    key = sym.name
                    for k in rec.keys:
                        key += '/' + k
                    results[key] = funcResult(rec)
        
        return results, syms

    # ----------------------------------------------------------------------------------------------------------
    def getAttrValue(self, symbolKind, rec, gAttrName):
        """
        Intended for internal use in this class.

        Returns the attribute value given by gAttrName
        from the record rec of the GAMS symbol of kind symbolKind.
        symbolKind:  One of {'eqn', 'parm', 'var'};  'set' makes no sense.
        rec       :  A GamsSymbolRecord from which the attribute value shall be retrieved.
        gAttrName :  Name of the GAMS symbol record attribute:
                     symbolKind = 'parm': gAttrName = 'level' or 'value' (synonymous)
                     symbolKind = 'var' : gAttrName = {'level', 'marginal', 'lower', 'upper', 'scale'}
                     symbolKind = 'eqn' : gAttrName = {'level', 'marginal', 'lower', 'upper', 'scale'}
        """
        if gAttrName == 'level' or gAttrName == 'value':
            if symbolKind == 'parm':
                return rec.value
            else:
                return rec.level

        if symbolKind == 'parm':
            raise Exception('GAMS parm has no attribute by name ' + gAttrName)

        if gAttrName == 'marginal':
            return rec.marginal
        elif gAttrName == 'scale':
            return rec.scale
        elif gAttrName == 'lower':
            return rec.lower
        elif gAttrName == 'upper':
            return rec.upper
        else:
            raise Exception('GAMS symbol record attribute ' + gAttrName + ' is unknown')

    # ----------------------------------------------------------------------------------------------------------
    def getValue(self, symbolName, attrName='level'):
        """
        Returns attribute values of named scalar symbol (parm, var or eqn) as a double.
          symbolName:      Name of GAMS symbol (must be parm or var).
          attrName:        Attribute to be retrieved from symbol (defaults to 'level' / 'value'):
                           Parm:     {level} or {value}; {level} is used as an alias for {value}
                           Var, Eqn: {level,marginal,lower,upper,scale}
        """
        return self.getValues(symbolName, None, None, attrName)
    
    def getValue1(self, symbolName, attrName='level'):
        """
        Returns attribute values of named scalar symbol (parm, var or eqn) as a double.
          symbolName:      Name of GAMS symbol (must be parm or var).
          attrName:        Attribute to be retrieved from symbol (defaults to 'level' / 'value'):
                           Parm:     {level} or {value}; {level} is used as an alias for {value}
                           Var, Eqn: {level,marginal,lower,upper,scale}
        """
        return self.getValues(symbolName, None, None, attrName)

    # ----------------------------------------------------------------------------------------------------------
    def getValues(self, symbolName, freeSetKey, fixSetKeyValues, attrName='level', asDict=False):
        """
        Returns attribute values of named symbol (parm, var or eqn) as a list of doubles.
          symbolName:      Name of GAMS symbol (must be parm or var).
          freeSetKey:      Name of single set (1-D) roaming freely.
          fixSetKeyValues: Dictionary of domain sets having fixed values.
                          e.g. { 'k':'ESV4'}
          NOTE: [1 + Length of fixSetKeyValues] must equal dimensionality of symbol.

          attrName:        Attribute to be retrieved from symbol (defaults to 'level' / 'value'):
                           Parm:     {level} or {value}; {level} is used as an alias for {value}
                           Var, Eqn: {level,marginal,lower,upper,scale}
                           
          asDict:          Return result as dictionary using freeSetKey values as key.
        """

        # print str(datetime.now())
        # print 'Debug: symbolName = ' + symbolName

        [kind, symbol] = self.getSymbolKind(symbolName)
        if symbol is None:
            self.logger.error('GAMS symbol name ' + symbolName + ' is neither Set, Parameter, Variable nor Equation')
            raise ValueError('GAMS symbol name ' + symbolName + ' is neither Set, Parameter, Variable nor Equation')

        gSymbol = GSymbol(symbol, self)
        if gSymbol.kind == 'set':
            self.logger.error('Cannot retrieve value(s) for a GAMS set.')
            raise ValueError('Cannot retrieve value(s) for a GAMS set.')

        # Handle scalars first as they have no dependencies on sets.
        if gSymbol.isScalar:
            rec = symbol.first_record()
            attrValue = self.getAttrValue(gSymbol.kind, rec, attrName)
            return attrValue

        # Handle symbols having dimension larger than zero.
        # Verify existence of set keys.
        errorFound = False
        errorFound = freeSetKey.lower() not in self.setLookup.keys()
        if errorFound:
            self.logger.error('freeSetKey = ' + freeSetKey + ' is not a GAMS set.')
        for key in fixSetKeyValues.keys():
            # print 'debug: key = ' + key
            # print 'debug: key = ' + key.lower()
            if key.lower() not in self.setLookup.keys():
                errorFound = True
                self.logger.error('fixSetKey = ' + key + ' is not a GAMS set.')
        if errorFound:
            raise Exception('Errors found in set key(s)')

        # All but one domain (set) must be fixed.
        qdom = symbol.domains_as_strings
        nMissing = len(qdom) - 1 - len(fixSetKeyValues)
        if nMissing != 0:
            self.logger.error(f'Domains of {symbol.name}: {str(qdom)}')
            raise Exception(f'Missing {str(nMissing)} fixed set values of GAMS symbol {symbol.name}')

        # Convert user-given keys to proper case
        # and save in like-named variables appended with '2'.
        freeSetKey2 = self.setLookup[freeSetKey.lower()]
        fixSetKeyValues2 = dict()
        for k in fixSetKeyValues.keys():
            v = fixSetKeyValues[k]
            kk = self.setLookup[k.lower()]
            ss = self.sets[kk]
            vv = self.__getMemberCased(ss, v)
            fixSetKeyValues2[kk] = vv

        # Create lookup index using lower case set names as key.
        qdomIndex = {}
        for dom in qdom:
            qdomIndex[dom] = qdom.index(dom)

        freeIndx = qdomIndex[freeSetKey2]

        # Remove the index that we will not test against fixSetKeys.
        del qdomIndex[freeSetKey2]

        freeSet = self.sets[freeSetKey2]
        nValue = freeSet.number_records
        lookup = dict()
        index = 0
        for rec in freeSet:
            lookup[rec.key(0)] = index
            index += 1

        # Create array of zeroes to receive var values (level in GAMS parlor).
        values = np.zeros(nValue)

        # Get the values of item for all members of freeSet and
        # for specified fixed members of the other sets of the domain.
        # Non-existing records signifies a zero-valued record (not stored by GAMS).

        # Loop the GAMS symbol and extract values from all
        # records satisfying the criteria and insert at the
        # proper location within array 'values'.
        useFastAccess = False  # = (attrName == 'level' or attrName == 'value')
        for rec in symbol:
            validRec = True
            for ikey in qdomIndex.keys():
                ival = qdomIndex[ikey]
                rKey = rec.key(ival)
                vv = (rKey == fixSetKeyValues2[ikey])
                validRec = validRec and vv
                if not validRec:
                    break

            if validRec:
                # Find the index within the receiving array using the free set.
                freeKey = rec.key(freeIndx)
                vIndx = lookup[freeKey]
                if useFastAccess:
                    if gSymbol.kind == 'var' or gSymbol.kind == 'eqn':
                        values[vIndx] = rec.level
                    else:
                        values[vIndx] = rec.value
                else:
                    attrValue = self.getAttrValue(gSymbol.kind, rec, attrName)
                    values[vIndx] = attrValue

        if asDict:
            return dict(zip(lookup.keys(), values))
        else:
            return values

    # ----------------------------------------------------------------------------------------------------------
    def getDataFrame(self, symbolName, attrName='level'):
        """
        Returns attribute values of named symbol (parm, var or eqn) as a pandas dataframe.
          symbolName:      Name of GAMS symbol (must be eqn, parm, var).
          attrName:        Attribute to be retrieved from symbol (defaults to 'level' / 'value'):
                           Parm:     {level} or {value}; {level} is used as an alias for {value}
                           Var, Eqn: {level,marginal,lower,upper,scale}
         If symbol has dimension 1 (one) then a dictionary is returned, otherwise a dataframe.
        """

        # print str(datetime.now())
        # self.logger.debug('symbolName = ' + symbolName)

        [kind, symbol] = self.getSymbolKind(symbolName)
        if symbol is None:
            self.logger.error(f'GAMS symbol name {symbolName} is neither Set, Parameter, Variable nor Equation')
            return []

        gSymbol = GSymbol(symbol, self)
        if gSymbol.kind == 'set':
            self.logger.error('Cannot retrieve value(s) for GAMS set.')
            return []

        if gSymbol.dimension == 0:
            self.logger.error('Cannot convert scalar symbol into a dataframe')
            return None

        if gSymbol.dimension > 2:
            self.logger.error('Cannot convert symbol with more than 2 dimensions into a dataframe')
            return None

        # Handle symbols having dimension 1 or 2.
        # Symbol has dimension 1 (one) resulting in a dictionary.
        doms = symbol.domains_as_strings
        # for idom in range(len(doms)):
        #     self.logger.debug('{0}.domain[{1}] = {2}'.format(symbolName, idom, doms[idom]))
        if gSymbol.dimension == 1: 
            d = dict()
            for rec in symbol:
                attrValue = self.getAttrValue(gSymbol.kind, rec, attrName)
                d[rec.keys[0]] = attrValue

            return d

        # Symbol has dimension 2 resulting in a dataframe.
        rowSet = self.getSet(doms[0])
        rowKeys = self.getSetMembers(rowSet.name)
        nRow = rowSet.number_records
        # if gSymbol.dimension == 1 and not returnAsDict:
        #     colKeys = ['Value']
        #     nCol = 1
        # else: 
        colSet = self.getSet(doms[1])
        colKeys = self.getSetMembers(colSet.name)
        nCol = colSet.number_records
            
        # self.logger.debug('nRow='+str(nRow)+', nCol='+str(nCol))
        df = pd.DataFrame(data=np.zeros((nRow , nCol)))
        df.index = rowKeys
        df.columns = colKeys

        for rec in symbol:
            attrValue = self.getAttrValue(gSymbol.kind, rec, attrName)
            df.loc[rec.keys[0], rec.keys[1]] = attrValue

        return df
    # ----------------------------------------------------------------------------------------------------------

    def getDataFrame2(self, symbolName, freeSets=(), fixedSets={}, subSetOfFreeSet=[], indexRow = True, attrName='level'):
        """
        Janus
        Import an  n x n dataframe, with free sets as rows and cols, and fixed sets set fixed
        The functionality is an extension of getDataFrame
        subSetOfFreeSet works only on the Columns as of yet
        """
        assert type(freeSets)==type(()), 'Error 901: freeSets must have type Tuple'
        assert type(symbolName)==type(''), 'Error 902'
        assert type(fixedSets)==type({}), 'Error 903'
        assert type(attrName)==type(''), 'Error 904'
        assert len(freeSets)==2,    'Error905 freeSets must have exactly dimension 2'
        
        rowName = freeSets[0]
        colName = freeSets[1]
        
        if indexRow == False:
            rowSet = range(len(self.getSetMembers(rowName)))
        if indexRow == True:
            rowSet = self.getSetMembers(rowName)
        if len(subSetOfFreeSet) == 0:
            colSet = self.getSetMembers(colName)
        elif len(subSetOfFreeSet) > 0:
            colSet = subSetOfFreeSet
        else:
            self.logger.error('Error 906')
            return 
        nRow = len(rowSet)
        nCol = len(colSet)
        
        assert nRow > 1, 'Error920: first set in freeSets must have dimension > 1'
#        assert nCol > 1, 'Error921: second set in freeSets must have dimension > 1'

        df = pd.DataFrame(data=np.zeros((nRow,nCol)),index=rowSet,columns=colSet)
        
        for col in colSet:
            fixedSetsTemp = copy.deepcopy(fixedSets) # Need a temporary dict to work on
            fixedSetsTemp.update({colName: col})
            df[col] = self.getValues(symbolName, rowName, fixedSetsTemp)
        
        return df       
    
    def getDataFrame3(self,symbolName, freeSets=(), fixedSets={}, attrName='level'):
        """
        Janus
        Import an n x i x j dataframe, with free sets as rows and cols, and fixed sets set fixed
        The functionality is an extension of getDataFrame
        Columns are arranged as col1.dot1, col1.dot2, col2.dot1, ...
        """
        assert type(freeSets)==type(()), 'Error 1001: freeSets must have type Tupl'
        assert type(symbolName)==type(''), 'Error 1002'
        assert type(fixedSets)==type({}), 'Error 1003'
        assert type(attrName)==type(''), 'Error 1004'
        assert len(freeSets)==3,    'Error1005 freeSets must have excactly dimension 3'
        
        rowName = freeSets[0]
        colName = freeSets[1]
        dotName = freeSets[2]
        
        rowSet = self.getSetMembers(rowName)
        colSet = self.getSetMembers(colName)
        dotSet = self.getSetMembers(dotName)
        
        nRow = len(rowSet)
        nCol = len(colSet)
        nDot = len(dotSet)
        
    # ----------------------------------------------------------------------------------------------------------
    def getRecords(self, symbolName: str, attrName='level') -> pd.DataFrame:
        """
        Returns attribute values of named symbol (parm, var or eqn) as a pandas dataframe.
        The dataframe holds every record of the symbol where each dimension constitutes
        a column and every requested attribute likewise holds a column. 
        The Dataframe has a default enumerated index (zero-based).
          symbolName:      Name of GAMS symbol (must be eqn, parm, var).
          attrName:        Attribute to be retrieved from symbol (defaults to 'level' / 'value'):
                           Parm:     {level} or {value}; {level} is used as an alias for {value}
                           Var, Eqn: {level,marginal,lower,upper,scale}
        """

        # print str(datetime.now())
        # self.logger.debug('symbolName = ' + symbolName)

        [kind, symbol] = self.getSymbolKind(symbolName)
        if symbol is None:
            self.logger.error(f'GAMS symbol name {symbolName} is neither Set, Parameter, Variable nor Equation')
            return None

        gSymbol = GSymbol(symbol, self)
        doms = symbol.domains_as_strings
        # self.logger.debug(f'{symbolName=}: {doms=}, {gSymbol.nrec=}')
        colHeader = doms + [attrName]
        df = pd.DataFrame(index=range(gSymbol.nrec), columns=colHeader)
        for irec, rec in enumerate(symbol):
            attrValue = self.getAttrValue(gSymbol.kind, rec, attrName)
            colValues = rec.keys + [attrValue]
            # if irec < 10:
            #     self.logger.debug(f'{irec=}, {rec.keys=}, {colValues=}')
            df.iloc[irec,:] = colValues

        return df
    # ----------------------------------------------------------------------------------------------------------
       
# ----------------------------------------------------------------------------------------------------------

class GRecord():
    """
    A class wrapping a single GAMS gdx symbol record.
    Author: MBL
    """
    def __init__(self, rec, recKind:str):
        self.parent = rec.symbol.name
        self.kind = recKind
        self.keys = rec.keys
        if recKind == 'eqn' or recKind == 'var':
            self.value = rec.level
            self.marginal = rec.marginal
            self.lower = rec.lower
            self.upper = rec.upper
            # self.logger.debug(f'GRecord: sym={self.parent}, rec={rec.keys}, value={rec.level}, marginal={rec.marginal}')
        elif recKind == 'parm':
            self.value = rec.value
        elif recKind == 'set':
            self.value = rec.text
        else:
            raise ValueError('recKind = {0} is not permitted.'.format(recKind))

    def __str__(self):
        str = "{0}, {1}, keys={2}, {3}".format(self.parent, self.kind, self.keys, self.value)
        return str
    
    def __repr__(self):
        return self.__str__()
    
# ----------------------------------------------------------------------------------------------------------
class GSymbol():
    """
    A class wrapping a single GAMS gdx symbol.
    Provides easy access to attributes.
    Author: MBL
    """

    def __init__(self, symbol, gw:GdxWrapper):   #--- , logger: logging.Logger):
        """Initializes instance by a user-given symbol."""
        
        # self.logger = logger
        # self.logger.debug(f'type(gw) = {type(gw)}')
        self.gw = gw
        self.symbol = symbol
        self.vartype = None
        self.eqntype = None
        if isinstance(symbol, g.GamsSet):
            self.kind = 'set'
        elif isinstance(symbol, g.GamsParameter):
            self.kind = 'parm'
        elif isinstance(symbol, g.GamsVariable):
            self.kind = 'var'
            self.vartype = self.getVarType(symbol.vartype)
        elif isinstance(symbol, g.GamsEquation):
            self.kind = 'eqn'
            self.eqntype = self.getEqnType(symbol.equtype)
        # self.logger.debug(f'self.kind = {self.kind}')
        self.domains = symbol.domains_as_strings
        self.name = symbol.name
        self.text = cleantext(symbol.text)
        self.nrec = symbol.number_records
        # self.logger.debug(f'domains={self.domains}, name={self.name}, nrec={self.nrec}, text={self.text}')
        self.dimension = symbol.dimension
        self.isScalar = (symbol.dimension == 0)
        # self.logger.debug(f'dimension={self.dimension}, isScalar={self.isScalar}')
        self.recs = None
        self.sets = None

    def getRecords(self):
        self.recs = list()
        for rec in self.symbol:
            grec = GRecord(rec, self.kind)
            self.recs.append(grec)
        return self.recs
    
    def getSets(self):
        # Sets are returned as a list of list of strings
        self.sets = list()
        for setName in self.domains:
            s = self.gw.getSetMembers(setName)
            self.sets.append(s)
        return self.sets
    
    def getElement(self, keys, attrName='value'):
        if self.recs is None:
            self.getRecords()
            self.getSets()
            
        if len(keys) != self.dimension:
            raise ValueError('keys has length {0}, but symbol {1} has {2} keys.' \
                             .format(len(keys), self.name, self.dimension))
        
        elements = self.recs.copy()
        for k,key in enumerate(keys):
            elements = [e for e in elements if e.keys[k] == key]
            # self.logger.debug('k={0}, key={1}, elements=[{2}]'.format(k, key, elements))
        return elements
    
        
    def getEqnType(self, intEqnType):
        if intEqnType == 0:
            return 'E'
        elif intEqnType == 1:
            return 'G'
        elif intEqnType == 2:
            return 'L'
        elif intEqnType == 3:
            return 'N'
        elif intEqnType == 4:
            return 'X'
        elif intEqnType == 5:
            return 'C'
        raise Exception('Equation type enumeration ' + str(intEqnType) + ' is not defined')

    def getVarType(self, intVarType):
        if intVarType == 1:
            return 'Binary'
        elif intVarType == 2:
            return 'Integer'
        elif intVarType == 3:
            return 'Positive'
        elif intVarType == 4:
            return 'Negative'
        elif intVarType == 5:
            return 'Free'
        elif intVarType == 6:
            return 'SOS1'
        elif intVarType == 7:
            return 'SOS2'
        elif intVarType == 8:
            return 'SemiCont'
        elif intVarType == 9:
            return 'SemiInt'
        raise Exception('Equation type enumeration ' + str(intVarType) + ' is not defined')

    def __repr__(self):
        return str(self)
    
    def __str__(self):
        # return self.name
    
        if self.kind == 'eqn':
            str = f"{self.kind}, name={self.name}, dim={self.dimension}, eqntype={self.eqntype}, nrec={self.nrec}, Domains='{self.domains}"  #--- "\nDesc: {self.text}"
        elif self.kind == 'var':
            str = f"{self.kind}, name={self.name}, dim={self.dimension}, vartype={self.vartype} nrec={self.nrec} Domains='{self.domains}'"  #--- "\nDesc: {self.text}" 
        else:
            str = f"{self.kind}, name={self.name}, dim={self.dimension}, nrec={self.nrec} Domains='{self.domains}'"   #--- "\nDesc: {self.text}" 
        return str

    # ------------ End of class GSymbol  -----------------



