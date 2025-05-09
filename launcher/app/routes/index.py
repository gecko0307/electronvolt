import bottle
from ..config import *
from ..data import *

@bottle.route('/')
def index(db):
    d = profileData(db)
    return bottle.template(load('index.stpl'), data = d)