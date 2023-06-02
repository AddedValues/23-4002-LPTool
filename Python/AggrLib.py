# -*- coding: utf-8 -*-
"""
Script til blokopdeling af tidsserie. 

Created on Thu Mar 31 07:29:38 2022

@author: MogensBechLaursen
"""
import os
# from typing import tuple
import logging
import numpy as np
import pandas as pd
import scipy.signal as sci

logger = logging.getLogger('MEC')

#%% Class definitions

class BlockOptions():
    """
    Parameters
    ----------
    spec : dict
        dictionary of individual options
    years : tuple[int,int]
        First and last year of elspot prices
    height : float
        Max. amplitude span of any block
    minLen  : int
        Min. length (no. of time points) of any block.
    maxLen : int
        Max. length (no. of time points) of any block.
    peakSeparation : int
        Min. no. of time points between peaks of the secondary time series.
    peakMinHeight : float
        Min. height of a peak of the secondary time series.
    peakWidth : int
        Width of any peak of the secondary time series (i.e. the length of a sub-block defined by the secondary series)
    minProminence: float
        Min. prominence [1 .. 100] of any peak if it shall influence sub-partitioning primary blocks.

    Returns
    -------
    BlockOptions instance
    """
    
    def __init__(self, name: str, spec:dict=None, years:tuple[int,int]=None, height:float=None, minLen:int=None, maxLen:int=None, \
                       peakSeparation:int=None, peakMinHeight:float=None, peakWidth:int=None, minProminence:float=None):
        
        # HACK
        self.useSecondary = True
        self.name = name
        
        if spec is None:
            self.yearBeg         = years[0]
            self.yearEnd         = years[1]
            self.height          = height
            self.peakMinHeight   = peakMinHeight
            self.peakSeparation  = peakSeparation
            self.peakWidth       = peakWidth
            self.minProminence   = minProminence
            self.minLen          = minLen 
            self.maxLen          = maxLen
        else:
            self.yearBeg         = int(spec['yearBegin']) 
            self.yearEnd         = int(spec['yearEnd']) 
            self.height          = spec['blockHeight']
            self.peakMinHeight   = spec['peakMinHeight']
            self.peakSeparation  = int(spec['peakSeparation'])
            self.peakWidth       = int(spec['peakWidth'])
            self.minProminence   = spec['minProminence']
            self.minLen          = int(spec['blockMinLen'])
            self.maxLen          = int(spec['blockMaxLen'])
            
        if self.yearBeg > self.yearEnd:
            raise ValueError('{self.yearBegin=} must less or equal to {self.yearEnd=}')
        if self.height <= 0:
            raise ValueError('blockHeight={} must be positive.'.format(self.height))
        if self.peakSeparation < 0 or self.peakSeparation <= self.peakWidth:
            raise ValueError('Peak separation={} must be positive and less than peakWidth={}'.format(self.peakSeparation, self.peakWidth))
        if self.peakWidth >= self.minLen:
            raise ValueError('peakWidth = {} must be less than min. block length minLen = {}'.format(self.peakWidth, self.minLen))
        if self.peakWidth < 0 or ((self.peakWidth % 2 == 0) and self.peakWidth >=1):
            raise ValueError('peakWidth={} must be non-negative and odd'.format(self.peakWidth))
        if self.minProminence < 0:  # value > 100 means ignoring secondary partitioning.
            raise ValueError('Min. prominence promMin={} must be positive and normally within range 0..100'.format(self.minProminence))
        if self.minLen < self.peakWidth:
            raise ValueError('Min. block length minLen={} must be larger than peakWidth={}'.format(self.minLen, self.peakWidth))

        if self.maxLen == 0:
            self.maxLen = 2**16
        
    def __str__(self):
        return 'yearBeg={}, yearEnd={}, height={}, minLen={}, maxLen={}, peakMinHeight={}, peakSeparation={}, peakWidth={}, minProminence={}'  \
               .format(self.yearBeg, self.yearEnd, self.height, self.minLen, self.maxLen, self.peakMinHeight, self.peakSeparation, self.peakWidth, self.minProminence)
    
    def __repr__(self):
        return self.__str__()
    

