import os
from AppBase.LpBase import LpBase
from Engine import JobSpec, JobHandler, JobResult, JobStatus, JobScheduler

modelDir:str = r"C:\Github\23-4002-LPtool\master"
workDir:str = r"C:\Github\23-4002-LPtool\workdir"

def getModelText(name:str, modelDir:str) -> str:
    """ Returns the text of the model with the given name. """
    modelText = ""
    with open(os.path.join(modelDir, name + ".gms", "r")) as f:
        modelText = f.read()
    return modelText

#%%  Main program

if __name__ == "__main__":
    logger = LpBase.init("Main", "Main")
    try:
        jobSpec = JobSpec(name="Test", description="Test")
        modelName = "MecLpMain"
        modelText = getModelText(modelName, modelDir)
        jobHandler = JobHandler(name="Test", description="Test", wkdir=workDir, modelTest=modelText)

    except Exception as ex:
        logger.critical(f"Exception occurred: {ex}", exc_info=True)