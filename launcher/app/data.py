import io
import datetime
from datetime import datetime

from .namespace import *
from .config import *

def load(name):
    f = io.open('%s/%s' % (Config.templatesPath, name), 'r', encoding = 'utf-8')
    s = f.read()
    f.close()
    return s

def datetimeFromSql(dts):
    return datetime.strptime(dts, '%Y-%m-%d %H:%M:%S')

# Generates SQL SELECT query matching the kwargs passed
def select(table, kwargs = None):
    sql = list()
    sql.append("SELECT * FROM %s" % table)
    if kwargs:
        sql.append(" WHERE " + " AND ".join("%s" % (v) for v in kwargs))
    return "".join(sql)

def profileData(db):
    data = NestedNamespace({
        'config': {
            'appInfo': Config.appInfo
        }
    })
    return data