class Block():
    """
    Parameters
    ----------
    begin : int
        First time point of block (zero-based).
    end : int
        Last time point of block (zero-based).
    amplitudes: [float]
        amplitudes belonging to this block.

    Returns
    -------
    Block instance

    """
    def __init__(self, begin:int, end:int, amplitudes:np.array):
        # NB: time coordinates begin and end are 0-based.
        self.begin = begin
        self.end = end
        self.count = end - begin + 1
        self.average = np.average(amplitudes)
        self.min = np.min(amplitudes)
        self.max = np.max(amplitudes)
        self.span = self.max - self.min 
        self.amplitudes = amplitudes[begin:end+1]
        
    def GetAsBase0(self):
        return [self.begin, self.end, self.count, self.average, self.min, self.max, self.span]

    def GetAsBase1(self):
        return [self.begin + 1, self.end + 1, self.count, self.average, self.min, self.max, self.span]

    def __len__(self):
        return self.count
    
    def __str__(self):
        return '[begin={}, end={}, count={}]'.format(self.begin, self.end, self.count)
    
    def __repr__(self):
        return '[begin={}, end={}, count={}, min={}, max={}, span={}]'.format(self.begin, self.end, self.count, self.min, self.max, self.span)

    def embraces(self, index:int):
        return (self.begin <= index and index <= self.end)
    
    def peakIsBefore(self, peak):
        return peak.index < self.begin
    
    def peakIsAfter(self, peak):
        return peak.index > self.end
    
    def getSubBlocks(self, peak, peakWidth:float, amplitudes:np.array):
        newBlocks = list()
        ibegSub = peak.index - int(peakWidth / 2)
        iendSub = peak.index + int(peakWidth / 2)
        # logger.debug('tp={}, ibBeg={}, ibEnd={}, ibegSub={}, iendSub={}'.format(peak.index, self.begin, self.end, ibegSub, iendSub))
    
        # Split block into 2 or 3 new blocks dependent on its edge proximity.
        if ibegSub <= self.begin:    # New sub-block touches or crosses left edge of block.
            # Two new sub-blocks to be created.
            ibegSub = max(self.begin, ibegSub)
            # logger.debug('left-most ibegSub={}, iendSub={}'.format(ibegSub, iendSub))
            b2 = Block(ibegSub,   iendSub,  amplitudes[ibegSub:iendSub+1])
            b3 = Block(iendSub+1, self.end, amplitudes[iendSub+1:self.end+1])
            newBlocks.extend([b2, b3])
            # logger.debug('\nb1={}, \nb2={}, \nb3={}'.format('void', b2, b3))
        elif iendSub >= self.end:  # New sub-block touches or crosses right edge of block.
            # Two new sub-blocks to be created.
            iendSub = min(self.end, iendSub)
            # logger.debug('right-most ibegSub={}, iendSub={}'.format(ibegSub, iendSub))
            b1 = Block(self.begin, ibegSub - 1, amplitudes[self.begin:ibegSub])
            b2 = Block(ibegSub,    iendSub,     amplitudes[ibegSub:iendSub+1])
            newBlocks.extend([b1, b2])
            # logger.debug('\nb1={}, \nb2={}, \nb3={}'.format(b1, b2, 'void'))
        else:
            # Three new sub-blocks to be created.
            # logger.debug('in-between ibegSub={}, iendSub={}'.format(ibegSub, iendSub))
            b1 = Block(self.begin, ibegSub - 1, amplitudes[self.begin:ibegSub])
            b2 = Block(ibegSub,    iendSub,     amplitudes[ibegSub:iendSub+1])
            b3 = Block(iendSub+1,  self.end,    amplitudes[iendSub+1:self.end+1])
            newBlocks.extend([b1, b2, b3])
            # logger.debug('\nb1={}, \nb2={}, \nb3={}'.format(b1, b2, b3))
            
        return newBlocks


class Peak():
    """ 
    Parameters
    ----------
    index: int
        Index of peak in the originating timeseries.
    amplitude: float
        Amplitude of peak
    prominence: float
        The strenght of the peak as compared to its surrounding part of the time series.
        Prominence as defined by function scipy.signal.peak_prominences 
        albeit normalized against the largest one and multiplied by 100 (to get an easy value).
    Returns
    -------
    Peak instance
    """        
    def __init__(self, index: int, amplitude:float, prominence:float):
        self.index = index
        self.amplitude = amplitude
        self.prominence = int(prominence)
        self.wasUsed = False
        
    def __str__(self):
        return self.__repr__()
    
    def __repr__(self):
        return '[index={}, amplitude={}, prominence={}]'.format(self.index, self.amplitude, self.prominence)
        
    def GetAsBase0(self):
        return [self.index, self.amplitude, self.prominence]

    def GetAsBase1(self):
        return [self.index + 1, self.amplitude, self.prominence]


#%% GetBlocksBase0 Compute base-0 indexed blocks (0-based) and return as dataframes

