from distutils.core import setup, Extension

_includeDirs = ['../include']

setup(name='dai',
      version='0.1',
      ext_modules=[
        Extension(
            name='_dai',
            sources=[
                'dai_wrap.cxx',
                '../src/util.cpp',
                '../src/varset.cpp',
                '../src/exceptions.cpp',
                '../src/factor.cpp',
                ],
            include_dirs=_includeDirs,
            ),
            ],
      )
