import sys
import os
import site
import shutil
from os.path import join, basename
from glob import glob
from distutils.sysconfig import get_python_lib
from cx_Freeze import setup, Executable
from cx_Freeze.command.build_exe import build_exe as build_exe_command

user_site = site.getusersitepackages()
cefPath = os.path.join(user_site, 'cefpython3')
CEF_INCLUDES = glob(join(cefPath, '*'))

base = None
if (sys.platform == 'win32'):
    base = 'Win32GUI'

mainScript = 'launcher.pyw'

if '--script' in sys.argv:
    index = sys.argv.index('--script')
    sys.argv.pop(index)
    mainScript = sys.argv.pop(index)

executable = Executable(script = mainScript, icon = 'icon.ico', base = base)

packages = [
    'os', 'sys', 'ctypes', 'json'
]

exclude = [
    'tkinter', 'tcl', 'tk', 'xml', 'xmlrpc', 'email', 'unittest'
]

bin_exclude = [
    'chrome_elf.dll',
    'libcef.dll',
    'libEGL.dll',
    'libGLESv2.dll',
    'msvcp90.dll',
    'msvcp100.dll',
    'widevinecdmadapter.dll',
    'd3dcompiler_43.dll',
    'd3dcompiler_47.dll'
]

include = [
    'data', 'static'
]

# Copy CEF files
class CustomBuildExe(build_exe_command):
    def run(self):
        super().run()
        build_dir = self.build_exe
        for cef_file in CEF_INCLUDES:
            if os.path.isfile(cef_file):
                dest_path = join(build_dir, basename(cef_file))
                try:
                    shutil.copy2(cef_file, dest_path)
                    print(f"? Copying {basename(cef_file)}")
                except Exception as e:
                    print(f"? Error copying {basename(cef_file)}: {e}")
            elif os.path.isdir(cef_file):
                dest_path = join(build_dir, basename(cef_file))
                try:
                    shutil.copytree(cef_file, dest_path, dirs_exist_ok=True)
                    print(f"?? Copying directory {basename(cef_file)}")
                except Exception as e:
                    print(f"? Error copying directory {basename(cef_file)}: {e}")
            else:
                print(f"? Skipping unknown item {basename(cef_file)}")
                
setup(
    name = 'Electronvolt Launcher',
    version = '0.0.1',
    description = 'Electronvolt Launcher',
    options = {
        'build_exe': {
            'packages': packages,
            'excludes': exclude, 
            'bin_excludes': bin_exclude,
            'include_files': include,
            'include_msvcr': True,
            'optimize': 2
        }
    },
    executables = [executable],
    cmdclass = {'build_exe': CustomBuildExe}
)