def GetBlocksBase0(options:BlockOptions, primaryTs : np.array, secondaryTs : np.array, shifts: np.array):

    # Compute blocks and afterwards, convert to base-0 representation of indices    
    blocks, blockSeries, peaks = CalcBlocks(options, primaryTs, secondaryTs, shifts)
    
    # Convert blocks to 0-based indices and cast into a DataFrame.
    nblock = len(blocks)
    arrBlocks = np.zeros(shape=(nblock,7), dtype='float')
    for i in range(nblock):
        arrBlocks[i,:] = blocks[i].GetAsBase0()
    
    npeak = len(peaks)
    arrPeaks = np.zeros(shape=(npeak,3), dtype='float')
    for ip in range(npeak):
        arrPeaks[ip,:] = peaks[ip].GetAsBase0()

    dfBlocks = pd.DataFrame(arrBlocks, columns=['Begin', 'End', 'Count', 'Average', 'Min', 'Max', 'Span'])
    dfBlockSeries = pd.DataFrame(blockSeries, columns=['Min', 'Max'])
    dfPeaks = pd.DataFrame(arrPeaks, columns=['Index', 'Amplitude', 'Prominence'])
    
    return dfBlocks, dfBlockSeries, dfPeaks


#%% GetBlocksBase1 Compute Excel-indexed blocks (1-based) and return as dataframes

def GetBlocksBase1(options: BlockOptions, primaryTs : np.array, secondaryTs : np.array, shifts: np.array):
    
    # Compute blocks and afterwards, convert to base-1 representation of indices    
    blocks, blockSeries, peaks = CalcBlocks(options, primaryTs, secondaryTs, shifts)
    
    # Convert blocks to 1-based indices and cast into a DataFrame.
    nblock = len(blocks)
    arrBlocks = np.zeros(shape=(nblock,7), dtype='float')
    for i in range(nblock):
        arrBlocks[i,:] = blocks[i].GetAsBase1()
    
    npeak = len(peaks)
    arrPeaks = np.zeros(shape=(npeak,3), dtype='float')
    for ip in range(npeak):
        arrPeaks[ip,:] = peaks[ip].GetAsBase1()

    dfBlocks = pd.DataFrame(arrBlocks, columns=['Begin', 'End', 'Count', 'Average', 'Min', 'Max', 'Span'])
    dfBlockSeries = pd.DataFrame(blockSeries, columns=['Min', 'Max'])
    dfPeaks = pd.DataFrame(arrPeaks, columns=['Index', 'Amplitude', 'Prominence'])
    
    return dfBlocks, dfBlockSeries, dfPeaks


