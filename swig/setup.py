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
                '../src/graph.cpp',
                '../src/bipgraph.cpp',
                '../src/factorgraph.cpp',
                '../src/regiongraph.cpp',
                '../src/weightedgraph.cpp',
                '../src/clustergraph.cpp',
                '../src/properties.cpp',
                '../src/daialg.cpp',
                '../src/exactinf.cpp',
                '../src/alldai.cpp',
                '../src/jtree.cpp',
                ],
            include_dirs=_includeDirs,
            define_macros=[
                ('DAI_WITH_JTREE', None),
                ],
            ),
            ],
      )
