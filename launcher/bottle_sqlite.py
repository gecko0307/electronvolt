'''
Bottle-sqlite is a plugin that integrates SQLite3 with your Bottle
application. It automatically connects to a database at the beginning of a
request, passes the database handle to the route callback and closes the
connection afterwards.

To automatically detect routes that need a database connection, the plugin
searches for route callbacks that require a `db` keyword argument
(configurable) and skips routes that do not. This removes any overhead for
routes that don't need a database connection.

Usage Example::

    import bottle
    from bottle.ext import sqlite

    app = bottle.Bottle()
    plugin = sqlite.Plugin(dbfile='/tmp/test.db')
    app.install(plugin)

    @app.route('/show/:item')
    def show(item, db):
        row = db.execute('SELECT * from items where name=?', item).fetchone()
        if row:
            return template('showitem', page=row)
        return HTTPError(404, "Page not found")
'''

__author__ = "Marcel Hellkamp"
__version__ = '0.1.3'
__license__ = 'MIT'

### CUT HERE (see setup.py)

import sqlite3
import inspect
import bottle

# PluginError is defined to bottle >= 0.10
if not hasattr(bottle, 'PluginError'):
    class PluginError(bottle.BottleException):
        pass
    bottle.PluginError = PluginError


class SQLitePlugin(object):
    ''' This plugin passes an sqlite3 database handle to route callbacks
    that accept a `db` keyword argument. If a callback does not expect
    such a parameter, no connection is made. You can override the database
    settings on a per-route basis. '''

    name = 'sqlite'
    api = 2

    ''' python3 moves unicode to str '''
    try:
        unicode
    except NameError:
        unicode = str

    def __init__(self, dbfile=':memory:', autocommit=True, dictrows=True,
                 keyword='db', text_factory=unicode):
        self.dbfile = dbfile
        self.autocommit = autocommit
        self.dictrows = dictrows
        self.keyword = keyword
        self.text_factory = text_factory

    def setup(self, app):
        ''' Make sure that other installed plugins don't affect the same
            keyword argument.'''
        for other in app.plugins:
            if not isinstance(other, SQLitePlugin):
                continue
            if other.keyword == self.keyword:
                raise PluginError("Found another sqlite plugin with "
                                  "conflicting settings (non-unique keyword).")
            elif other.name == self.name:
                self.name += '_%s' % self.keyword

    def apply(self, callback, route):
        # hack to support bottle v0.9.x
        if bottle.__version__.startswith('0.9'):
            config = route['config']
            _callback = route['callback']
        else:
            config = route.config
            _callback = route.callback

        # Override global configuration with route-specific values.
        if "sqlite" in config:
            # support for configuration before `ConfigDict` namespaces
            g = lambda key, default: config.get('sqlite', {}).get(key, default)
        else:
            g = lambda key, default: config.get('sqlite.' + key, default)

        dbfile = g('dbfile', self.dbfile)
        autocommit = g('autocommit', self.autocommit)
        dictrows = g('dictrows', self.dictrows)
        keyword = g('keyword', self.keyword)
        text_factory = g('keyword', self.text_factory)

        # Test if the original callback accepts a 'db' keyword.
        # Ignore it if it does not need a database handle.
        argspec = inspect.getargspec(_callback)
        if keyword not in argspec.args:
            return callback

        def wrapper(*args, **kwargs):
            # Connect to the database
            db = sqlite3.connect(dbfile)
            # set text factory
            db.text_factory = text_factory
            # This enables column access by name: row['column_name']
            if dictrows:
                db.row_factory = sqlite3.Row
            # Add the connection handle as a keyword argument.
            kwargs[keyword] = db

            try:
                rv = callback(*args, **kwargs)
                if autocommit:
                    db.commit()
            except sqlite3.IntegrityError as e:
                db.rollback()
                raise bottle.HTTPError(500, "Database Error", e)
            except bottle.HTTPError as e:
                raise
            except bottle.HTTPResponse as e:
                if autocommit:
                    db.commit()
                raise
            finally:
                db.close()
            return rv

        # Replace the route callback with the wrapped one.
        return wrapper

Plugin = SQLitePlugin
