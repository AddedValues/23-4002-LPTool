import sqlite3 as sql
import xlwings as xw
import pandas as pd 
import numpy as np
import uuid
''' 
https://www.sqlitetutorial.net/sqlite-data-types/ 
https://www.sqlite.org/lang_createtable.html
'''


if __name__ == "__main__":
        
    conn = sql.connect('App/Data/LpMock.db')
    cursor = conn.cursor()

    id = uuid.uuid4()

    # Create table
    cursor.execute('''CREATE TABLE IF NOT EXISTS stem_data(
                    id TEXT PRIMARY KEY NOT NULL, 
                    subtable_ids TEXT NOT NULL); ''')
    
    conn.commit()
    conn.close()