#%% CalcBlocks Compute time blocks for the driving time series.
def CalcBlocks(options:BlockOptions, primaryTs: np.array, secondaryTs: np.array, shifts: np.array):
    """
    Calculates a partitioning of a timeseries into blocks of time points. 
    The partioning is refined using a secondary timeseries such that peaks of the latter are used for sub-dividing a primary block.
    
    A number of criteria governs the partioning.
    The height h is the largest amplitude span within a block.
    Once the primary partioning is done, the secondary sets in using these criteria:
        blockMin:  Only primary blocks of length (count) greater or equal to blockMin will be considered.
        peakWidth: The width of the sub-block holding a peak.
        promMin:   A minimum prominence of a peak if it shall be used for sub-partitioning.
    No block may span across a time point listed in parameter shifts.
    
    Parameters
    ----------
    options : BlockOptions
        Options controlling the partitioning the time series into blocks.
    primaryTs : np.array
        Timeseries 0-based used for the primary partioning.
    secondaryTs : np.array
        Timeseries 0-based used for the secondary partioning.
    shifts: np.array
        Timepoints 0-based  used for mandatory block boundaries.

    Raises
    ------
    ValueError
        DESCRIPTION.

    Returns
    -------
    blocks : list
        Instances of class Block.
    blockSeries : numpy array (ntime,2)
        Holds blocks as a timeseries with min and max amplitude.
    """
    # logger.debug(f'options={options}')                            
    ntime = len(primaryTs)
    blocks = list()   # Each member will be a Block instance.
    shiftFound = False
    i = 0
    while i < ntime:
        found = False
        # Compute maximum length of next block.
        if shiftFound: 
            # logger.debug(f'{i=} after a shift was found.')
            shiftFound = False
        maxLen = options.maxLen
        shiftFound = False

        # Check if at least one shift appears within the max length of next block.
        # Beware that more than one shift can reside within the interval i .. i+maxLen-1.
        mask = np.isin(range(i, i + maxLen), shifts)  # Returns an array of booleans.
        # if i in range(4700,4720):
        #     logger.debug(f'{i=}, {mask=}')
        for im, m in enumerate(mask):
            if m and im > 0:
                shiftTime = i + im 
                maxLen = shiftTime - i 
                shiftFound = True
                # logger.debug(f'{i=}, {im=}, {shiftTime=}, {maxLen=}')
                break

        jend = min(ntime, i + maxLen)
        for j in range(i+1, jend):
            maxdiffH = np.max(np.abs(primaryTs[j] - primaryTs[i:j]))
            if maxdiffH > options.height:
                found = True
                iend = j     # NB: point j was outside this block.
                block = Block(i, iend-1, primaryTs[i:iend])
                blocks.append(block)
                # logger.debug(f'i={i}, j={j}, block={block}, maxdiffH={maxdiffH}')
                i = j  
        
        if not found:
            # logger.debug(f'found={found}, i={i}, jend={jend}')
            iend = jend 
            block = Block(i, iend-1, primaryTs[i:iend])
            blocks.append(block)
            i = iend
    
    
    # Find peaks in secondary timeseries.
    # See: https://docs.scipy.org/doc/scipy/reference/generated/scipy.signal.find_peaks.html
    # See: https://docs.scipy.org/doc/scipy/reference/generated/scipy.signal.peak_prominences.html#scipy.signal.peak_prominences
    rawpeaks, props = sci.find_peaks(secondaryTs, height=options.peakMinHeight, distance=options.peakSeparation)
    prominences = sci.peak_prominences(secondaryTs, rawpeaks, wlen=None)
    prom = 100 * prominences[0] / np.max(prominences[0])
    peaks = [Peak(rawpeaks[ip], secondaryTs[rawpeaks[ip]], prom[ip]) for ip in range(len(rawpeaks))]
    
    if options.useSecondary and options.minProminence <= 100 and options.peakWidth >= 1:
        # Partitioning blocks based on peaks of the secondary timeseries.
        peakIsHandled = np.zeros(dtype='bool', shape=(len(peaks)))    # Tells if a peak has been handled.
        blockIsHandled = np.zeros(dtype='bool', shape=(len(blocks)))  # Tells if a primary block has been handled.
        newBlocks = list()  # Each member will be a Block instance.
        ipStart = 0
        
        for ib in range(len(blocks)):
            block = blocks[ib]
            # logger.debug('ib={}, block={}'.format(ib, block))
            if len(block) < options.minLen:
                # Peaks in small blocks are ignored.
                newBlocks.append(block)
                continue
        
            # The actual block may contain zero or several peaks.    
            for ip in range(ipStart, len(peaks)):
                peak = peaks[ip]
                # logger.debug('peak={}, block={}'.format(peak, block))
                if block.peakIsBefore(peak):
                    # logger.debug('Peak={} lies before block.begin={}'.format(peak.index, block.begin))
                    continue
                elif block.peakIsAfter(peak):
                    # logger.debug('Peak={} lies after block.end={}. Break'.format(peak.index, block.end))
                    ipStart = ip
                    break
                elif peak.prominence < options.minProminence:
                    # logger.debug('Peak={} prominence={} is below threshold={}'.format(peak.index, peak.prominence, promMin))
                    continue
                else:
                    # logger.debug('Peak={} lies within block={}'.format(peak.index, str(block)))
                    subBlocks = block.getSubBlocks(peak, options.peakWidth, primaryTs)
                    # logger.debug(f'{subBlocks=}')
        
                    # If current block is identical to the last of newBlocks, then remove it from the list.
                    if len(newBlocks) > 0 and newBlocks[len(newBlocks)-1] == block:
                        newBlocks.remove(block)
        
                    newBlocks.extend(subBlocks)
                    block = subBlocks[-1]
                    peakIsHandled[ip] = True
                    blockIsHandled[ib] = True

            if not blockIsHandled[ib]:
                newBlocks.append(block)
                blockIsHandled[ib] = True
            
        blocks = newBlocks
    
    # Unfolding blocks to timeseries.
    blockSeries = np.zeros(shape=(ntime,2), dtype='float')  # Min and Max amplitude values.
    for ib in range(len(blocks)):
        for ih in range(int(blocks[ib].begin), int(blocks[ib].end+1)):
            blockSeries[ih,0] = blocks[ib].min
            blockSeries[ih,1] = blocks[ib].max

    return blocks, blockSeries, peaks

