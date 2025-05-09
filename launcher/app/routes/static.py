import bottle
from ..config import *

@bottle.route('/<filename:path>')
def serverStatic(filename):
    return bottle.static_file(filename, root = Config.sitePath)
